import QtQuick
import QtCore
// Nécessaire pour la propriété attachée StackView.onActivated
import QtQuick.Controls

import ComputerModel 1.0
import AppModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import CompanionClient 1.0
import SystemStatus 1.0
import InputStatus 1.0
import WifiSetup 1.0
import AmbientColor 1.0

import "Format.js" as Format
import "Library.js" as Library
import "BootTimeline.js" as Boot

// Écran d'accueil de la console : la logique. La présentation est ailleurs :
// HomeScreen.qml (fond, barre haute, bloc héros, étagère, panneau d'options) et
// LaunchScreen.qml (lancement d'un jeu).
// Branché sur les vrais modèles Moonlight (ComputerModel + AppModel) :
//  - découverte du host (mDNS, polling lancé par main.qml) ;
//  - appairage automatique style "app TV" (code affiché, accept côté PC) ;
//  - lancement direct si le host est en mode direct-launch (cf. AppView.qml) ;
//  - bouton Jouer = vraie session via StreamSegue.qml ;
//  - bouton Y = options du flux, lues et écrites dans les préférences Moonlight.
FocusScope {
    id: home
    focus: true

    implicitWidth: 1280
    implicitHeight: 720

    // --- Modèles Moonlight ---
    // Liste des hosts connus (mDNS + manuels).
    // IMPORTANT : initialize() remplit le modèle SANS émettre de reset ;
    // il faut donc créer + initialiser AVANT d'assigner la propriété (sinon
    // les vues se lient à un modèle vu comme vide, pour toujours).
    property var computerModel: null

    // Index du host actif (= premier online+paired, fallback 0, -1 si vide).
    // Calculé via l'Instantiator `hostScanner` plus bas.
    property int activeComputerIndex: -1

    // Liste des jeux du host actif. Recréée à chaque changement de host.
    property var appModel: null

    // Représentation "vue" du host actif (lu via l'Instantiator).
    property string activeHostName: ""
    property bool   activeHostOnline: false
    property bool   activeHostPaired: false
    property bool   activeHostStatusUnknown: true
    property bool   activeHostWakeable: false     // adresse MAC connue : réveil à distance possible

    // --- État de l'appairage automatique ---
    property string pairingPin: ""
    property bool   pairingInFlight: false
    property string pairingError: ""

    // Lancement direct (mode "direct launch" du host) : une seule fois par session.
    property bool directLaunchDone: false

    // Premier démarrage : bienvenue, puis réseau si la console n'est pas en ligne ;
    // ensuite seulement la recherche du PC et les liaisons.
    property alias setupDone: consoleConfig.setupDone
    property bool welcomed: false
    readonly property bool needsNetwork: WifiSetup.available && !WifiSetup.online
    onNeedsNetworkChanged: if (welcomed && !needsNetwork) setupDone = true

    Settings {
        id: consoleConfig
        category: "ConsoleUi"
        // Le profil de stream par défaut n'est appliqué qu'au premier démarrage
        // console ; ensuite le panneau d'options (bouton Y) fait foi.
        property bool streamProfileInitialized: false
        property bool sounds: true          // réglage « Sons » du panneau d'options
        property string lastGame: ""        // dernier jeu lancé : l'accueil s'ouvre dessus
        property string favorites: "[]"     // jeux épinglés (X), le dernier épinglé en tête (JSON)
        property string recentGames: "{}"   // date de la dernière partie lancée d'ici, par jeu (JSON, ms)
        property int sleepMinutes: Theme.sleepMinutes   // veille de l'écran après inactivité ; 0 = jamais
        property string buttonLayout: "auto"   // glyphes : auto (la manette branchée), xbox, playstation, nintendo
        property bool setupDone: false      // premier démarrage fait (bienvenue, réseau)
        property string gameProfiles: "{}"  // réglages de flux propres à un jeu, par nom (JSON)
    }

    Component.onCompleted: {
        hideUpstreamChrome()
        Sounds.enabled = consoleConfig.sounds

        // Démarre la découverte du HostCompanion (mDNS _hostcompanion._tcp).
        // Si un host appairé est déjà connu, le client se reconnecte tout seul
        // (events + bibliothèque) dès qu'il est joignable.
        CompanionClient.startDiscovery()
        refreshCompanionGames()

        // Profil de stream "console" par défaut : 1080p60, 30 Mbps (cible §7 :
        // 30–50 Mbps stables ; le défaut Moonlight pour du 1080p60 est en
        // dessous). Appliqué une seule fois — modifiable ensuite via le
        // bouton Y (options du flux).
        if (!consoleConfig.streamProfileInitialized) {
            StreamingPreferences.width = 1920
            StreamingPreferences.height = 1080
            StreamingPreferences.fps = 60
            StreamingPreferences.bitrateKbps = Math.max(
                StreamingPreferences.getDefaultBitrate(1920, 1080, 60,
                                                       StreamingPreferences.enableYUV444),
                30000)
            StreamingPreferences.save()
            consoleConfig.streamProfileInitialized = true
        }
        refreshOptions()

        var m = Qt.createQmlObject(
            'import ComputerModel 1.0; ComputerModel {}', home, '')
        m.initialize(ComputerManager)
        m.pairingCompleted.connect(handlePairingCompleted)
        computerModel = m
    }

    // StreamSegue/QuitSegue ré-affichent la toolbar upstream en se dépilant :
    // on re-masque le chrome à chaque retour sur l'accueil.
    StackView.onActivated: returnedHome()

    function returnedHome() {
        hideUpstreamChrome()
        var fromGame = streamStarted
        if (streamStarted) {
            streamStarted = false
            Sounds.play("back")
            homeGuardUntil = Date.now() + Theme.homeGuard   // Home peut être encore enfoncé
        }
        endLaunch()
        refreshOptions()   // (la résolution « native » n'est connue qu'une fois à l'écran)
        homeScreen.forceActiveFocus()
        homeScreen.wake()
        rearmSleep()
        // Retour d'un jeu : le rideau CocoOS, posé au début du flux, couvre l'accueil.
        // Il fait la suite de l'action choisie dans le menu en jeu (StreamMenu), puis
        // se lève et l'accueil rentre (« Retour à l'accueil » : le jeu tourne encore).
        var exit = InputStatus.takeStreamExit()
        if (!fromGame || !streamCurtain.covering) {
            if (fromGame && exit === "quit") quitRunningGame()
            else if (fromGame && SystemStatus.powerActions.indexOf(exit) >= 0) SystemStatus.power(exit)
        } else if (exit === "quit" && appModel) {
            streamCurtain.reveal(qsTr("Fermeture de %1…").arg(appModel.getRunningAppName()), true)
            appModel.quitRunningApp()   // le rideau se lève à la réponse du PC (onQuitAppCompleted)
        } else if (SystemStatus.powerActions.indexOf(exit) >= 0) {
            streamCurtain.reveal("")
            SystemStatus.power(exit)
            if (exit === "suspend") streamCurtain.dismiss()   // redémarrer, éteindre : il reste
        } else {
            if (exit !== "") streamCurtain.reveal("")
            streamCurtain.dismiss()   // flux fini autrement (connexion perdue…) : il se lève aussitôt
        }
    }

    function hideUpstreamChrome() {
        // Mode console : masquer la barre d'outils Material de main.qml
        // (élément "bureau" interdit par le principe zéro-friction).
        // Fait d'ici pour ne pas modifier le fichier upstream. Détachée de la fenêtre,
        // pas seulement cachée : StreamSegue la ré-affiche en se dépilant, et on la
        // voyait en haut du rideau jusqu'à la fin de la transition.
        var win = home.Window.window
        if (win && win.header)
            win.header = null
    }

    // --- Boutons console au niveau de l'accueil ---
    // Y/Start (Hangup) ouvrent NOS options ; sans ça, les événements remonteraient
    // à main.qml qui ouvrirait la SettingsView Material du bureau. X (Menu) épingle
    // le jeu (géré par l'étagère) ; ici, il est consommé pour la même raison.
    // B (Échap) est consommé : rien derrière l'accueil.
    Keys.onMenuPressed: { /* X hors de l'étagère : rien */ }
    Keys.onHangupPressed: homeScreen.options.open()
    // Au clavier, la touche Origine (Home) tient lieu du bouton Home de la manette.
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home || event.key === Qt.Key_HomePage) {
            event.accepted = true
            homeButton()
        }
    }
    Keys.onEscapePressed: { /* accueil : rien à fermer */ }

    onActiveComputerIndexChanged: rebuildAppModel()
    onActiveHostPairedChanged: maybeStartPairing()

    function rebuildAppModel() {
        if (activeComputerIndex >= 0) {
            // Même contrainte que pour computerModel : initialiser AVANT
            // d'assigner, sinon les vues se lient à un modèle "vide".
            var m = Qt.createQmlObject(
                'import AppModel 1.0; AppModel {}', home, '')
            m.initialize(ComputerManager, activeComputerIndex, false)
            appModel = m
        } else {
            appModel = null
        }
    }

    // NB : AppModel/ComputerModel (C++) n'exposent PAS de propriété `count` ;
    // on passe toujours par le count des Instantiator (appViewer/hostScanner).
    // L'app (objet d'appViewer) du jeu sélectionné sur l'étagère.
    function currentApp() {
        if (shelfModel.count === 0 || appViewer.count === 0) return null
        var idx = Math.max(0, Math.min(homeScreen.currentIndex, shelfModel.count - 1))
        return appViewer.objectAt(shelfModel.get(idx).appIndex) || null
    }

    // --- Étagère : les apps du PC sans les utilitaires, favoris puis jeux récents ---
    // Ses index ne sont PAS ceux d'AppModel : chaque élément porte son `appIndex`.
    ListModel { id: shelfModel }        // name, appIndex, boxart, favorite
    property int shelfRevision: 0       // change à chaque réordonnancement (liaisons)

    function favoriteNames() { return Library.parse(consoleConfig.favorites, []) }

    // Dernière partie, en ms : lancée d'ici, ou d'après le Companion (jouée sur le PC).
    function lastPlayedTime(name, recent) {
        var info = companionGames[name.toLowerCase()]
        var companion = info && info.lastPlayed ? Date.parse(info.lastPlayed) : 0
        return Math.max(recent[name] || 0, companion || 0)
    }

    function rebuildShelf() {
        var apps = []
        for (var i = 0; i < appViewer.count; i++) {
            var it = appViewer.objectAt(i)
            if (!it) continue
            var art = it.boxart.toString()
            // (Moonlight donne une icône générique aux apps sans jaquette : l'étagère
            // dessine plutôt son propre repli.)
            apps.push({ name: it.name, appIndex: i, boxart: art === "qrc:/res/no_app_image.png" ? "" : art })
        }
        var favorites = favoriteNames()
        var recent = Library.parse(consoleConfig.recentGames, {})
        var ordered = Library.order(apps, favorites, function(name) { return home.lastPlayedTime(name, recent) })

        // Le jeu affiché le reste : la sélection le suit à sa nouvelle place. Au
        // chargement, avant l'entrée de l'accueil, c'est le dernier jeu lancé.
        var selected = homeScreen.ready && homeScreen.currentIndex < shelfModel.count
                       ? shelfModel.get(homeScreen.currentIndex).name : consoleConfig.lastGame
        Library.sync(shelfModel, ordered.map(function(a) {
            return { name: a.name, appIndex: a.appIndex, boxart: a.boxart,
                     favorite: favorites.indexOf(a.name) >= 0 }
        }))
        shelfRevision++
        var index = ordered.findIndex(function(a) { return a.name === selected })
        if (index >= 0)
            homeScreen.currentIndex = index
        maybeDirectLaunch()
    }

    function shelfIndexOf(appIndex) {
        for (var i = 0; i < shelfModel.count; i++)
            if (shelfModel.get(i).appIndex === appIndex) return i
        return -1
    }

    // X : épingle le jeu en tête de l'étagère, ou le détache.
    function toggleFavorite() {
        var app = currentApp()
        if (!app) return
        var favorites = Library.toggled(favoriteNames(), app.name)
        var pinned = favorites.indexOf(app.name) >= 0
        consoleConfig.favorites = JSON.stringify(favorites)
        rebuildShelf()
        Sounds.play(pinned ? "select" : "back")
        homeScreen.toast(pinned ? qsTr("%1 est épinglé en tête de liste").arg(app.name)
                                : qsTr("%1 n'est plus épinglé").arg(app.name))
    }

    // Un jeu vient d'être lancé : il passe en tête des jeux récents.
    function markPlayed(name) {
        var recent = Library.parse(consoleConfig.recentGames, {})
        recent[name] = Date.now()
        consoleConfig.recentGames = JSON.stringify(recent)
        consoleConfig.lastGame = name
        Qt.callLater(rebuildShelf)
    }

    // --- Appairage automatique ("silent pair" côté console, cf CLAUDE.md §9 6b) ---
    // Dès qu'un host en ligne mais non appairé devient actif, on génère un PIN
    // et on lance l'appairage en arrière-plan. L'utilisateur ne voit qu'un code
    // de liaison (pinScreen), à saisir une fois côté PC.
    // À terme, le host auto-acceptera et cet écran ne s'affichera jamais.
    //
    // Garde-fou : au boot, le host passe online AVANT que son pairState soit
    // confirmé (statusUnknown / bref "non appairé" le temps du serverinfo
    // HTTPS). On exige donc un état "online + non appairé" STABLE pendant
    // 2,5 s avant de déclencher — sinon on enverrait une demande de PIN
    // parasite à un host déjà appairé.
    function maybeStartPairing() {
        if (pairingNeeded())
            pairingArmTimer.start()
        else
            pairingArmTimer.stop()
    }

    function pairingNeeded() {
        return !pairingInFlight
            && activeComputerIndex >= 0
            && activeHostOnline
            && !activeHostPaired
            && !activeHostStatusUnknown
    }

    Timer {
        id: pairingArmTimer
        interval: 2500
        onTriggered: {
            if (!home.pairingNeeded()) return
            home.pairingError = ""
            home.pairingPin = home.computerModel.generatePinString()
            home.pairingInFlight = true
            console.info("[console-ui] Appairage automatique avec \"" + home.activeHostName + "\"")
            home.computerModel.pairComputer(home.activeComputerIndex, home.pairingPin)
            // Si le Companion est déjà appairé, il soumet le PIN à Apollo à notre
            // place → l'utilisateur n'a rien à faire côté PC (§6.4). Sinon, repli :
            // pinScreen affiche le PIN à saisir sur le PC.
            if (CompanionClient.paired)
                CompanionClient.submitMoonlightPin(home.pairingPin)
        }
    }

    function handlePairingCompleted(error) {
        pairingInFlight = false
        if (error !== undefined && error !== null) {
            // Échec (refus, timeout, jeu en cours…) : nouvelle tentative avec
            // un nouveau code après une courte pause.
            pairingError = "" + error
            pairingRetryTimer.restart()
        } else {
            pairingPin = ""
            pairingError = ""
        }
    }

    Timer {
        id: pairingRetryTimer
        interval: 5000
        onTriggered: home.maybeStartPairing()
    }

    // --- Scanner caché des hosts : met à jour activeComputerIndex en continu ---
    Instantiator {
        id: hostScanner
        model: home.computerModel
        delegate: QtObject {
            readonly property bool isOnline: model.online
            readonly property bool isPaired: model.paired
            readonly property bool isUnknown: model.statusUnknown
            readonly property bool isWakeable: model.wakeable
            readonly property string hostName: model.name
            // Chaque changement de rôle relance la sélection : un host qui
            // passe online (même non appairé) doit rafraîchir l'affichage.
            onIsOnlineChanged: home.pickActiveComputer()
            onIsPairedChanged: home.pickActiveComputer()
            onIsUnknownChanged: home.pickActiveComputer()
            onHostNameChanged: home.pickActiveComputer()
        }
        onObjectAdded: function(index, obj) { home.pickActiveComputer() }
        onObjectRemoved: function(index, obj) { home.pickActiveComputer() }
    }

    function pickActiveComputer() {
        // Premier candidat online+paired, sinon premier online, sinon 0, sinon -1.
        var fallback = hostScanner.count > 0 ? 0 : -1
        var firstOnline = -1
        for (var i = 0; i < hostScanner.count; i++) {
            var it = hostScanner.objectAt(i)
            if (!it) continue
            if (it.isOnline && it.isPaired) {
                if (activeComputerIndex !== i) activeComputerIndex = i
                updateActiveHostView(it)
                return
            }
            if (firstOnline < 0 && it.isOnline) firstOnline = i
        }
        var pick = firstOnline >= 0 ? firstOnline : fallback
        if (activeComputerIndex !== pick) activeComputerIndex = pick
        var sel = pick >= 0 ? hostScanner.objectAt(pick) : null
        updateActiveHostView(sel)
    }

    function updateActiveHostView(it) {
        if (it) {
            activeHostName = it.hostName
            activeHostOnline = it.isOnline
            activeHostPaired = it.isPaired
            activeHostStatusUnknown = it.isUnknown
            activeHostWakeable = it.isWakeable
        } else {
            activeHostName = ""
            activeHostOnline = false
            activeHostPaired = false
            activeHostStatusUnknown = true
            activeHostWakeable = false
        }
        maybeStartPairing()
    }

    // Instantiator pour exposer les rôles d'AppModel à currentApp() / launchApp().
    Instantiator {
        id: appViewer
        model: home.appModel
        delegate: QtObject {
            readonly property string name: model.name
            readonly property bool running: model.running
            readonly property int appid: model.appid
            readonly property url boxart: model.boxart
            // (les jaquettes arrivent après la liste)
            onNameChanged: Qt.callLater(home.rebuildShelf)
            onBoxartChanged: Qt.callLater(home.rebuildShelf)
        }
        // Reconstruite une fois la liste arrivée (Qt.callLater regroupe les appels).
        onObjectAdded: Qt.callLater(home.rebuildShelf)
        onObjectRemoved: Qt.callLater(home.rebuildShelf)
    }

    // Lancement direct éventuel (§9 6a), une fois l'étagère construite.
    function maybeDirectLaunch() {
        if (directLaunchDone || !appModel) return
        var idx = appModel.getDirectLaunchAppIndex()
        if (idx >= 0) {
            directLaunchDone = true
            var shelfIndex = shelfIndexOf(idx)
            if (shelfIndex >= 0)
                homeScreen.currentIndex = shelfIndex
            launchApp(idx)
        }
    }

    // Bibliothèque du Companion indexée par nom de jeu (en minuscules) : fournit au
    // bloc héros la source, la dernière session et le temps de jeu. Vide sans Companion.
    property var companionGames: ({})

    function refreshCompanionGames() {
        var byName = {}
        var games = CompanionClient.games()
        for (var i = 0; i < games.length; i++)
            byName[(games[i].name || "").toLowerCase()] = games[i]
        companionGames = byName
        Qt.callLater(rebuildShelf)          // l'ordre suit aussi les parties jouées sur le PC
    }

    // Réseau vers le PC : sondé seulement quand l'accueil est à l'écran et le PC en ligne.
    readonly property string probedHost: onTop && activeHostOnline ? activeHostName : ""
    onProbedHostChanged: probedHost !== "" ? SystemStatus.probeHost(ComputerManager, probedHost)
                                           : SystemStatus.stopProbing()

    // Glyphes des boutons : ceux de la manette branchée, sauf réglage contraire.
    Binding {
        target: Theme; property: "buttonLayout"
        value: consoleConfig.buttonLayout !== "auto" ? consoleConfig.buttonLayout
             : InputStatus.layout !== "" ? InputStatus.layout : "xbox"
    }

    // L'animation de démarrage (tests : la finir d'office).
    readonly property alias splash: bootSplash

    // Sortie de veille (écran, ou suspension du système) : l'accueil rentre, le logo
    // de la barre haute respire (BOOT_ANIMATION.md §7).
    function playWake() {
        if (!bootSplash.done) return
        bootSplash.mode = "wake"
        bootSplash.start()
    }
    Connections {
        target: SystemStatus
        function onResumed() { home.playWake() }
    }

    // --- Animation de démarrage : l'accueil sait-il quoi montrer ? ---
    // Prêt : des jeux sur l'étagère, ou un écran de message qui n'attend plus le
    // réseau (bienvenue, choix du Wi-Fi, codes de liaison, PC hors ligne confirmé,
    // aucun PC connu passé un délai de découverte). Sinon, le O fait le chargeur.
    property bool discoveryGrace: false
    Timer { interval: Theme.bootDiscoveryGrace; running: true; onTriggered: home.discoveryGrace = true }
    readonly property bool bootReady: shelfModel.count > 0 || welcomeScreen.shown || networkScreen.shown
        || companionPairing.shown || pinScreen.shown
        || (searchScreen.shown && ((activeComputerIndex >= 0 && !activeHostOnline && !activeHostStatusUnknown)
                                   || (hostScanner.count === 0 && discoveryGrace)))
    readonly property string bootStep: hostScanner.count === 0 && !discoveryGrace ? qsTr("Démarrage des services")
        : !activeHostOnline ? qsTr("Recherche de l’hôte")
        : !activeHostPaired || (CompanionClient.paired && !CompanionClient.eventsConnected) ? qsTr("Connexion à l’hôte")
        : qsTr("Chargement de la bibliothèque")

    // --- Veille de l'écran ---
    // Sans action à l'accueil pendant consoleConfig.sleepMinutes, l'écran passe au
    // noir. Jamais pendant un lancement (ni pendant un flux : Qt est alors suspendu).
    readonly property bool onTop: StackView.view === null || StackView.status === StackView.Active
    readonly property bool sleepAllowed: onTop && !launchScreen.active && consoleConfig.sleepMinutes > 0
    onSleepAllowedChanged: rearmSleep()
    property var focusBeforeSleep: null

    function rearmSleep() {
        if (sleepAllowed && !sleepScreen.asleep)
            idleTimer.restart()
        else
            idleTimer.stop()
    }
    Timer {
        id: idleTimer
        interval: consoleConfig.sleepMinutes * 60000
        onTriggered: {
            home.focusBeforeSleep = home.Window.activeFocusItem
            sleepScreen.sleep()
        }
    }

    // --- Bouton Home ---
    // À l'accueil : ouvre (ou referme) le menu Home. En veille : réveille. Pendant un
    // jeu, c'est la session qui le reçoit : elle rend la main à l'accueil (gamepad.cpp).
    property double homeGuardUntil: 0

    Connections {
        target: InputStatus
        function onActivity() { home.rearmSleep() }
        function onHomePressed() { home.homeButton() }
        function onBumperPressed(direction) {
            if (homeScreen.options.opened) homeScreen.options.switchTab(direction)
        }
    }
    // À l'ouverture, le panneau suit le jeu sélectionné (ligne de ses réglages à part).
    Connections {
        target: homeScreen.options
        function onOpenedChanged() { if (homeScreen.options.opened) home.refreshOptions() }
    }
    // Luminosité ou volume changés ailleurs (touches de la console) : le panneau suit.
    Connections {
        target: SystemStatus
        function onChanged() { if (homeScreen.options.opened) home.refreshOptions() }
    }

    function homeButton() {
        if (Date.now() < homeGuardUntil || streamCurtain.covering) return
        if (sleepScreen.asleep) {
            sleepScreen.wake()
            return
        }
        if (!onTop || launchScreen.active || updateDialog.opened) return
        if (homeMenu.opened) {
            homeMenu.close()
            return
        }
        homeScreen.options.close()
        confirmDialog.close()
        openHomeMenu()
    }

    function openHomeMenu() {
        var running = appModel ? appModel.getRunningAppName() : ""
        var actions = []
        if (running !== "") {
            actions.push({ label: qsTr("Reprendre %1").arg(running), key: "resume" })
            actions.push({ label: qsTr("Quitter %1").arg(running), key: "quit" })
        }
        var power = SystemStatus.powerActions
        if (power.indexOf("suspend") >= 0) actions.push({ label: qsTr("Mettre en veille"), key: "suspend" })
        if (power.indexOf("reboot") >= 0) actions.push({ label: qsTr("Redémarrer"), key: "reboot" })
        if (power.indexOf("poweroff") >= 0) actions.push({ label: qsTr("Éteindre"), key: "poweroff" })
        if (actions.length === 0) return
        homeMenu.message = running !== "" ? qsTr("%1 est en cours sur %2.").arg(running).arg(activeHostName) : ""
        homeMenu.actions = actions
        homeMenu.open()
    }

    function homeMenuChosen(key) {
        var running = appModel ? appModel.getRunningAppName() : ""
        if (key === "resume") {
            var index = findAppIndexByName(running)
            if (index >= 0) launchApp(index)
        } else if (key === "quit") {
            confirmDialog.ask(qsTr("Quitter %1 ?").arg(running),
                              qsTr("Toute progression non sauvegardée sera perdue."),
                              qsTr("Quitter"), function() { home.quitRunningGame() })
        } else if (key === "suspend") {
            SystemStatus.power("suspend")
        } else if (key === "reboot") {
            confirmDialog.ask(qsTr("Redémarrer la console ?"), "", qsTr("Redémarrer"),
                              function() { SystemStatus.power("reboot") })
        } else if (key === "poweroff") {
            confirmDialog.ask(qsTr("Éteindre la console ?"), "", qsTr("Éteindre"),
                              function() { SystemStatus.power("poweroff") })
        }
    }

    function quitRunningGame() {
        if (!appModel) return
        homeScreen.toast(qsTr("Fermeture de %1…").arg(appModel.getRunningAppName()))
        appModel.quitRunningApp()
    }
    Connections {
        target: ComputerManager
        function onQuitAppCompleted(error) {
            if (streamCurtain.waiting) streamCurtain.dismiss()
            if (error !== undefined && error !== null)
                homeScreen.toast(qsTr("Le jeu n'a pas pu être fermé."))
        }
    }

    // --- Réveil du PC (Wake-on-LAN) ---
    // PC connu (adresse MAC) mais hors ligne : la console l'allume elle-même, une fois
    // d'office peu après le démarrage, puis avant tout lancement et à la demande (A)
    // sur l'écran de recherche.
    property bool waking: false          // réveil envoyé, on attend que le PC réponde
    property bool wakeFailed: false      // il n'a pas répondu à temps
    property bool autoWakeDone: false

    function wakeHost() {
        if (activeComputerIndex < 0 || !activeHostWakeable || activeHostOnline) return
        console.info("[console-ui] Réveil de \"" + activeHostName + "\"")
        computerModel.wakeComputer(activeComputerIndex)
        waking = true
        wakeFailed = false
        wakeTimeout.restart()
    }

    Timer {
        id: autoWake
        interval: Theme.autoWakeDelay
        running: !home.autoWakeDone && home.activeComputerIndex >= 0
                 && home.activeHostWakeable && !home.activeHostOnline
        onTriggered: {
            home.autoWakeDone = true
            home.wakeHost()
        }
    }
    Timer {
        id: wakeTimeout
        interval: Theme.wakeTimeout
        onTriggered: {
            home.waking = false
            home.wakeFailed = true
            if (home.launchWaking)
                launchScreen.error = qsTr("%1 ne répond pas. Vérifiez qu'il est branché et que le réveil à distance (Wake-on-LAN) est activé.")
                                     .arg(home.activeHostName)
        }
    }
    onActiveHostOnlineChanged: {
        maybeStartPairing()
        if (!activeHostOnline) return
        waking = false
        wakeFailed = false
        wakeTimeout.stop()
        if (launchWaking)
            companionWait.restart()
    }
    // Le PC répond : le Companion (s'il est appairé) se reconnecte un peu après lui.
    // On lui laisse ce temps avant de reprendre le lancement, sinon il partirait en direct.
    Timer {
        id: companionWait
        interval: 250
        repeat: true
        property int waited: 0
        onRunningChanged: if (running) waited = 0
        onTriggered: {
            waited += interval
            if (!CompanionClient.paired || CompanionClient.eventsConnected || waited >= Theme.companionWait) {
                stop()
                home.resumeLaunchAfterWake()
            }
        }
    }

    // --- Lancement d'un jeu ---
    // A enfonce le bouton Jouer, puis LaunchScreen s'ouvre par-dessus l'accueil. Le
    // flux Moonlight ne démarre que lorsque l'hôte est prêt (tout de suite en
    // lancement direct, au READY du Companion sinon) ET que l'écran a fini de s'ouvrir.
    property int launchIndex: -1         // jeu en cours de lancement, -1 sinon
    property bool launchResume: false    // il tourne déjà sur le PC : on reprend
    property bool launchReady: false     // l'hôte est prêt
    property bool launchOpened: false    // LaunchScreen couvre l'écran
    property bool streamStarted: false   // le flux a démarré : au retour, son de retour
    property bool launchWaking: false    // le PC dormait : le lancement attend son réveil

    function findAppIndexByName(name) {
        for (var i = 0; i < appViewer.count; i++) {
            var it = appViewer.objectAt(i)
            if (it && it.name === name) return i
        }
        return -1
    }

    function humanSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        var u = [qsTr("o"), qsTr("Ko"), qsTr("Mo"), qsTr("Go"), qsTr("To")]
        var i = 0; var v = bytes
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (i >= 2 ? v.toLocaleString(Qt.locale(english ? "en_US" : "fr_FR"), "f", 1) : Math.round(v)) + " " + u[i]
    }

    function launchApp(index) {
        if (!appModel) return
        if (launchIndex >= 0 || launchScreen.active) return   // un lancement est déjà en cours
        var item = appViewer.objectAt(index)
        if (!item) return

        // PC éteint : on le réveille d'abord, l'écran de lancement en première étape.
        if (!activeHostOnline && activeHostWakeable) {
            launchIndex = index
            launchWaking = true
            launchResume = false
            launchReady = false
            launchOpened = false
            launchScreen.image = homeScreen.backdrop
            setLaunchOrigin(index)
            launchScreen.steps = [qsTr("Réveil de %1").arg(activeHostName), qsTr("Lancement de %1").arg(item.name)]
            launchScreen.step = 0
            launchScreen.stepProgress = Theme.wakeStepProgress   // durée inconnue : la barre attend à mi-chemin
            launchScreen.cancellable = true
            launchScreen.hint = ""
            wakeHost()
            Sounds.play("select")
            homeScreen.pressed = true
            launchPress.start()
            return
        }

        // PC injoignable et impossible à réveiller : pas de session vers une
        // adresse vide (« Host not found (Error 3) »).
        if (!activeHostOnline) {
            homeScreen.toast(qsTr("%1 est hors ligne").arg(activeHostName))
            return
        }

        // Un AUTRE jeu tourne déjà sur le host : demander confirmation
        // (équivalent console du quitAppDialog de AppView.qml). Chemin direct.
        var runningId = appModel.getRunningAppId()
        if (runningId !== 0 && runningId !== item.appid) {
            confirmDialog.ask(qsTr("Un jeu est déjà en cours"),
                              qsTr("%1 est en cours sur votre PC. Le fermer et lancer %2 ? Toute progression non sauvegardée sera perdue.")
                                  .arg(appModel.getRunningAppName()).arg(item.name),
                              qsTr("Fermer et jouer"), function() { home.quitAndLaunch(index) })
            return
        }

        beginLaunch(index, false)
        Sounds.play("select")
        homeScreen.pressed = true
        launchPress.start()
    }

    // Étapes et départ du lancement. `afterWake` : l'écran est déjà ouvert sur
    // l'étape du réveil, qui est faite.
    function beginLaunch(index, afterWake) {
        var item = appViewer.objectAt(index)
        if (!item) return
        // Chemin Companion = LE différenciateur : POST /v1/launch → (maj si besoin)
        // → READY → stream. On NE démarre PAS le stream nous-mêmes ici (§4 host).
        // Repli direct si le Companion est absent ou ne connaît pas ce jeu.
        var gameId = CompanionClient.paired && CompanionClient.eventsConnected
                     ? CompanionClient.gameIdForName(item.name) : ""
        var runningId = appModel.getRunningAppId()

        launchIndex = index
        launchResume = runningId === item.appid
        launchReady = gameId === ""
        if (!afterWake) {
            launchOpened = false
            launchScreen.image = homeScreen.backdrop
            setLaunchOrigin(index)
        }
        launchScreen.steps = (afterWake ? [launchScreen.steps[0]] : [])
            .concat(gameId !== "" ? [qsTr("Préparation de %1").arg(activeHostName)] : [])
            .concat([
                launchResume ? qsTr("Reprise de %1").arg(item.name) : qsTr("Lancement de %1").arg(item.name),
                qsTr("Ouverture du flux %1").arg(streamSummary(item.name))
            ])
        launchScreen.step = afterWake ? 1 : 0
        launchScreen.stepProgress = 1
        launchScreen.cancellable = gameId !== ""
        launchScreen.hint = ""
        if (gameId !== "")
            CompanionClient.launch(gameId)
        maybeStartStream()
    }

    // L'écran de lancement grandit depuis la vignette, si c'est bien le jeu
    // sélectionné sur l'étagère (pas une reprise depuis le menu Home).
    function setLaunchOrigin(appIndex) {
        var selected = shelfModel.count > 0 ? shelfModel.get(Math.min(homeScreen.currentIndex, shelfModel.count - 1)) : null
        var fromShelf = selected !== null && selected.appIndex === appIndex
        launchScreen.origin = fromShelf ? homeScreen.activeThumbRect : Qt.rect(0, 0, 0, 0)
        launchScreen.thumbnail = fromShelf ? selected.boxart : ""
    }

    function resumeLaunchAfterWake() {
        if (!launchWaking) return
        launchWaking = false
        var index = launchIndex
        launchIndex = -1
        beginLaunch(index, true)
    }

    Timer {
        id: launchPress
        interval: Theme.launchPress
        onTriggered: {
            homeScreen.launching = true
            launchScreen.open()
        }
    }

    // « 1080p60 », « 1080p60 HEVC HDR » : le flux tel qu'il est réglé.
    function streamSummary(game) {
        var p = StreamingPreferences
        var s = settingsFor(game && gameProfiles()[game] ? game : "")
        var codec = s.videoCodecConfig === p.VCC_FORCE_H264 ? " H.264"
                  : s.videoCodecConfig === p.VCC_FORCE_AV1 ? " AV1"
                  : s.videoCodecConfig === p.VCC_AUTO ? "" : " HEVC"
        return s.height + "p" + s.fps + codec + (s.enableHdr ? " HDR" : "")
    }

    // Démarre la session Moonlight (page StreamSegue d'origine, cachée sous
    // LaunchScreen) dès que l'hôte est prêt et que l'écran de lancement est en place.
    function maybeStartStream() {
        if (launchIndex < 0 || launchWaking || !launchReady || !launchOpened || !appModel) return
        var index = launchIndex
        launchIndex = -1
        var item = appViewer.objectAt(index)
        if (item)
            applyGameProfile(item.name)     // (remis par endLaunch)
        var session = appModel.createSessionForApp(index)
        prepareStreamMenu(item ? item.name : "")
        if (item)
            markPlayed(item.name)

        // Dernière étape : la barre avance au rythme de la connexion. C'est le
        // moment de rappeler comment on reviendra (la page d'origine de Moonlight,
        // cachée dessous, affiche ce conseil ici).
        launchScreen.cancellable = false
        launchScreen.hint = qsTr("Start + Select + L1 + R1 : revenir à l'accueil")
        launchScreen.stepProgress = 0
        launchScreen.step = launchScreen.steps.length - 1
        // Moonlight fige l'interface pendant qu'il prépare son décodeur : l'écran
        // de lancement reste immobile jusqu'à la première étape de connexion.
        launchScreen.frozen = true
        session.stageStarting.connect(function() {
            launchScreen.frozen = false
            launchScreen.stepProgress = Math.min(1, launchScreen.stepProgress + 1 / Theme.launchStreamStages)
        })
        session.connectionStarted.connect(function() {
            home.streamStarted = true
            streamCurtain.cover()
            Sounds.play("ready")
            launchScreen.close(false)
        })
        session.sessionFinished.connect(function() { home.endLaunch() })

        var component = Qt.createComponent("qrc:/gui/StreamSegue.qml")
        stackView.push(component.createObject(stackView, {
            "appName": item ? item.name : "",
            "session": session,
            "isResume": launchResume
        }))
    }

    // Le menu en jeu (bouton Home pendant le flux) : son titre, ses actions, ses glyphes.
    function prepareStreamMenu(game) {
        InputStatus.prepareStreamMenu(game, SystemStatus.powerActions, Theme.buttonLayout)
    }

    // Retour à l'accueil : fin du jeu, échec, annulation.
    function endLaunch() {
        restoreCommonSettings()
        launchPress.stop()
        companionWait.stop()
        launchWaking = false
        launchIndex = -1
        launchScreen.close(true)
        homeScreen.launching = false
        homeScreen.pressed = false
    }

    // Ferme le jeu en cours puis enchaîne sur le nouveau, via le QuitSegue
    // upstream (gère le quit côté host et le chaînage nextSession).
    function quitAndLaunch(nextIndex) {
        if (!appModel) return
        var item = appViewer.objectAt(nextIndex)
        if (item) {
            markPlayed(item.name)
            applyGameProfile(item.name)     // (remis au retour sur l'accueil)
        }
        prepareStreamMenu(item ? item.name : "")
        var session = item ? appModel.createSessionForApp(nextIndex) : null
        if (session) {
            session.connectionStarted.connect(function() {
                home.streamStarted = true
                streamCurtain.cover()
            })
        }
        var component = Qt.createComponent("qrc:/gui/QuitSegue.qml")
        stackView.push(component.createObject(stackView, {
            "appName": appModel.getRunningAppName(),
            "quitRunningAppFn": function() { appModel.quitRunningApp() },
            "nextAppName": item ? item.name : null,
            "nextSession": session
        }))
    }

    // --- Options (bouton Y) : onglets Flux et Console ---
    // Les choix proposés par ligne du panneau, et les onglets eux-mêmes. Tout est lu
    // dans les préférences Moonlight, la conf console ou le système, et y est écrit
    // aussitôt : pas d'état à part.
    property var optionChoices: ({})
    property var optionTabs: []
    property bool optionAutoBitrate: false   // le débit suit résolution et fréquence

    // Langue de l'interface : le réglage de Moonlight, dont la traduction est chargée au
    // démarrage (languages/qml_en.ts). « Auto » (jamais choisie) suit la langue du système.
    readonly property bool english: StreamingPreferences.language === StreamingPreferences.LANG_EN
        || StreamingPreferences.language === StreamingPreferences.LANG_AUTO && Qt.locale().name.indexOf("en") === 0

    function refreshOptions() {
        var p = StreamingPreferences
        // Réglages de flux affichés : ceux du jeu sélectionné s'il en a, sinon les communs.
        var game = homeScreen.app ? homeScreen.app.name : ""
        var own = game !== "" && gameProfiles()[game] !== undefined
        var s = settingsFor(own ? game : "")

        // Résolution : 720p, celle de l'écran, 1080p (et l'actuelle si elle n'y est pas).
        var nativeW = Math.round(Screen.width * Screen.devicePixelRatio)
        var nativeH = Math.round(Screen.height * Screen.devicePixelRatio)
        var res = [ { label: "720p", w: 1280, h: 720 }, { label: "1080p", w: 1920, h: 1080 } ]
        var same = function(w, h) { return function(r) { return r.w === w && r.h === h } }
        if (nativeW > 0 && !res.some(same(nativeW, nativeH)))
            res.splice(1, 0, { label: qsTr("Natif %1×%2").arg(nativeW).arg(nativeH), w: nativeW, h: nativeH })
        if (!res.some(same(s.width, s.height)))
            res.push({ label: s.width + "×" + s.height, w: s.width, h: s.height })

        var fps = [30, 60, 90, 120]
        if (fps.indexOf(s.fps) < 0)
            fps.push(s.fps)
        fps.sort(function(a, b) { return a - b })

        // Débit : « Auto » est la valeur que Moonlight calcule pour la résolution et
        // la fréquence ; sinon une valeur fixe (l'actuelle est ajoutée si besoin).
        optionAutoBitrate = s.autoAdjustBitrate
                && s.bitrateKbps === p.getDefaultBitrate(s.width, s.height, s.fps, p.enableYUV444)
        var kbps = [10000, 20000, 40000, 80000]
        if (!optionAutoBitrate && kbps.indexOf(s.bitrateKbps) < 0)
            kbps.push(s.bitrateKbps)
        kbps.sort(function(a, b) { return a - b })
        var rate = [ { label: qsTr("Auto"), auto: true } ].concat(kbps.map(function(k) {
            return { label: qsTr("%1 Mb/s").arg(Math.round(k / 1000)), kbps: k }
        }))

        var codec = [ { label: qsTr("Auto"), value: p.VCC_AUTO }, { label: "H.264", value: p.VCC_FORCE_H264 },
                      { label: "HEVC", value: p.VCC_FORCE_HEVC }, { label: "AV1", value: p.VCC_FORCE_AV1 } ]
        var codecIndex = codec.findIndex(function(c) { return c.value === s.videoCodecConfig })
        var hdr = [ { label: qsTr("Désactivé"), value: false }, { label: qsTr("Activé"), value: true } ]

        // Console : réglages du système et de la conf console (ConsoleUi).
        var percents = function(from) {
            var list = []
            for (var v = from; v <= 100; v += 10) list.push({ label: qsTr("%1 %").arg(v), value: v })
            return list
        }
        var nearest = function(list, value) {
            var best = 0
            for (var i = 1; i < list.length; i++)
                if (Math.abs(list[i].value - value) < Math.abs(list[best].value - value)) best = i
            return best
        }
        var brightness = percents(10), volume = percents(0)
        var sleep = [ { label: qsTr("2 min"), value: 2 }, { label: qsTr("5 min"), value: 5 },
                      { label: qsTr("10 min"), value: 10 }, { label: qsTr("30 min"), value: 30 },
                      { label: qsTr("Jamais"), value: 0 } ]
        var buttons = [ { label: qsTr("Auto"), value: "auto" }, { label: "Xbox", value: "xbox" },
                        { label: "PlayStation", value: "playstation" }, { label: "Nintendo", value: "nintendo" } ]
        var sounds = [ { label: qsTr("Activés"), value: true }, { label: qsTr("Coupés"), value: false } ]
        // Chaque langue dans sa langue.
        var language = [ { label: "Français", value: p.LANG_FR }, { label: "English", value: p.LANG_EN } ]

        optionChoices = { res: res, fps: fps.map(function(f) { return { label: "" + f, value: f } }),
                          rate: rate, codec: codec, hdr: hdr, brightness: brightness, volume: volume,
                          sleep: sleep, buttons: buttons, sounds: sounds, language: language }
        var row = function(key, label, index) {
            return { key: key, label: label, index: index,
                     options: optionChoices[key].map(function(c) { return c.label }) }
        }
        var consoleRows = []
        if (SystemStatus.brightness >= 0)
            consoleRows.push(row("brightness", qsTr("Luminosité"), nearest(brightness, SystemStatus.brightness)))
        if (SystemStatus.volume >= 0)
            consoleRows.push(row("volume", qsTr("Volume"), nearest(volume, SystemStatus.volume)))
        consoleRows.push(row("sleep", qsTr("Veille de l'écran"),
                             Math.max(0, sleep.findIndex(function(c) { return c.value === consoleConfig.sleepMinutes }))))
        consoleRows.push(row("buttons", qsTr("Boutons"),
                             Math.max(0, buttons.findIndex(function(c) { return c.value === consoleConfig.buttonLayout }))))
        consoleRows.push(row("sounds", qsTr("Sons"), consoleConfig.sounds ? 0 : 1))
        consoleRows.push(row("language", qsTr("Langue"), english ? 1 : 0))
        if (WifiSetup.available)
            consoleRows.push({ key: "wifi", label: qsTr("Wi-Fi"), action: true,
                               value: WifiSetup.currentNetwork !== "" ? WifiSetup.currentNetwork : qsTr("Non connecté") })

        optionChoices.profile = [ { label: qsTr("Réglages communs"), value: false },
                                  { label: qsTr("Réglages à part"), value: true } ]
        var profileRow = game !== "" ? [ { key: "profile", label: game, index: own ? 1 : 0,
                                           options: optionChoices.profile.map(function(c) { return c.label }) } ]
                                     : []
        optionTabs = [
            { label: qsTr("Flux"), rows: profileRow.concat([
                row("res", qsTr("Résolution"), res.findIndex(same(s.width, s.height))),
                row("fps", qsTr("Images par seconde"), fps.indexOf(s.fps)),
                row("rate", qsTr("Débit"), optionAutoBitrate ? 0 : 1 + kbps.indexOf(s.bitrateKbps)),
                // (un ancien réglage « HEVC HDR » est montré comme HEVC)
                row("codec", qsTr("Codec"), codecIndex >= 0 ? codecIndex : 2),
                row("hdr", qsTr("HDR"), s.enableHdr ? 1 : 0)
            ]) },
            { label: qsTr("Console"), rows: consoleRows }
        ]
    }

    function applyOption(key, index) {
        var p = StreamingPreferences
        var choice = optionChoices[key][index]
        // Console : rien à voir avec les préférences du flux.
        if (key === "sounds") {
            consoleConfig.sounds = choice.value
            Sounds.enabled = choice.value
        } else if (key === "brightness") {
            SystemStatus.setBrightness(choice.value)
        } else if (key === "volume") {
            SystemStatus.setVolume(choice.value)
        } else if (key === "sleep") {
            consoleConfig.sleepMinutes = choice.value
            rearmSleep()
        } else if (key === "buttons") {
            consoleConfig.buttonLayout = choice.value
        } else if (key === "language") {
            // Moonlight charge la traduction et rafraîchit les liaisons qsTr ; le reste
            // (onglets ci-dessous, menus, toasts) est recalculé à son prochain affichage.
            p.language = choice.value
            p.save()
            p.retranslate()
        }
        if (["sounds", "brightness", "volume", "sleep", "buttons", "language"].indexOf(key) >= 0) {
            refreshOptions()
            return
        }
        // Flux : les réglages du jeu sélectionné s'il en a, sinon les communs.
        var game = homeScreen.app ? homeScreen.app.name : ""
        if (key === "profile") {
            setOwnProfile(game, choice.value)
            refreshOptions()
            return
        }
        var own = game !== "" && gameProfiles()[game] !== undefined
        var s = settingsFor(own ? game : "")
        if (key === "res") {
            s.width = choice.w
            s.height = choice.h
        } else if (key === "fps") {
            s.fps = choice.value
        } else if (key === "rate") {
            s.autoAdjustBitrate = choice.auto === true
            optionAutoBitrate = s.autoAdjustBitrate
            if (!choice.auto)
                s.bitrateKbps = choice.kbps
        } else if (key === "codec") {
            s.videoCodecConfig = choice.value
        } else if (key === "hdr") {
            s.enableHdr = choice.value
        }
        if (optionAutoBitrate)
            s.bitrateKbps = p.getDefaultBitrate(s.width, s.height, s.fps, p.enableYUV444)
        writeSettings(own ? game : "", s)
        refreshOptions()
    }

    // --- Réglages de flux propres à un jeu ---
    // Un jeu peut avoir ses réglages de flux (ConsoleUi/gameProfiles, par nom) ; sinon
    // il suit les réglages communs, ceux des préférences Moonlight. Au lancement d'un
    // jeu qui en a, ils remplacent les communs le temps de la session, sans jamais
    // être enregistrés à leur place.
    readonly property var streamKeys: ["width", "height", "fps", "bitrateKbps", "autoAdjustBitrate",
                                       "videoCodecConfig", "enableHdr"]
    property var commonSaved: null      // réglages communs mis de côté pendant un jeu à profil

    function gameProfiles() { return Library.parse(consoleConfig.gameProfiles, {}) }

    function commonSettings() {
        var p = StreamingPreferences, s = {}
        streamKeys.forEach(function(k) { s[k] = p[k] })
        return s
    }

    function settingsFor(game) {
        var profile = game !== "" ? gameProfiles()[game] : undefined
        return profile ? Object.assign({}, profile) : commonSettings()
    }

    function writeSettings(game, s) {
        if (game !== "") {
            var profiles = gameProfiles()
            profiles[game] = s
            consoleConfig.gameProfiles = JSON.stringify(profiles)
        } else {
            var p = StreamingPreferences
            streamKeys.forEach(function(k) { p[k] = s[k] })
            p.save()
        }
    }

    // Réglages à part pour `game` (copie des communs), ou retour aux communs.
    function setOwnProfile(game, own) {
        var profiles = gameProfiles()
        if (own) profiles[game] = commonSettings()
        else delete profiles[game]
        consoleConfig.gameProfiles = JSON.stringify(profiles)
    }

    function applyGameProfile(game) {
        var profile = gameProfiles()[game]
        if (!profile || commonSaved) return
        commonSaved = commonSettings()
        var p = StreamingPreferences
        streamKeys.forEach(function(k) { p[k] = profile[k] })
    }

    function restoreCommonSettings() {
        if (!commonSaved) return
        var p = StreamingPreferences
        var saved = commonSaved
        commonSaved = null
        streamKeys.forEach(function(k) { p[k] = saved[k] })
    }

    // --- Accueil « Ambiant » ---
    HomeScreen {
        id: homeScreen
        anchors.fill: parent
        focus: true

        readonly property var app: { home.shelfRevision; return home.currentApp() }
        // Fiche du jeu dans la bibliothèque du Companion (absente sans Companion).
        readonly property var info: app ? (home.companionGames[app.name.toLowerCase()] || null) : null

        model: shelfModel
        ready: shelfModel.count > 0
        title: app ? app.name : ""
        logo: info && info.logo ? info.logo : ""
        running: app ? app.running : false
        favorite: app ? home.favoriteNames().indexOf(app.name) >= 0 : false
        source: info ? Format.sourceName(info.source) : ""
        lastPlayed: info ? Format.lastPlayed(info.lastPlayed, new Date()) : ""
        playtime: info ? Format.playtime(info.playtimeSeconds) : ""
        // L'image 16:9 du Companion (cache disque) ; à défaut, la jaquette du jeu,
        // recadrée. Pas de fond pour un jeu sans jaquette (Moonlight donne alors une
        // icône générique).
        backdrop: info && info.background ? info.background
                : app && app.boxart.toString() !== "qrc:/res/no_app_image.png" ? app.boxart : ""
        // La couleur dominante du fond (calculée à part), sinon l'accent.
        readonly property color backdropColor: {
            AmbientColor.revision
            return AmbientColor.colorFor(backdrop)
        }
        ambient: backdropColor.valid ? backdropColor : Theme.accent
        ambientTint: backdropColor.valid
        hostName: home.activeHostName !== "" ? home.activeHostName : qsTr("Recherche…")
        connected: home.activeHostOnline && home.activeHostPaired
        // Batterie et Wi-Fi de la console (-1 : pas de donnée, indicateur masqué), et
        // réseau vers le PC, sondé tant que l'accueil est à l'écran.
        latencyMs: connected ? SystemStatus.latencyMs : -1
        jitterMs: connected ? SystemStatus.jitterMs : -1
        signalStrength: SystemStatus.signalStrength
        batteryPercent: SystemStatus.batteryPercent
        charging: SystemStatus.charging
        controllerBattery: InputStatus.controllerBattery

        optionTabs: home.optionTabs
        optionsHost: home.activeHostName

        // L'accueil entre quand l'animation de démarrage en est à sa sortie ; le logo de
        // la barre haute n'apparaît qu'une fois celui du démarrage arrivé à sa place.
        entryAllowed: bootSplash.entryOpen && !streamCurtain.covering
        statusLogoShown: !bootSplash.visible || bootSplash.mode === "wake"

        staged: searchScreen.shown || pinScreen.shown || companionPairing.shown
                || welcomeScreen.shown || networkScreen.shown
        panelOpen: confirmDialog.opened || homeMenu.opened || wifiSheet.opened

        onLaunchRequested: function(index) { home.launchApp(shelfModel.get(index).appIndex) }
        onFavoriteRequested: home.toggleFavorite()
        onOptionChanged: function(key, index) { home.applyOption(key, index) }
        onOptionAction: function(key) {
            if (key === "wifi") {
                options.close()
                home.openWifi()
            }
        }
        // Oublier ce PC : son appairage Moonlight ET celui du Companion.
        onForgetRequested: {
            options.close()
            CompanionClient.forgetHost()
            if (home.activeComputerIndex >= 0)
                home.computerModel.deleteComputer(home.activeComputerIndex)
        }
    }

    // --- Écrans de message, à la place du héros et de l'étagère ---
    // Un seul à la fois. Priorité à la liaison Companion : une fois faite, c'est
    // lui qui transmet le code Moonlight à Apollo (plus rien à saisir sur le PC).
    readonly property var legendOptions: [ { glyph: "Y", label: qsTr("Options") } ]

    // Recherche du PC (et son réveil), puis chargement de la bibliothèque.
    MessageScreen {
        id: searchScreen
        parent: homeScreen.stage
        shown: home.setupDone && shelfModel.count === 0 && !pinScreen.shown && !companionPairing.shown
        // Un PC connu et réveillable, mais hors ligne : A le réveille.
        readonly property bool canWake: !home.activeHostOnline && home.activeHostWakeable && !home.waking
        focus: shown && canWake
        title: home.activeHostOnline ? qsTr("Chargement de vos jeux")
             : home.waking ? qsTr("Réveil de %1").arg(home.activeHostName)
             : home.wakeFailed ? qsTr("%1 ne répond pas").arg(home.activeHostName)
             : home.activeHostWakeable ? qsTr("%1 est hors ligne").arg(home.activeHostName)
             : qsTr("Recherche de votre PC")
        text: home.activeHostOnline ? ""
            : home.waking ? qsTr("Votre PC démarre, cela peut prendre une minute.")
            : home.wakeFailed ? qsTr("Vérifiez qu'il est branché et que le réveil à distance (Wake-on-LAN) est activé.")
            : home.activeHostWakeable ? qsTr("Il est peut-être éteint ou en veille.")
            : qsTr("Vérifiez qu'il est allumé et sur le même réseau que la console.")
        busy: !canWake
        hints: canWake ? [ { glyph: "A", label: home.wakeFailed ? qsTr("Réessayer") : qsTr("Réveiller") } ]
                         .concat(home.legendOptions)
                       : home.legendOptions
        Keys.onReturnPressed: { home.wakeHost(); Sounds.play("select") }
        Keys.onEnterPressed: { home.wakeHost(); Sounds.play("select") }
    }

    // Liaison Moonlight : le code à saisir une fois sur le PC (repli quand le
    // Companion n'est pas appairé, sinon il soumet ce code à Apollo tout seul).
    MessageScreen {
        id: pinScreen
        parent: homeScreen.stage
        shown: home.setupDone && home.activeHostOnline && !home.activeHostPaired && home.pairingPin !== ""
               && !CompanionClient.paired && !companionPairing.shown
        title: qsTr("Liaison avec %1").arg(home.activeHostName !== "" ? home.activeHostName : qsTr("votre PC"))
        text: qsTr("Saisissez ce code sur votre PC. La console se connectera ensuite toute seule.")
        code: home.pairingPin
        status: home.pairingError !== "" ? qsTr("La liaison a échoué. Nouvelle tentative dans un instant…")
                                         : qsTr("En attente de votre PC…")
        error: home.pairingError !== ""
        busy: !error
        hints: home.legendOptions
    }

    // --- Premier démarrage ---
    MessageScreen {
        id: welcomeScreen
        parent: homeScreen.stage
        shown: !home.setupDone && !home.welcomed
        focus: shown
        title: qsTr("Bienvenue")
        text: qsTr("Quelques secondes de réglages, puis vos jeux.")
        hints: [ { glyph: "A", label: qsTr("Commencer") } ]
        Keys.onReturnPressed: home.welcome()
        Keys.onEnterPressed: home.welcome()
    }
    MessageScreen {
        id: networkScreen
        parent: homeScreen.stage
        shown: !home.setupDone && home.welcomed && home.needsNetwork
        focus: shown
        title: qsTr("Connexion à Internet")
        text: qsTr("Choisissez le réseau Wi-Fi de la maison : la console y retrouvera votre PC.")
        status: WifiSetup.connecting ? qsTr("Connexion…") : ""
        busy: WifiSetup.connecting
        hints: [ { glyph: "A", label: qsTr("Choisir un réseau") } ]
        Keys.onReturnPressed: home.openWifi()
        Keys.onEnterPressed: home.openWifi()
    }
    function welcome() {
        Sounds.play("select")
        welcomed = true
        if (!needsNetwork)
            setupDone = true
    }

    // --- Wi-Fi : la liste des réseaux (un panneau d'options), puis le mot de passe ---
    property string wifiTarget: ""      // réseau en cours de connexion

    readonly property var wifiRows: WifiSetup.networks.map(function(n) {
        return { key: n.ssid, label: n.ssid, bars: n.bars, action: true,
                 value: n.active ? qsTr("Connecté") : n.known ? qsTr("Enregistré") : n.secured ? "" : qsTr("Ouvert") }
    })

    function openWifi() {
        WifiSetup.scan()
        wifiSheet.open()
    }

    function chooseNetwork(ssid) {
        var network = WifiSetup.networks.find(function(n) { return n.ssid === ssid })
        if (!network || network.active) return
        wifiTarget = ssid
        if (network.secured && !network.known) {
            keyboard.prompt = qsTr("Mot de passe de %1").arg(ssid)
            keyboard.open("")
            wifiSheet.close()           // (B sur le clavier vide y ramène)
        } else {
            connectWifi("")
        }
    }

    function connectWifi(password) {
        wifiSheet.close()
        homeScreen.toast(qsTr("Connexion à %1…").arg(wifiTarget))
        WifiSetup.connectTo(wifiTarget, password)
    }

    Connections {
        target: WifiSetup
        function onConnectFinished(ok, error, badPassword) {
            if (ok) {
                homeScreen.toast(qsTr("Connecté à %1").arg(home.wifiTarget))
                return
            }
            homeScreen.toast(error)
            // Mauvais mot de passe : on le redemande aussitôt.
            if (badPassword) {
                keyboard.prompt = qsTr("Mot de passe de %1").arg(home.wifiTarget)
                keyboard.open("")
            }
        }
    }

    // --- Confirmations (« un autre jeu tourne déjà », quitter le jeu, éteindre…) ---
    ConsoleDialog {
        id: confirmDialog
        anchors.fill: parent
        property var pending: null
        // Pose la question ; `action` est appelée si l'on confirme.
        function ask(title, message, confirmLabel, action) {
            confirmDialog.title = title
            confirmDialog.message = message
            confirmDialog.confirmLabel = confirmLabel
            pending = action
            open()
        }
        onConfirmed: if (pending) pending()
        onClosed: homeScreen.forceActiveFocus()
    }

    // Panneau des réseaux : sur le canevas, comme le panneau d'options.
    Item {
        width: home.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        OptionsSheet {
            id: wifiSheet
            anchors.fill: parent
            title: qsTr("Wi-Fi")
            subtitle: WifiSetup.currentNetwork !== "" ? qsTr("Connecté à %1").arg(WifiSetup.currentNetwork)
                    : WifiSetup.scanning ? qsTr("Recherche des réseaux…") : qsTr("Non connecté")
            connected: WifiSetup.online
            tabs: [ { label: qsTr("Wi-Fi"), rows: home.wifiRows } ]
            onActionRequested: function(key) { home.chooseNetwork(key) }
            onClosed: if (!keyboard.opened) homeScreen.forceActiveFocus()
        }
        // Tant que le panneau est ouvert, la liste se met à jour.
        Timer { interval: Theme.wifiRescan; repeat: true; running: wifiSheet.opened; onTriggered: WifiSetup.scan() }
    }

    OnScreenKeyboard {
        id: keyboard
        anchors.fill: parent
        qwerty: home.english
        minLength: 8                    // WPA : 8 caractères au moins
        onAccepted: function(text) {
            home.connectWifi(text)
            homeScreen.forceActiveFocus()   // le clavier fermé ne doit plus rien avaler
        }
        onCancelled: home.openWifi()
    }

    // --- Menu Home : reprendre ou quitter le jeu en cours, veille, redémarrage, extinction ---
    ConsoleDialog {
        id: homeMenu
        anchors.fill: parent
        title: qsTr("Menu")
        onChosen: function(key) { home.homeMenuChosen(key) }
        onClosed: if (!confirmDialog.opened) homeScreen.forceActiveFocus()
    }

    // --- Au-dessus de la pile d'écrans de Moonlight ---
    // L'écran de lancement doit rester visible pendant que la page de connexion
    // d'origine (StreamSegue) travaille : lui et le dialog de mise à jour vivent
    // donc dans la fenêtre, pas dans cet écran-ci, que la pile masque alors.
    Item {
        id: topLayer
        parent: home.Window.window ? home.Window.window.contentItem : home
        anchors.fill: parent
        z: 100

        LaunchScreen {
            id: launchScreen
            anchors.fill: parent
            onOpened: {
                home.launchOpened = true
                home.maybeStartStream()
            }
            // B : annulation pendant la préparation par le Companion, ou fermeture
            // de l'écran après un échec.
            onCancelRequested: {
                if (error === "" && !home.launchWaking)
                    CompanionClient.cancelLaunch()
                Sounds.play("back")
                home.endLaunch()
                homeScreen.forceActiveFocus()
            }
        }

        // Animation de démarrage, le temps que l'accueil se mette en place.
        BootSplash {
            id: bootSplash
            anchors.fill: parent
            z: 2
            // Debug (BOOT_ANIMATION.md §10) : vitesse, variante, boucle, système en retard.
            speed: Number(SystemStatus.env("COCOOS_BOOT_SPEED")) || 1
            mode: SystemStatus.env("COCOOS_BOOT_MODE") === "wake" ? "wake" : "cold"
            loop: SystemStatus.env("COCOOS_BOOT_LOOP") === "1"
            readonly property real fakeDelay: Number(SystemStatus.env("COCOOS_BOOT_FAKE_DELAY_MS")) || 0
            systemReady: home.bootReady && t >= fakeDelay
            stepText: home.bootStep
            statusBarLogo: homeScreen.statusLogo
            onSoundCue: function(name) { Sounds.play("boot-" + name) }
            onFinished: {
                console.info("[console-ui] Démarrage (" + mode + ") : " + Math.round(t) + " ms"
                             + (mode === "cold" && readyAt > Boot.loaderShowAt ? ", avec chargeur (prêt à "
                                + Math.round(readyAt) + " ms)" : "")
                             + ", image la plus longue " + longestFrame.toFixed(1) + " ms")
                if (mode === "cold")
                    homeScreen.forceActiveFocus()
                // Leurs premiers relevés (D-Bus, synchrones) attendaient la fin de la
                // séquence : rien ne doit bloquer le fil GUI pendant l'animation.
                SystemStatus.start()
                WifiSetup.start()
            }
        }

        // Rideau CocoOS entre un jeu et l'accueil : par-dessus tout, animation de
        // démarrage comprise (il ne sert jamais en même temps qu'elle).
        StreamCurtain {
            id: streamCurtain
            anchors.fill: parent
            z: 3
            onLifted: homeScreen.forceActiveFocus()
        }

        // Veille de l'écran : par-dessus tout le reste.
        SleepScreen {
            id: sleepScreen
            anchors.fill: parent
            z: 1
            onWoke: {
                var item = home.focusBeforeSleep
                home.focusBeforeSleep = null
                if (item) item.forceActiveFocus()
                else homeScreen.forceActiveFocus()
                home.rearmSleep()
                home.playWake()
            }
        }

        // Mise à jour requise (piloté par le Companion, §9.1)
        ConsoleDialog {
            id: updateDialog
            anchors.fill: parent
            confirmLabel: qsTr("Mettre à jour")
            cancelLabel: qsTr("Annuler")
            property string size: ""
            // Distingue « confirmé » de « simplement fermé » : ConsoleDialog émet
            // confirmed() PUIS closed() quand on valide → sans ce flag on enverrait
            // accept=true puis accept=false.
            property bool answered: false
            onConfirmed: {
                answered = true
                CompanionClient.respondUpdate(true)
                // Une étape de plus, juste après la préparation.
                var steps = launchScreen.steps.slice()
                steps.splice(1, 0, size !== "" ? qsTr("Mise à jour de %1 sur le PC").arg(size)
                                               : qsTr("Mise à jour sur le PC"))
                launchScreen.steps = steps
                launchScreen.stepProgress = 0
                launchScreen.step = 1
            }
            onClosed: {
                if (!answered) {
                    CompanionClient.respondUpdate(false)   // refus = retour à l'accueil (§9.1 ABORTED)
                    home.endLaunch()
                    homeScreen.forceActiveFocus()
                } else {
                    launchScreen.forceActiveFocus()        // garde B actif pendant la maj
                }
            }
        }
    }

    // --- Saisie du code d'appairage Companion (6 chiffres, host → console) ---
    CompanionPairing {
        id: companionPairing
        parent: homeScreen.stage
        focus: shown            // seul écran de message qui prend la manette
        // « Découvert mais pas appairé » : on a un fingerprint live mais pas de token.
        shown: home.setupDone && CompanionClient.certFingerprint !== "" && !CompanionClient.paired
        hostName: home.activeHostName !== "" ? home.activeHostName : CompanionClient.hostName
        // À l'apparition : on demande au host de GÉNÉRER + AFFICHER son code (pair/start).
        // L'utilisateur le lit sur le PC et le saisit ici ; la validation = pair/confirm.
        onShownChanged: if (shown) {
            reset()
            CompanionClient.startPairing(qsTr("Console"))
        }
        onSubmitted: function(code) { CompanionClient.confirmPairing(code) }
    }

    // --- Branchement des événements Companion (REST + WS) ---
    Connections {
        target: CompanionClient

        function onPairingFailed(code) {
            companionPairing.busy = false
            companionPairing.errorText = (code === "PAIR_EXPIRED")
                ? qsTr("Code expiré — relancez la liaison depuis le PC.")
                : qsTr("Code incorrect — réessayez.")
        }
        function onLibraryChanged() { home.refreshCompanionGames() }

        function onPairingSucceeded() {
            companionPairing.errorText = ""
            // Si un appairage Moonlight est en cours, soumettre son PIN maintenant.
            if (home.pairingInFlight && home.pairingPin !== "")
                CompanionClient.submitMoonlightPin(home.pairingPin)
        }

        // États de la machine de lancement du host (protocol.md §9.1), ramenés
        // aux étapes de l'écran de lancement.
        function onLaunchStateChanged(sessionId, gameId, state) {
            if (home.launchIndex < 0) return
            if (state === "CHECKING") {
                launchScreen.step = 0
            } else if (state === "UP_TO_DATE" || state === "ARMING") {
                launchScreen.stepProgress = 1
                launchScreen.step = launchScreen.steps.length - 2   // « Lancement de … »
            }
        }
        function onUpdateRequired(sessionId, gameId, sizeBytes) {
            if (home.launchIndex < 0) return
            updateDialog.size = home.humanSize(sizeBytes)
            updateDialog.title = qsTr("Mise à jour requise")
            updateDialog.message = sizeBytes > 0
                ? qsTr("Ce jeu doit être mis à jour (%1) avant d'y jouer.").arg(updateDialog.size)
                : qsTr("Ce jeu doit être mis à jour avant d'y jouer.")
            updateDialog.answered = false
            updateDialog.open()
        }
        function onUpdateProgress(sessionId, pct, bytesDone, bytesTotal) {
            if (home.launchIndex >= 0)
                launchScreen.stepProgress = pct / 100
        }
        // L'app Apollo du jeu est prête (virtual display armé) : on peut démarrer
        // la session Moonlight dessus (mapping par nom, §4).
        function onLaunchReady(sessionId, apolloAppId) {
            if (home.launchIndex < 0) return
            var index = home.findAppIndexByName(apolloAppId)
            if (index >= 0)
                home.launchIndex = index
            home.launchReady = true
            home.maybeStartStream()
        }
        function onLaunchFailed(sessionId, code, message) {
            if (home.launchIndex < 0) return
            launchPress.stop()
            if (!launchScreen.active) {
                homeScreen.launching = true
                launchScreen.open()
            }
            launchScreen.progressShown = true
            launchScreen.error = (message && message !== "") ? message : code
        }
    }
}
