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

import "idle"
import "settings"
import "Format.js" as Format
import "Library.js" as Library
import "Search.js" as Search
import "StreamProfiles.js" as StreamProfiles
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
    property alias preferredHost: consoleConfig.preferredHost   // PC choisi (ChoixPC)
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
        property bool reduceMotion: false   // « Réduire les animations » (Theme.reducedMotion)
        // « Vibrations » : intensité des motifs de la manette (InputStatus.feedback, haptics.json) :
        // 0 coupées, 0,6 légères, 1 fortes. L'ancienne clé booléenne `rumble` est ignorée.
        property real haptics: 0.6
        property string lastGame: ""        // dernier jeu lancé : l'accueil s'ouvre dessus
        property string favorites: "[]"     // jeux épinglés (X), le dernier épinglé en tête (JSON)
        property string recentGames: "{}"   // date de la dernière partie lancée d'ici, par jeu (JSON, ms)
        // Veille après tant de secondes d'inactivité ; 0 = jamais. (Remplace `sleepMinutes`, en
        // minutes et à 5 par défaut : tout le monde repart des 120 s de l'écran de veille.)
        property int idleSeconds: Theme.idleSeconds
        property string buttonLayout: "auto"   // glyphes : auto (la manette branchée), xbox, playstation, nintendo
        property bool setupDone: false      // premier démarrage fait (bienvenue, réseau)
        property string gameProfiles: "{}"  // réglages de flux propres à un jeu, par nom (JSON)
        // Profil de flux des réglages communs (StreamProfiles.js) ; « manual » : les réglages
        // tels quels. Un jeu à réglages à part garde le sien dans gameProfiles.
        property string streamProfile: StreamProfiles.DEFAULT
        // « Réglages avancés » (onglet Flux) : les réglages du flux un à un, les chiffres des
        // profils, les réglages à part d'un jeu. Éteint, l'essentiel seulement.
        property bool advancedSettings: false
        property string recentSearches: "[]"   // recherches récentes, la dernière en tête (JSON)
        property string volumeHud: "left"      // indicateur du volume : left, center, right
        property string preferredHost: ""      // PC choisi (ChoixPC) ; vide : le premier trouvé
    }

    Component.onCompleted: {
        useIdleMock()
        hideUpstreamChrome()
        Sounds.enabled = consoleConfig.sounds
        Theme.reducedMotion = consoleConfig.reduceMotion

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
    // Start (≡) arrive avec la même touche que Y : la recherche, plutôt que les options.
    // PC hors ligne : ≡ ouvre les réglages du réseau, Y le choix d'un autre PC.
    Keys.onHangupPressed: {
        var start = InputStatus.startHeld()
        if (homeScreen.hostOffline) start ? openWifi() : openHostPicker()
        else start ? openSearch() : homeScreen.options.open()
    }
    // Au clavier, la touche Origine (Home) tient lieu du bouton Home de la manette.
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Home || event.key === Qt.Key_HomePage) {
            event.accepted = true
            homeButton()
        }
    }
    Keys.onEscapePressed: homeScreen.dismissNotification()     // accueil : sinon rien à fermer
    // Touches de volume de la console (dans le jeu : keyboard.cpp) : ±5 %, et la capsule (MotionHud).
    Shortcut { sequence: "Volume Up"; autoRepeat: true; onActivated: home.volumeKey(1) }
    Shortcut { sequence: "Volume Down"; autoRepeat: true; onActivated: home.volumeKey(-1) }
    function volumeKey(direction) {
        if (SystemStatus.volume < 0) return
        var value = SystemStatus.volume
        var floor = Math.floor(value / 5) * 5
        var next = Math.max(0, Math.min(100, direction > 0 ? floor + 5 : (value === floor ? floor - 5 : floor)))
        volumeHud.level = next / 100
        volumeHud.press(direction, next === value)
        if (next === value) {
            Sounds.play("volume_limit")
            return
        }
        SystemStatus.setVolume(next)
        Sounds.play("volume_tick")
        rearmSleep()
    }
    // Ctrl + Maj + Alt + Tab : le bouton Home au clavier, d'où que soit le focus (aussi en
    // jeu : keyboard.cpp). Avec Maj, Qt reçoit Tab comme Backtab.
    Shortcut {
        sequences: ["Ctrl+Alt+Shift+Tab", "Ctrl+Alt+Shift+Backtab"]
        onActivated: home.homeButton()
    }

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

    // La vignette sélectionnée (élément de shelfModel) : une app du PC, ou un jeu pas
    // encore installé (appIndex < 0, gameId du Companion).
    function currentTile() {
        if (shelfModel.count === 0) return null
        return shelfModel.get(Math.max(0, Math.min(homeScreen.currentIndex, shelfModel.count - 1)))
    }

    // --- Étagère : les apps du PC sans les utilitaires, favoris puis jeux récents ---
    // Ses index ne sont PAS ceux d'AppModel : chaque élément porte son `appIndex`.
    ListModel { id: shelfModel }        // name, appIndex, boxart, cover, publisher, favorite, gameId, pending, progress
    property int shelfRevision: 0       // change à chaque réordonnancement (liaisons)
    // Collection de l'étagère affichée (Library.collection) et celles qu'on peut choisir.
    property string collection: "all"
    // Aucun jeu à montrer (pas seulement une catégorie vide, comme Favoris) : PC à trouver,
    // bibliothèque à charger.
    readonly property bool libraryEmpty: shelfModel.count === 0 && collection === "all"
    property var collections: ["all"]
    readonly property var collectionNames: ({ all: qsTr("Tout"), favorites: qsTr("Favoris"),
                                              recent: qsTr("Récents"), apps: qsTr("Apps") })

    // LB / RB sur le carrousel : la catégorie voisine ; le carrousel arrive de ce côté.
    function switchCollection(dir) {
        var next = collections.indexOf(collection) + dir
        if (next < 0 || next >= collections.length) {
            Sounds.play("edge")
            return
        }
        homeScreen.categoryStart(dir)
        collection = collections[next]
        Sounds.play(dir > 0 ? "category_next" : "category_prev")
        rebuildShelf(true)
        homeScreen.shelf.slideIn(dir)
    }
    // Le jeu en cours sur le PC (son nom ; vide = aucun) : un point sur sa vignette.
    readonly property string runningGame: {
        for (var i = 0; i < appViewer.count; i++) {
            var app = appViewer.objectAt(i)
            if (app && app.running) return app.name
        }
        return ""
    }

    function favoriteNames() { return Library.parse(consoleConfig.favorites, []) }

    // Dernière partie, en ms : lancée d'ici, ou d'après le Companion (jouée sur le PC).
    function lastPlayedTime(name, recent) {
        var info = companionGames[name.toLowerCase()]
        var companion = info && info.lastPlayed ? Date.parse(info.lastPlayed) : 0
        return Math.max(recent[name] || 0, companion || 0)
    }

    // `switching` : on vient de changer de collection ; si le jeu affiché n'y est pas, la
    // sélection repart du premier.
    function rebuildShelf(switching) {
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
        var ordered = Library.order(apps, function(name) { return home.lastPlayedTime(name, recent) })

        // Le jeu affiché le reste : la sélection le suit à sa nouvelle place. Au
        // chargement, avant l'entrée de l'accueil, c'est le dernier jeu lancé.
        var selected = homeScreen.ready && homeScreen.currentIndex < shelfModel.count
                       ? shelfModel.get(homeScreen.currentIndex).name : consoleConfig.lastGame
        // Puis, en fin d'étagère, les jeux du PC pas encore installés (téléchargeables) — PC en
        // ligne seulement : hors ligne, l'accueil doit rester sur l'écran de recherche / réveil.
        var pending = activeHostOnline
            ? Library.pendingTiles(companionList, apps.map(function(a) { return a.name }), downloads) : []
        // Jaquette : celle de Playnite (Companion, 600 × 848, le format du carrousel) d'abord,
        // celle d'Apollo (600 × 800) à défaut.
        var info = function(name) { return companionGames[name.toLowerCase()] || null }
        var all = ordered.map(function(a) {
            var i = info(a.name)
            return { name: a.name, appIndex: a.appIndex, boxart: a.boxart, cover: i && i.cover ? i.cover : "",
                     publisher: i ? Format.publisher(i) : "",
                     favorite: favorites.indexOf(a.name) >= 0, gameId: "", pending: false, progress: -1 }
        }).concat(pending.map(function(g) {
            return { name: g.name, appIndex: -1, boxart: "", cover: g.cover || "", publisher: Format.publisher(g),
                     favorite: favorites.indexOf(g.name) >= 0, gameId: g.id, pending: true,
                     progress: home.downloadFraction(g.id) }
        }))
        // La collection affichée ; vidée (dernier favori détaché), on revient à tout.
        var played = function(name) { return home.lastPlayedTime(name, recent) }
        collections = Library.collections(all, played)
        if (collections.indexOf(collection) < 0) {
            collection = "all"
            switching = true
        }
        allTiles = all
        var items = Library.collection(all, collection, played)
        Library.sync(shelfModel, items)
        shelfRevision++
        var index = items.findIndex(function(a) { return a.name === selected })
        if (index >= 0)
            homeScreen.currentIndex = index
        else if (switching)
            homeScreen.currentIndex = 0
        maybeDirectLaunch()
    }

    property var allTiles: []           // tous les jeux de l'étagère, toutes catégories (recherche)

    // --- Recherche (≡ à l'accueil) : titres, éditeurs et genres de toute la bibliothèque ---
    function openSearch() {
        findScreen.games = allTiles.map(function(t) {
            var i = companionGames[t.name.toLowerCase()] || {}
            return { name: t.name, developers: i.developers || [], publishers: i.publishers || [],
                     genres: i.genres || [], releaseDate: i.releaseDate || "",
                     cover: t.cover || t.boxart || "", background: i.background || "" }
        })
        findScreen.open()
    }
    // Un résultat choisi : la recherche est retenue, l'accueil montre le jeu (catégorie Tout).
    function searchChosen(index, query) {
        consoleConfig.recentSearches = JSON.stringify(Search.remember(Library.parse(consoleConfig.recentSearches, []), query))
        var name = findScreen.games[index].name
        if (collection !== "all") {
            collection = "all"
            rebuildShelf(true)
        }
        for (var i = 0; i < shelfModel.count; i++)
            if (shelfModel.get(i).name === name) homeScreen.currentIndex = i
    }

    function shelfIndexOf(appIndex) {
        for (var i = 0; i < shelfModel.count; i++)
            if (shelfModel.get(i).appIndex === appIndex) return i
        return -1
    }

    // X : épingle le jeu en tête de l'étagère, ou le détache.
    // X : ajoute le jeu aux favoris, ou l'en retire (bannière de MotionFavori).
    function toggleFavorite() {
        var tile = currentTile()
        if (!tile) return
        var favorites = Library.toggled(favoriteNames(), tile.name)
        consoleConfig.favorites = JSON.stringify(favorites)
        rebuildShelf()
        homeScreen.favoriteFeedback(favorites.indexOf(tile.name) >= 0)
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
        // Le PC choisi (ChoixPC), même hors ligne : l'accueil dit alors qu'il l'est.
        for (var p = 0; p < hostScanner.count && consoleConfig.preferredHost !== ""; p++) {
            var pref = hostScanner.objectAt(p)
            if (pref && pref.hostName === consoleConfig.preferredHost && pref.isPaired) {
                if (activeComputerIndex !== p) activeComputerIndex = p
                updateActiveHostView(pref)
                return
            }
        }
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
    property var companionList: []      // la même, en liste : ses jeux à installer finissent l'étagère

    function refreshCompanionGames() {
        var byName = {}
        var games = CompanionClient.games()
        for (var i = 0; i < games.length; i++)
            byName[(games[i].name || "").toLowerCase()] = games[i]
        // La bibliothèque arrive alors que l'accueil est déjà là (MotionJaquettes) : son signal.
        if (games.length > 0 && companionList.length === 0 && homeScreen.entered)
            Sounds.play("library_ready")
        companionList = games
        companionGames = byName
        Qt.callLater(rebuildShelf)          // l'ordre suit aussi les parties jouées sur le PC
    }

    // --- Téléchargement à distance d'un jeu pas encore installé (Companion, /v1/downloads) ---
    // Par gameId : { state, bytesDone, bytesTotal } (DOWNLOAD_STATE). DONE reste jusqu'à ce que
    // le jeu soit installé : sa vignette disparaît alors, son app arrive (~30 s au plus).
    property var downloads: ({})

    function setDownload(gameId, state, bytesDone, bytesTotal) {
        var all = Object.assign({}, downloads)
        if (state === "") delete all[gameId]
        else all[gameId] = { state: state, bytesDone: bytesDone, bytesTotal: bytesTotal }
        downloads = all
        Qt.callLater(rebuildShelf)
    }

    // Avancement 0..1 (barre de la vignette) ; -1 : pas de téléchargement en cours.
    function downloadFraction(gameId) {
        var d = downloads[gameId]
        if (!d || d.state === "DONE") return -1
        return d.bytesTotal > 0 ? d.bytesDone / d.bytesTotal : 0
    }

    function downloadPercent(d) {
        return d.bytesTotal > 0 ? qsTr("%1 % de %2").arg(Math.floor(100 * d.bytesDone / d.bytesTotal))
                                                    .arg(humanSize(d.bytesTotal)) : ""
    }

    // Note du héros pour un jeu pas encore installé. Elle ne change qu'avec l'état (elle
    // s'anime à chaque changement) : le pourcentage vit dans la barre de la vignette.
    function pendingNote(gameId, info) {
        var d = downloads[gameId]
        if (info && info.isInstalled || d && d.state === "DONE") return qsTr("Installé — prêt dans un instant")
        if (!d) return qsTr("Non installé")
        return d.state === "PAUSED" ? qsTr("Téléchargement en pause") : qsTr("Téléchargement en cours")
    }

    // A sur un jeu pas encore installé : le télécharger tout de suite (zéro friction), ou
    // ouvrir le menu de son téléchargement.
    function pendingAction(gameId, name) {
        var d = downloads[gameId]
        var info = companionGames[name.toLowerCase()]
        if (info && info.isInstalled || d && d.state === "DONE") {
            homeScreen.toast(qsTr("%1 arrive dans un instant").arg(name))
            return
        }
        if (!d) {
            CompanionClient.download(gameId)
            setDownload(gameId, "DOWNLOADING", 0, 0)    // le PC prépare (Steam redémarre)
            Sounds.play("select")
            homeScreen.toast(qsTr("Téléchargement de %1 lancé sur %2").arg(name).arg(activeHostName))
            return
        }
        var paused = d.state === "PAUSED"
        var amount = downloadPercent(d)
        downloadMenu.gameId = gameId
        downloadMenu.title = name
        downloadMenu.message = paused
            ? (amount !== "" ? qsTr("En pause à %1.").arg(amount) : qsTr("En pause."))
            : (amount !== "" ? qsTr("Téléchargement : %1.").arg(amount) : qsTr("Le PC prépare le téléchargement."))
        downloadMenu.actions = [
            paused ? { label: qsTr("Reprendre"), key: "resume" } : { label: qsTr("Mettre en pause"), key: "pause" },
            { label: qsTr("Annuler le téléchargement"), key: "cancel" }
        ]
        downloadMenu.open()
    }

    function downloadMenuChosen(key) {
        var gameId = downloadMenu.gameId
        var name = downloadMenu.title
        if (key === "resume") {
            CompanionClient.download(gameId)
        } else if (key === "pause") {
            CompanionClient.pauseDownload(gameId)
        } else if (key === "cancel") {
            confirmDialog.ask(qsTr("Annuler le téléchargement ?"),
                              qsTr("Les fichiers déjà téléchargés de %1 seront supprimés du PC.").arg(name),
                              qsTr("Annuler le téléchargement"), function() { CompanionClient.cancelDownload(gameId) },
                              qsTr("Téléchargement annulé"))
        }
    }

    // --- Désinstallation à distance (fiche du jeu, Companion) ---
    // Par gameId : "UNINSTALLING" tant que le PC y travaille (UNINSTALL_STATE).
    property var uninstalls: ({})

    function setUninstall(gameId, state) {
        var all = Object.assign({}, uninstalls)
        if (state === "") delete all[gameId]
        else all[gameId] = state
        uninstalls = all
    }

    function gameName(gameId) {
        var game = companionList.find(function(g) { return g.id === gameId })
        return game ? game.name : ""
    }

    function confirmUninstall(info) {
        var size = info.installSizeBytes > 0 ? humanSize(info.installSizeBytes) : ""
        confirmDialog.ask(qsTr("Désinstaller %1 ?").arg(info.name),
                          size !== "" ? qsTr("Le jeu sera supprimé du PC (%1 libérés). Vous pourrez le retélécharger depuis la console.").arg(size)
                                      : qsTr("Le jeu sera supprimé du PC. Vous pourrez le retélécharger depuis la console."),
                          qsTr("Désinstaller"), function() {
                              CompanionClient.uninstall(info.id)
                              home.setUninstall(info.id, "UNINSTALLING")
                          }, qsTr("Désinstallation lancée"))
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
    readonly property bool bootReady: !libraryEmpty || welcomeScreen.shown || networkScreen.shown
        || companionPairing.shown || pinScreen.shown
        || (searchScreen.shown && ((activeComputerIndex >= 0 && !activeHostOnline && !activeHostStatusUnknown)
                                   || (hostScanner.count === 0 && discoveryGrace)))
    readonly property string bootStep: hostScanner.count === 0 && !discoveryGrace ? qsTr("Démarrage des services")
        : !activeHostOnline ? qsTr("Recherche de l’hôte")
        : !activeHostPaired || (CompanionClient.paired && !CompanionClient.eventsConnected) ? qsTr("Connexion à l’hôte")
        : qsTr("Chargement de la bibliothèque")

    // --- Veille de l'écran ---
    // Sans action à l'accueil pendant consoleConfig.idleSeconds, l'écran passe au
    // noir. Jamais pendant un lancement (ni pendant un flux : Qt est alors suspendu).
    readonly property bool onTop: StackView.view === null || StackView.status === StackView.Active
    readonly property bool sleepAllowed: onTop && !launchScreen.active && consoleConfig.idleSeconds > 0
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
        interval: consoleConfig.idleSeconds * 1000
        onTriggered: {
            console.info("[console-ui] Veille après " + consoleConfig.idleSeconds + " s d'inactivité (" + home.idleStatus.state + ")")
            home.focusBeforeSleep = home.Window.activeFocusItem
            sleepScreen.sleep()
        }
    }

    // --- Bouton Home ---
    // À l'accueil : ouvre (ou referme) le menu Home. En veille : réveille. Pendant un
    // jeu, c'est la session qui le reçoit : elle rend la main à l'accueil (gamepad.cpp).
    property double homeGuardUntil: 0

    // Vibrations : la manette suit certains sons (butée, refus, confirmation, lancement).
    Connections {
        target: Sounds
        function onPlayed(name) { InputStatus.feedback(name, consoleConfig.haptics) }
    }

    Connections {
        target: InputStatus
        function onActivity() { home.rearmSleep() }
        function onHomePressed() { home.homeButton() }
        // LB / RB, LT / RT, R3 : lus dans SDL (la navigation upstream ne les traduit pas).
        function onBumperPressed(direction) {
            if (keyboard.opened) keyboard.moveCursor(direction)
            else if (findScreen.opened) findScreen.panel.moveCursor(direction)
            else if (settingsScreen.opened) settingsScreen.focusContent(!settingsScreen.contentFocused)
            else if (homeScreen.options.opened) homeScreen.options.switchTab(direction)
            else if (homeScreen.shelf.activeFocus) home.switchCollection(direction)
        }
        function onTriggerPressed(direction) {
            if (keyboard.opened) { if (direction < 0) keyboard.shift() }
            else if (findScreen.opened) { if (direction < 0) findScreen.panel.shift() }
            else if (homeScreen.shelf.activeFocus) homeScreen.shelf.jump(direction)
        }
        function onStickPressed(side) {
            if (keyboard.opened && side > 0) keyboard.toggleReveal()
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

    // --- Données de l'écran de veille (idle/, docs/design/idle/) ---
    // Ce que la console sait déjà : le PC, le réseau, la batterie, le jeu qui tourne sur le PC
    // (sa jaquette Apollo, et l'heure de son lancement d'ici), le dernier jeu lancé.
    // TODO(HostCompanion) : téléchargements, jaquettes Playnite, début réel de la partie.
    // COCOOS_IDLE_MOCK=1 (+ COCOOS_IDLE_STATE=game|gameDownload|download|rest, COCOOS_IDLE_NETWORK=
    // 4g|5g) : les données de test des maquettes, pour voir les quatre écrans sur la console.
    // TODO(module 5G) : la 4G / 5G réelle (kind "4g" / "5g", qualité) viendra de ModemManager.
    function tileByName(name) {
        for (var i = 0; i < shelfModel.count; i++)
            if (shelfModel.get(i).name === name) return shelfModel.get(i)
        return null
    }
    function idleGame(name) {
        var tile = tileByName(name)
        var info = companionGames[name.toLowerCase()]
        return { title: name, coverUrl: tile ? tile.boxart : "",
                 publisher: info && info.publishers && info.publishers.length ? info.publishers[0] : "",
                 genre: info && info.genres && info.genres.length ? info.genres[0] : "" }
    }
    IdleStatus {
        id: liveIdleStatus
        readonly property var recent: Library.parse(consoleConfig.recentGames, {})
        host: ({ name: home.activeHostName, reachable: home.activeHostOnline,
                 inGame: home.runningGame !== "", sleeping: false })
        network: SystemStatus.wifi.ssid !== undefined
                 ? { kind: "wifi", latencyMs: SystemStatus.latencyMs,
                     // Force NetworkManager (%) → dBm, à peu près : 2 × (dBm + 100).
                     rssiDbm: SystemStatus.wifi.strength / 2 - 100 }
                 : { kind: "ethernet", latencyMs: SystemStatus.latencyMs }
        battery: ({ percent: SystemStatus.batteryPercent, charging: SystemStatus.charging,
                    minutesLeft: SystemStatus.batteryDetails.minutes !== undefined ? SystemStatus.batteryDetails.minutes : -1 })
        session: home.runningGame !== ""
                 ? { active: true, game: home.idleGame(home.runningGame),
                     connectedAt: recent[home.runningGame] ? new Date(recent[home.runningGame]) : null }
                 : { active: false }
        lastGame: consoleConfig.lastGame !== "" && recent[consoleConfig.lastGame]
                  ? { title: consoleConfig.lastGame, coverUrl: home.idleGame(consoleConfig.lastGame).coverUrl,
                      lastPlayedAt: new Date(recent[consoleConfig.lastGame]) }
                  : null
    }
    property IdleStatus idleStatus: liveIdleStatus
    function useIdleMock() {
        if (SystemStatus.env("COCOOS_IDLE_MOCK") !== "1") return
        var mock = Qt.createQmlObject('import "idle"; IdleStatusMock {}', home, "IdleStatusMock")
        mock.scenario = SystemStatus.env("COCOOS_IDLE_STATE") || "game"
        mock.networkKind = SystemStatus.env("COCOOS_IDLE_NETWORK")       // "4g", "5g"…
        idleStatus = mock
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
        if (powerMenu.opened) {
            powerMenu.close(false)
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
        // L'alimentation : le menu de MenuAlimentation (directement, sans partie en cours).
        var power = SystemStatus.powerActions.length > 0
        if (running === "") {
            if (power) powerMenu.open()
            return
        }
        if (power) actions.push({ label: qsTr("Alimentation"), key: "power" })
        homeMenu.message = running !== "" ? qsTr("%1 est en cours sur %2.").arg(running).arg(activeHostName) : ""
        homeMenu.actions = actions
        homeMenu.open()
    }

    // --- Touche power (MotionAlimentation, MotionVeille) : appui court, la veille ; long, le menu ---
    Connections {
        target: InputStatus
        function onPowerKey(pressed) {
            if (pressed) {
                if (sleepScreen.asleep) sleepScreen.wake()
                else if (!powerMenu.opened && home.onTop && !streamCurtain.covering) powerMenu.startHold()
                return
            }
            if (powerMenu.holding && !powerMenu.releaseHold())
                home.powerAction("suspend")
        }
    }
    // Une action d'alimentation (menu, touche power) ; la veille et l'extinction s'animent.
    function powerAction(key) {
        if (SystemStatus.powerActions.indexOf(key) < 0) return
        console.info("[console-ui] Alimentation : " + key)
        SystemStatus.power(key)
    }
    readonly property string powerHeader: {
        var d = SystemStatus.batteryDetails || {}
        if (SystemStatus.batteryPercent < 0) return ""
        var minutes = d.minutes
        if (SystemStatus.charging || !(minutes > 0))
            return qsTr("Batterie %1 %").arg(SystemStatus.batteryPercent)
        var life = minutes < 60 ? qsTr("%1 min").arg(minutes)
                 : qsTr("%1 h %2").arg(Math.floor(minutes / 60)).arg(("0" + minutes % 60).slice(-2))
        return qsTr("Batterie %1 % · environ %2").arg(SystemStatus.batteryPercent).arg(life)
    }

    // Batterie très faible (5 %, hors charge) : l'île le dit, puis la veille au bout de 2 min si la
    // console n'est toujours pas branchée (dans le jeu, streammenu fait de même).
    readonly property bool batteryCritical: SystemStatus.batteryPercent >= 0 && !SystemStatus.charging
                                            && SystemStatus.batteryPercent <= Theme.batteryCritical
    onBatteryCriticalChanged: {
        if (!batteryCritical) return criticalSleep.stop()
        homeScreen.notify({ icon: "battery", accent: true,
                            title: qsTr("Batterie très faible · %1 %").arg(SystemStatus.batteryPercent),
                            text: qsTr("Mise en veille dans 2 min") })
        criticalSleep.restart()
    }
    Timer {
        id: criticalSleep
        interval: Theme.batteryCriticalSleep
        onTriggered: if (home.batteryCritical && SystemStatus.powerActions.indexOf("suspend") >= 0) {
            console.info("[console-ui] Batterie très faible : mise en veille")
            SystemStatus.power("suspend")
        }
    }

    function homeMenuChosen(key) {
        var running = appModel ? appModel.getRunningAppName() : ""
        if (key === "resume") {
            var index = findAppIndexByName(running)
            if (index >= 0) launchApp(index)
        } else if (key === "quit") {
            confirmDialog.ask(qsTr("Quitter %1 ?").arg(running),
                              qsTr("Toute progression non sauvegardée sera perdue."),
                              qsTr("Quitter"), function() { home.quitRunningGame() }, qsTr("Fermeture du jeu"))
        } else if (key === "power") {
            Qt.callLater(powerMenu.open)    // (après la fermeture du menu Home, qui rend la manette à l'accueil)
        } else if (key === "suspend") {
            SystemStatus.power("suspend")
        } else if (key === "reboot") {
            confirmDialog.ask(qsTr("Redémarrer la console ?"), "", qsTr("Redémarrer"),
                              function() { SystemStatus.power("reboot") }, qsTr("Redémarrage"))
        } else if (key === "poweroff") {
            confirmDialog.ask(qsTr("Éteindre la console ?"), "", qsTr("Éteindre"),
                              function() { SystemStatus.power("poweroff") }, qsTr("Extinction"))
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
    property bool hostJustWoke: false    // « … est en ligne » dans la pastille
    Timer { id: justWoke; interval: Theme.hostOnlineShow; onTriggered: home.hostJustWoke = false }

    // La pastille du PC (StatusBar.hostState) et l'état « PC hors ligne » de l'accueil : connu,
    // appairé, hors ligne, et ni réveillable ni en train de se réveiller (EtatHorsLigne). En
    // veille : réveillable, le carrousel reste tel quel et A le réveille en lançant le jeu.
    readonly property bool hostKnownOffline: activeHostName !== "" && activeHostPaired && !activeHostOnline
                                             && !activeHostStatusUnknown
    readonly property string hostState: activeHostOnline ? (hostJustWoke ? "online" : "")
        : waking ? "waking"
        : !hostKnownOffline ? ""
        : activeHostWakeable && !wakeFailed ? "asleep" : "offline"
    readonly property bool hostOffline: hostState === "offline" && !libraryEmpty

    // EtatHorsLigne : A réveille le PC (ou, sans réveil possible, refuse).
    function wakeFromOffline() {
        if (!activeHostWakeable) {
            homeScreen.offline.refuse()
            Sounds.play("deny")
            return
        }
        Sounds.play("select")
        wakeHost(true)
    }

    // `byUser` : demandé (et non d'office au démarrage) : sons du réveil (MotionReveilPC).
    function wakeHost(byUser) {
        if (activeComputerIndex < 0 || !activeHostWakeable || activeHostOnline) return
        console.info("[console-ui] Réveil de \"" + activeHostName + "\"")
        if (byUser) {
            Sounds.play("host_wake_send")
            if (!launchScreen.active) Sounds.play("connecting_loop")
        }
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
            if (!launchScreen.active) Sounds.stop("connecting_loop")
            if (home.launchWaking)
                home.launchFailed("")
        }
    }
    onActiveHostOnlineChanged: {
        maybeStartPairing()
        Qt.callLater(rebuildShelf)          // les jeux à télécharger suivent l'état du PC
        if (!activeHostOnline) return
        // Il vient de se réveiller : « PC-Salon est en ligne », un instant (MotionReveilPC).
        if (waking) {
            hostJustWoke = true
            justWoke.restart()
            if (!launchScreen.active) {
                Sounds.stop("connecting_loop")
                Sounds.play("host_online")
            }
        }
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
    property int lastLaunchIndex: -1     // dernier jeu lancé (Réessayer après un échec)

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
            lastLaunchIndex = index
            launchWaking = true
            launchResume = false
            launchReady = false
            launchOpened = false
            launchScreen.image = homeScreen.backdrop
            setLaunchOrigin(index)
            launchScreen.steps = wakeSteps(item.name)
            launchScreen.step = 0
            launchScreen.progress = -1
            launchScreen.cancellable = true
            wakeHost()
            Sounds.play("launch")
            homeScreen.pressed = true
            launchPress.start()
            return
        }

        // PC injoignable et impossible à réveiller : pas de session vers une adresse vide
        // (« Host not found (Error 3) ») ; on l'attend un instant, puis l'échec (MotionEchec).
        if (!activeHostOnline) {
            launchScreen.image = homeScreen.backdrop
            setLaunchOrigin(index)
            reachHost(index)
            Sounds.play("launch")
            homeScreen.pressed = true
            launchPress.start()
            return
        }

        // Un AUTRE jeu tourne déjà sur le host : demander confirmation
        // (équivalent console du quitAppDialog de AppView.qml). Chemin direct.
        var runningId = appModel.getRunningAppId()
        if (runningId !== 0 && runningId !== item.appid) {
            confirmDialog.ask(qsTr("Un jeu est déjà en cours"),
                              qsTr("%1 est en cours sur votre PC. Le fermer et lancer %2 ? Toute progression non sauvegardée sera perdue.")
                                  .arg(appModel.getRunningAppName()).arg(item.name),
                              qsTr("Fermer et jouer"), function() { home.quitAndLaunch(index) }, qsTr("C'est parti"))
            return
        }

        beginLaunch(index, false, false)
        Sounds.play("launch")
        homeScreen.pressed = true
        launchPress.start()
    }

    // « Réveil de PC-Salon… », « Lancement de Minecraft… » (MotionLancement).
    function wakeSteps(game) {
        return [qsTr("Réveil de %1…").arg(activeHostName), qsTr("Lancement de %1…").arg(game)]
    }

    // États et départ du lancement. `afterWake` : l'écran est déjà ouvert sur l'état du
    // réveil, qui est fait ; `kept` : il est déjà ouvert (Réessayer, après un échec).
    function beginLaunch(index, afterWake, kept) {
        var item = appViewer.objectAt(index)
        if (!item) return
        // Chemin Companion = LE différenciateur : POST /v1/launch → (maj si besoin)
        // → READY → stream. On NE démarre PAS le stream nous-mêmes ici (§4 host).
        // Repli direct si le Companion est absent ou ne connaît pas ce jeu.
        var gameId = CompanionClient.paired && CompanionClient.eventsConnected
                     ? CompanionClient.gameIdForName(item.name) : ""
        var runningId = appModel.getRunningAppId()

        launchIndex = index
        lastLaunchIndex = index
        launchResume = runningId === item.appid
        launchReady = gameId === ""
        if (!afterWake && !kept) {
            launchOpened = false
            launchScreen.image = homeScreen.backdrop
            setLaunchOrigin(index)
        }
        launchScreen.steps = (afterWake ? [launchScreen.steps[0]] : [])
            .concat(gameId !== "" ? [qsTr("Préparation de %1…").arg(activeHostName)] : [])
            .concat([
                launchResume ? qsTr("Reprise de %1…").arg(item.name) : qsTr("Lancement de %1…").arg(item.name),
                qsTr("Connexion au flux vidéo…")
            ])
        launchScreen.step = afterWake ? 1 : 0
        launchScreen.progress = -1
        launchScreen.cancellable = gameId !== ""
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
        launchScreen.thumbnail = fromShelf ? (selected.cover || selected.boxart) : ""
        var item = appViewer.objectAt(appIndex)
        launchScreen.title = item ? item.name : ""
    }

    function resumeLaunchAfterWake() {
        if (!launchWaking) return
        launchWaking = false
        var index = launchIndex
        launchIndex = -1
        beginLaunch(index, true, false)
    }

    Timer {
        id: launchPress
        interval: Theme.launchPress
        onTriggered: launchScreen.open()
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

        // Dernier état : « Connexion au flux vidéo… ».
        launchScreen.cancellable = false
        launchScreen.progress = -1
        launchScreen.step = launchScreen.steps.length - 1
        // Moonlight fige l'interface pendant qu'il prépare son décodeur : l'écran
        // de lancement reste immobile jusqu'à la première étape de connexion.
        launchScreen.frozen = true
        // Un échec avant le flux : l'écran de lancement le dit (MotionEchec), à la place du
        // dialog d'erreur de la page d'origine (élément « bureau »), dont on vide le texte.
        var failure = ""
        session.stageStarting.connect(function() { launchScreen.frozen = false })
        session.stageFailed.connect(function(stage, errorCode) {
            failure = qsTr("La connexion au flux a échoué (%1, erreur %2).").arg(stage).arg(errorCode)
        })
        session.displayLaunchError.connect(function(text) { failure = text })
        session.connectionStarted.connect(function() {
            home.streamStarted = true
            launchScreen.complete()
            Sounds.play("ready")
            keepHomeUnderStream(session)
            launchScreen.close(false)
        })
        session.sessionFinished.connect(function() {
            if (failure !== "" && !home.streamStarted && launchScreen.active) {
                streamSegueErrorDialog.text = ""
                home.launchFailed(failure)
            } else {
                home.endLaunch()
            }
        })

        var component = Qt.createComponent("qrc:/gui/StreamSegue.qml")
        stackView.push(component.createObject(stackView, {
            "appName": item ? item.name : "",
            "session": session,
            "isResume": launchResume
        }))
    }

    // Le flux démarre. La page d'origine (StreamSegue) cachait la fenêtre dès la connexion,
    // avant que celle du flux n'existe : on voyait le bureau entre les deux. Notre
    // gestionnaire passe avant le sien (branché plus tôt) et le débranche : la fenêtre reste,
    // le rideau noir, sous celle du flux, tout le temps du flux (au retour, rien
    // à réafficher : le flux se ferme sur elle).
    function keepHomeUnderStream(session) {
        var segue = stackView.currentItem
        var kept = !!(segue && segue.connectionStarted)
        if (kept)
            session.connectionStarted.disconnect(segue.connectionStarted)
        console.info("[console-ui] Lancement : fenêtre de l'accueil " + (kept ? "gardée sous le flux" : "cachée par StreamSegue"))
        streamCurtain.image = launchScreen.image
        streamCurtain.thumbnail = launchScreen.thumbnail
        streamCurtain.origin = launchScreen.origin
        streamCurtain.title = launchScreen.title
        streamCurtain.cover()
        streamCurtain.reveal("")
    }

    // Le menu en jeu (bouton Home pendant le flux) : son titre, ses actions, ses glyphes.
    // L'en-tête du centre de contrôle : jaquette, PC, latence, début de la partie (lancée d'ici).
    function prepareStreamMenu(game) {
        var tile = null
        for (var i = 0; i < allTiles.length && game !== ""; i++)
            if (allTiles[i].name === game) tile = allTiles[i]
        var recent = Library.parse(consoleConfig.recentGames, {})
        InputStatus.prepareStreamMenu(game, SystemStatus.powerActions, Theme.buttonLayout, SystemStatus, {
            cover: tile ? String(tile.cover || tile.boxart || "") : "",
            host: activeHostName,
            latency: SystemStatus.latencyMs,
            startedAt: launchResume && recent[game] ? recent[game] : Date.now()   // (une reprise : depuis son lancement)
        })
    }

    // Retour à l'accueil : fin du jeu, échec, annulation.
    function endLaunch() {
        restoreCommonSettings()
        launchPress.stop()
        companionWait.stop()
        reachTimer.stop()
        launchWaking = false
        launchIndex = -1
        launchScreen.close(true)
        homeScreen.pressed = false
    }

    // Échec du lancement (MotionEchec). PC injoignable : « PC-Salon ne répond pas », sinon
    // « Le lancement a échoué » et la raison.
    property int failedIndex: -1         // le jeu à relancer (Réessayer)
    function launchFailed(reason) {
        failedIndex = lastLaunchIndex
        launchPress.stop()
        companionWait.stop()
        launchWaking = false
        launchIndex = -1
        restoreCommonSettings()
        if (!launchScreen.active) launchScreen.open()
        launchScreen.cancellable = false
        launchScreen.canWake = !activeHostOnline && activeHostWakeable
        if (!activeHostOnline) {
            launchScreen.errorTitle = qsTr("%1 ne répond pas").arg(activeHostName)
            launchScreen.error = qsTr("Vérifiez que le PC est allumé et relié au même réseau,\nou réveillez-le à distance.")
        } else {
            launchScreen.errorTitle = qsTr("Le lancement a échoué")
            launchScreen.error = reason
        }
    }
    // PC hors ligne, sans réveil possible : « Connexion à PC-Salon… », « Nouvelle tentative… »,
    // puis l'échec s'il ne répond toujours pas ; s'il répond, le lancement reprend.
    function reachHost(index) {
        launchIndex = index
        lastLaunchIndex = index
        launchWaking = true
        launchReady = false
        launchResume = false
        launchScreen.steps = [qsTr("Connexion à %1…").arg(activeHostName), qsTr("Nouvelle tentative…")]
        launchScreen.step = 0
        launchScreen.progress = -1
        launchScreen.cancellable = true
        reachTimer.tries = 0
        reachTimer.restart()
    }
    Timer {
        id: reachTimer
        interval: Theme.reachRetry
        repeat: true
        property int tries: 0
        onTriggered: {
            if (!home.launchWaking || home.activeHostOnline) return stop()
            if (++tries === 1) {
                launchScreen.step = 1
            } else {
                stop()
                home.launchFailed("")
            }
        }
    }

    // A Réessayer : le même jeu, sans refermer l'écran (le PC est réveillé d'abord s'il dort).
    function retryLaunch() {
        var index = failedIndex
        launchScreen.error = ""
        if (index < 0 || !appModel) return endLaunch()
        launchOpened = true
        if (!activeHostOnline && activeHostWakeable) {
            launchIndex = index
            lastLaunchIndex = index
            launchWaking = true
            launchReady = false
            launchScreen.steps = wakeSteps(launchScreen.title)
            launchScreen.step = 0
            launchScreen.cancellable = true
            wakeHost()
        } else if (!activeHostOnline) {
            reachHost(index)
        } else {
            beginLaunch(index, false, true)
        }
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
                keepHomeUnderStream(session)
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
    // Curseur du débit, en Mb/s : bornes et crans marqués.
    readonly property var bitrateRange: [5, 150]
    readonly property var bitrateStops: [10, 20, 40, 80]
    // Curseurs en % (luminosité, volume) : crans marqués, et la luminosité jamais sous 5 %
    // (SystemStatus.setBrightness : on ne verrait plus rien pour remonter).
    readonly property var percentStops: [25, 50, 75]
    readonly property int brightnessMin: 5

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
        // Sous un profil automatique, les lignes montrent ce qu'il choisira au lancement.
        var context = profileContext()
        var chosen = StreamProfiles.launchSettings(s.profile, context)
        var e = chosen ? Object.assign({}, s, chosen) : s

        // Résolution : 720p, celle de l'écran, 1080p (et l'actuelle si elle n'y est pas).
        var nativeW = Math.round(Screen.width * Screen.devicePixelRatio)
        var nativeH = Math.round(Screen.height * Screen.devicePixelRatio)
        // (« 1440p » pour une définition courante, « Natif 1280×800 » pour celle de l'écran)
        var resLabel = function(w, h) {
            return w === nativeW && h === nativeH ? qsTr("Natif %1×%2").arg(w).arg(h)
                 : StreamProfiles.STANDARD.some(function(r) { return r.width === w && r.height === h }) ? h + "p"
                 : w + "×" + h
        }
        var res = [ { label: "720p", w: 1280, h: 720 }, { label: "1080p", w: 1920, h: 1080 } ]
        var same = function(w, h) { return function(r) { return r.w === w && r.h === h } }
        if (nativeW > 0 && !res.some(same(nativeW, nativeH)))
            res.push({ label: resLabel(nativeW, nativeH), w: nativeW, h: nativeH })
        if (!res.some(same(e.width, e.height)))
            res.push({ label: resLabel(e.width, e.height), w: e.width, h: e.height })
        res.sort(function(a, b) { return a.w * a.h - b.w * b.h })     // ← plus petite, → plus grande

        var fps = [30, 60, 90, 120]
        if (fps.indexOf(e.fps) < 0)
            fps.push(e.fps)
        fps.sort(function(a, b) { return a - b })

        // Débit : automatique (la valeur que Moonlight calcule pour la résolution et la
        // fréquence, montrée grisée sur le curseur), ou réglé au curseur.
        optionAutoBitrate = s.autoAdjustBitrate
                && s.bitrateKbps === p.getDefaultBitrate(s.width, s.height, s.fps, p.enableYUV444)
        var mbps = Math.round(e.bitrateKbps / 1000)

        var codec = [ { label: qsTr("Auto"), value: p.VCC_AUTO }, { label: "H.264", value: p.VCC_FORCE_H264 },
                      { label: "HEVC", value: p.VCC_FORCE_HEVC }, { label: "AV1", value: p.VCC_FORCE_AV1 } ]
        var codecIndex = codec.findIndex(function(c) { return c.value === s.videoCodecConfig })
        var hdr = [ { label: qsTr("Désactivé"), value: false }, { label: qsTr("Activé"), value: true } ]

        // Console : réglages du système et de la conf console (ConsoleUi).
        var sleep = [ { label: qsTr("30 s"), value: 30 }, { label: qsTr("1 min"), value: 60 },
                      { label: qsTr("2 min"), value: 120 }, { label: qsTr("5 min"), value: 300 },
                      { label: qsTr("10 min"), value: 600 }, { label: qsTr("30 min"), value: 1800 },
                      { label: qsTr("Jamais"), value: 0 } ]
        var buttons = [ { label: qsTr("Auto"), value: "auto" }, { label: "Xbox", value: "xbox" },
                        { label: "PlayStation", value: "playstation" }, { label: "Nintendo", value: "nintendo" } ]
        var sounds = [ { label: qsTr("Coupés"), value: false }, { label: qsTr("Activés"), value: true } ]
        var motion = [ { label: qsTr("Non"), value: false }, { label: qsTr("Oui"), value: true } ]
        var rumble = [ { label: qsTr("Off"), value: 0 }, { label: qsTr("Légères"), value: 0.6 },
                       { label: qsTr("Fortes"), value: 1 } ]
        // Chaque langue dans sa langue.
        var language = [ { label: "Français", value: p.LANG_FR }, { label: "English", value: p.LANG_EN } ]

        optionChoices = { res: res, fps: fps.map(function(f) { return { label: "" + f, value: f } }),
                          rateAuto: hdr, advanced: hdr, codec: codec, hdr: hdr,
                          sleep: sleep, buttons: buttons, sounds: sounds, rumble: rumble, motion: motion, language: language,
                          volumeHud: [ { label: qsTr("À gauche"), value: "left" }, { label: qsTr("Au centre"), value: "center" },
                                       { label: qsTr("À droite"), value: "right" } ] }
        // `toggle` : deux options [désactivé, activé], affichées en interrupteur.
        var row = function(key, label, index, toggle) {
            return { key: key, label: label, index: index, toggle: toggle === true,
                     options: optionChoices[key].map(function(c) { return c.label }) }
        }
        var consoleRows = []
        // Luminosité et volume : des curseurs (comme le débit), en %.
        var percentSlider = function(key, label, value, min) {
            return { key: key, label: label, slider: true, value: value, min: min, max: 100,
                     stops: percentStops, format: qsTr("%1 %"), group: "screen", section: qsTr("Écran et son") }
        }
        if (SystemStatus.brightness >= 0)
            consoleRows.push(percentSlider("brightness", qsTr("Luminosité"), SystemStatus.brightness, brightnessMin))
        if (SystemStatus.volume >= 0)
            consoleRows.push(percentSlider("volume", qsTr("Volume"), SystemStatus.volume, 0))
        consoleRows.push(row("sleep", qsTr("Veille après"),
                             Math.max(0, sleep.findIndex(function(c) { return c.value === consoleConfig.idleSeconds }))))
        consoleRows.push(row("sounds", qsTr("Sons"), consoleConfig.sounds ? 1 : 0, true))
        consoleRows.push(row("motion", qsTr("Réduire les animations"), consoleConfig.reduceMotion ? 1 : 0, true))
        consoleRows.push(row("language", qsTr("Langue"), english ? 1 : 0))
        consoleRows.push({ key: "settings", label: qsTr("Tous les réglages"), action: true })

        // (le reste de l'onglet : une carte « Console »)
        consoleRows.forEach(function(r) {
            if (r.group) return
            r.group = "console"
            r.section = qsTr("Console")
        })

        optionChoices.profile = [ { label: qsTr("Réglages communs"), value: false },
                                  { label: qsTr("Réglages à part"), value: true } ]
        var profileRow = game !== "" ? [ { key: "profile", label: game, index: own ? 1 : 0,
                                           options: optionChoices.profile.map(function(c) { return c.label }) } ]
                                     : []
        // Profil de flux : le sélecteur, et sous lui ce que le profil demandera.
        var profileNames = { competitive: qsTr("Compétitif"), balanced: qsTr("Équilibré"), quality: qsTr("Qualité"),
                             saver: qsTr("Éco"), manual: qsTr("Manuel") }
        var gigabytes = StreamProfiles.gigabytesPerHour(e.bitrateKbps)
        var gigabytesText = gigabytes.toLocaleString(Qt.locale(english ? "en_US" : "fr_FR"), "f", 1)
        var priority = { competitive: qsTr("Latence"), balanced: qsTr("Équilibre"), quality: qsTr("Image"),
                         saver: qsTr("≈ %1 Go/h").arg(gigabytesText), manual: qsTr("Vos réglages") }
        // Sans les réglages avancés : une phrase simple à la place des chiffres.
        var description = {
            competitive: qsTr("Le plus réactif : toutes les images de l'écran, pour les jeux rapides."),
            balanced: qsTr("Le meilleur compromis entre image et fluidité, adapté à votre réseau."),
            quality: qsTr("La plus belle image, quand le réseau suit."),
            saver: qsTr("Moins de données et de batterie : environ %1 Go par heure.").arg(gigabytesText),
            manual: qsTr("Vos propres réglages, dans les réglages avancés.") }
        var drop = chosen && s.profile !== "saver" ? StreamProfiles.networkDrop(context.quality) : 0
        var streamProfileRow = {
            key: "streamProfile", label: qsTr("Profil"), segments: true,
            group: "profile", section: qsTr("Profil de stream"),
            options: StreamProfiles.KEYS.map(function(k) { return profileNames[k] }),
            index: Math.max(0, StreamProfiles.KEYS.indexOf(s.profile)),
            // Manuel n'a de sens qu'avec les réglages avancés (ceux d'un jeu d'avant les profils
            // le gardent tant qu'on n'en choisit pas un autre).
            hiddenOptions: consoleConfig.advancedSettings || s.profile === "manual"
                           ? [] : [StreamProfiles.KEYS.indexOf("manual")],
            footnote: drop === 1 ? qsTr("Réseau moyen : le profil descend automatiquement d'un cran.")
                    : drop === 2 ? qsTr("Réseau faible : le profil descend automatiquement de deux crans.") : "",
            description: description[s.profile] || "",
            stats: [ { label: qsTr("Résolution"), value: e.height + "p" },
                     { label: qsTr("Images/s"), value: "" + e.fps },
                     { label: qsTr("Débit"), value: qsTr("%1 Mb/s").arg(mbps) },
                     { label: qsTr("Priorité"), value: priority[s.profile] || "" } ] }
        // Les lignes restent toutes là (aucune ne prend la place d'une autre) : `advanced`, elles
        // n'apparaissent qu'avec les réglages avancés ; `hidden`, elles restent repliées.
        // `auto` : grisées, choisies par le profil (les toucher passe en Manuel).
        var advanced = function(r) { r.advanced = true; r.group = "advanced"; return r }
        var byProfile = function(r) { r.auto = chosen !== null; return advanced(r) }
        var rateAuto = advanced(row("rateAuto", qsTr("Débit automatique"), optionAutoBitrate ? 1 : 0, true))
        rateAuto.hidden = chosen !== null
        // Oublier ce PC (son appairage Moonlight et Companion) : A maintenu.
        var forgetRow = activeHostName !== ""
            ? [ { key: "forget", label: qsTr("Oublier ce PC"), hold: true, doneLabel: qsTr("PC oublié"), group: "pc" } ] : []
        optionTabs = [
            { label: qsTr("Stream"), rows: [
                streamProfileRow,
                { key: "advanced", label: qsTr("Réglages avancés"), toggle: true, revealsAdvanced: true,
                  group: "advanced", section: qsTr("Avancé"),
                  index: consoleConfig.advancedSettings ? 1 : 0, options: optionChoices.advanced.map(function(c) { return c.label }) }
            ].concat(profileRow.map(advanced), [
                byProfile(row("res", qsTr("Résolution"), res.findIndex(same(e.width, e.height)))),
                byProfile(row("fps", qsTr("Images par seconde"), fps.indexOf(e.fps))),
                rateAuto,
                advanced({ key: "rate", label: qsTr("Débit"), slider: true, value: mbps, auto: chosen !== null || optionAutoBitrate,
                           min: bitrateRange[0], max: Math.max(bitrateRange[1], mbps), stops: bitrateStops,
                           format: qsTr("%1 Mb/s") }),
                // (un ancien réglage « HEVC HDR » est montré comme HEVC)
                advanced(row("codec", qsTr("Codec"), codecIndex >= 0 ? codecIndex : 2)),
                advanced(row("hdr", qsTr("HDR"), s.enableHdr ? 1 : 0, true))
            ], forgetRow) },
            { label: qsTr("Console"), rows: consoleRows }
        ]
    }

    function applyOption(key, index) {
        var p = StreamingPreferences
        var choice = optionChoices[key] ? optionChoices[key][index] : null    // (curseur : `index` est la valeur)
        // Console : rien à voir avec les préférences du flux.
        if (key === "advanced") {
            consoleConfig.advancedSettings = choice.value
            // Sans eux, plus de Manuel : le profil affiché repasse au profil par défaut (les
            // réglages manuels restent enregistrés, Manuel les retrouve).
            var shown = homeScreen.app ? homeScreen.app.name : ""
            if (shown === "" || gameProfiles()[shown] === undefined) shown = ""
            var current = settingsFor(shown)
            if (!choice.value && current.profile === "manual") {
                current.profile = StreamProfiles.DEFAULT
                writeSettings(shown, current)
            }
        } else if (key === "volumeHud") {
            consoleConfig.volumeHud = choice.value
            volumeHud.press(0, false)       // (pour la voir à sa place)
        } else if (key === "sounds") {
            consoleConfig.sounds = choice.value
            Sounds.enabled = choice.value
        } else if (key === "rumble") {
            consoleConfig.haptics = choice.value
            InputStatus.feedback("select", choice.value)   // pour la sentir
        } else if (key === "motion") {
            consoleConfig.reduceMotion = choice.value
            Theme.reducedMotion = choice.value
        } else if (key === "brightness") {          // les curseurs : `index` est la valeur, en %
            SystemStatus.setBrightness(index)
        } else if (key === "volume") {
            SystemStatus.setVolume(index)
        } else if (key === "sleep") {
            consoleConfig.idleSeconds = choice.value
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
        if (["advanced", "sounds", "rumble", "motion", "brightness", "volume", "sleep", "buttons", "language"].indexOf(key) >= 0) {
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
        if (key === "streamProfile") {
            s.profile = StreamProfiles.KEYS[index]
            writeSettings(own ? game : "", s)
            refreshOptions()
            return
        }
        // Un réglage du lancement touché sous un profil automatique : on passe en Manuel, à
        // partir de ce que le profil aurait choisi.
        var chosen = StreamProfiles.launchSettings(s.profile, profileContext())
        if (chosen && ["res", "fps", "rate", "rateAuto"].indexOf(key) >= 0) {
            Object.assign(s, chosen)
            s.profile = "manual"
            s.autoAdjustBitrate = false
            optionAutoBitrate = false
        }
        if (key === "res") {
            s.width = choice.w
            s.height = choice.h
        } else if (key === "fps") {
            s.fps = choice.value
        } else if (key === "rateAuto") {
            s.autoAdjustBitrate = choice.value
            optionAutoBitrate = choice.value
        } else if (key === "rate") {             // le curseur : un débit fixe, en Mb/s
            s.autoAdjustBitrate = false
            optionAutoBitrate = false
            s.bitrateKbps = index * 1000
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
        var p = StreamingPreferences, s = { profile: consoleConfig.streamProfile }
        streamKeys.forEach(function(k) { s[k] = p[k] })
        return s
    }

    // Réglages de `game` (les siens, sinon les communs), avec leur profil de flux.
    function settingsFor(game) {
        var profile = game !== "" ? gameProfiles()[game] : undefined
        if (!profile) return commonSettings()
        var s = Object.assign({}, profile)
        if (!s.profile) s.profile = "manual"   // (réglages à part d'avant les profils)
        return s
    }

    // Ce avec quoi `game` partira : ses réglages, et, sous un profil automatique, ce que ce
    // profil choisit pour cet écran et ce réseau.
    function effectiveSettings(game) {
        var s = settingsFor(game)
        var chosen = StreamProfiles.launchSettings(s.profile, profileContext())
        return chosen ? Object.assign(s, chosen) : s
    }

    // L'écran de la console et la qualité du réseau vers le PC (StreamProfiles.launchSettings).
    function profileContext() {
        var p = StreamingPreferences
        return { width: Math.round(Screen.width * Screen.devicePixelRatio) || 1920,
                 height: Math.round(Screen.height * Screen.devicePixelRatio) || 1080,
                 refresh: Screen.refreshRate,
                 quality: activeHostOnline ? Format.networkQuality(SystemStatus.latencyMs, SystemStatus.jitterMs) : "",
                 defaultKbps: function(w, h, fps) { return p.getDefaultBitrate(w, h, fps, p.enableYUV444) } }
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
            if (s.profile) consoleConfig.streamProfile = s.profile
        }
    }

    // Réglages à part pour `game` (copie des communs), ou retour aux communs.
    function setOwnProfile(game, own) {
        var profiles = gameProfiles()
        if (own) profiles[game] = commonSettings()
        else delete profiles[game]
        consoleConfig.gameProfiles = JSON.stringify(profiles)
    }

    // Au lancement de `game` : ses réglages (et ce qu'en tire son profil) remplacent les
    // communs dans les préférences, sans être enregistrés ; restoreCommonSettings les remet.
    function applyGameProfile(game) {
        if (commonSaved) return
        var s = effectiveSettings(game)
        commonSaved = commonSettings()
        var p = StreamingPreferences
        streamKeys.forEach(function(k) { p[k] = s[k] })
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
        visible: !sleepScreen.covering                  // caché sous la veille : rien à dessiner

        readonly property var app: { home.shelfRevision; return home.currentApp() }
        // La vignette sélectionnée : une app du PC, ou un jeu pas encore installé.
        readonly property var tile: { home.shelfRevision; return home.currentTile() }
        readonly property bool pending: tile !== null && tile.appIndex < 0
        // Fiche du jeu dans la bibliothèque du Companion (absente sans Companion).
        readonly property var info: tile ? (home.companionGames[tile.name.toLowerCase()] || null) : null

        model: shelfModel
        // Une catégorie vide (Favoris) n'empêche pas l'accueil d'entrer : la bibliothèque est là.
        ready: !home.libraryEmpty
        favoritesEmpty: home.collection === "favorites" && shelfModel.count === 0
        onRecentRequested: if (home.collections.indexOf("recent") >= 0)
                               home.switchCollection(home.collections.indexOf("recent") - home.collections.indexOf(home.collection))
        title: tile ? tile.name : ""
        logo: info && info.logo ? info.logo : ""
        // Sous le titre : « Éditeur · Année · Genre » ; dans Récents, la dernière partie et le
        // temps de jeu (MotionCategories). Un champ absent disparaît avec son séparateur.
        meta: !info ? [] : home.collection === "recent"
              ? [Format.lastPlayed(info.lastPlayed, new Date()), Format.playtime(info.playtimeSeconds)].filter(Boolean)
              : Format.meta(info)
        pegi: info ? Format.pegi(info.ageRatings) : ""
        running: app ? app.running : false
        runningGame: home.runningGame
        collectionLabels: home.collections.map(function(c) { return home.collectionNames[c] })
        collectionIndex: home.collections.indexOf(home.collection)
        onCollectionRequested: function(direction) { home.switchCollection(direction) }
        playLabel: tile && Library.isUtility(tile.name) ? qsTr("Ouvrir")
                 : !pending || info && info.isInstalled ? ""
                 : home.downloads[tile.gameId] ? qsTr("Téléchargement") : qsTr("Télécharger")
        updateNote: pending ? home.pendingNote(tile.gameId, info)
                  : info && home.uninstalls[info.id] ? qsTr("Désinstallation en cours") : ""
        favorite: tile ? home.favoriteNames().indexOf(tile.name) >= 0 : false
        source: info ? Format.sourceName(info.source) : ""
        lastPlayed: info ? Format.lastPlayed(info.lastPlayed, new Date()) : ""
        playtime: info ? Format.playtime(info.playtimeSeconds) : ""
        // L'image 16:9 du Companion (cache disque) ; à défaut, la jaquette du jeu,
        // recadrée. Pas de fond pour un jeu sans jaquette (Moonlight donne alors une
        // icône générique).
        backdrop: info && info.background ? info.background
                : app && app.boxart.toString() !== "qrc:/res/no_app_image.png" ? app.boxart
                : pending ? tile.boxart : ""
        // La couleur dominante du fond (calculée à part), sinon l'accent.
        readonly property color backdropColor: {
            AmbientColor.revision
            return AmbientColor.colorFor(backdrop)
        }
        ambient: backdropColor.valid ? backdropColor : Theme.accent
        ambientTint: backdropColor.valid
        hostName: home.activeHostName !== "" ? home.activeHostName : qsTr("Recherche…")
        connected: home.activeHostOnline && home.activeHostPaired
        hostState: home.hostState
        hostOffline: home.hostOffline
        menuShown: hostPicker.opened || powerMenu.opened
        waking: home.waking && !launchScreen.active
        // Batterie et Wi-Fi de la console (-1 : pas de donnée, indicateur masqué), et
        // réseau vers le PC, sondé tant que l'accueil est à l'écran.
        latencyMs: connected ? SystemStatus.latencyMs : -1
        jitterMs: connected ? SystemStatus.jitterMs : -1
        signalStrength: SystemStatus.signalStrength
        batteryPercent: SystemStatus.batteryPercent
        charging: SystemStatus.charging
        batteryDetails: SystemStatus.batteryDetails
        wifi: SystemStatus.wifi
        wifiChangeable: WifiSetup.available
        onSystemRequested: function(key) {
            if (key === "wifi") home.openWifi()
            else if (key === "host") home.openHostPicker()
        }
        controllerBattery: InputStatus.controllerBattery
        controllerCount: InputStatus.controllerCount
        controllerFamily: InputStatus.layout
        notificationsAllowed: !sleepScreen.asleep && !streamCurtain.covering

        optionTabs: home.optionTabs
        // « PC-Salon · connecté · 4 ms » sous le titre de la feuille d'options.
        optionsSubtitle: home.activeHostName === "" ? ""
            : [home.activeHostName, connected ? qsTr("connecté") : qsTr("hors ligne")]
                .concat(connected && SystemStatus.latencyMs >= 0 ? [qsTr("%1 ms").arg(SystemStatus.latencyMs)] : [])
                .join(" · ")

        // L'accueil entre quand l'animation de démarrage en est à sa sortie ; le logo de
        // la barre haute n'apparaît qu'une fois celui du démarrage arrivé à sa place.
        entryAllowed: bootSplash.entryOpen
        // Un jeu prend l'écran, ou en revient : l'accueil s'efface puis revient (MotionQuitter).
        launching: launchScreen.covering || streamCurtain.covering
        statusLogoShown: !bootSplash.visible || bootSplash.mode === "wake"

        staged: searchScreen.shown || pinScreen.shown || companionPairing.shown
                || welcomeScreen.shown || networkScreen.shown
        detailOpen: gamePage.shown
        panelOpen: confirmDialog.opened || homeMenu.opened || settingsScreen.opened || findScreen.opened
                   || hostPicker.opened || powerMenu.opened
                   || downloadMenu.opened

        onLaunchRequested: function(index) {
            if (home.hostOffline) return home.wakeFromOffline()
            var tile = shelfModel.get(index)
            var info = home.companionGames[tile.name.toLowerCase()]
            if (tile.appIndex < 0)
                home.pendingAction(tile.gameId, tile.name)
            else if (info && info.isInstalled === false)    // désinstallé : l'app part au prochain relevé (~30 s)
                homeScreen.toast(qsTr("%1 n'est plus installé").arg(tile.name))
            else
                home.launchApp(tile.appIndex)
        }
        // Bas sur l'étagère : la fiche, si le Companion connaît le jeu.
        onDetailsRequested: {
            if (info) gamePage.open()
            else Sounds.play("edge")
        }
        onFavoriteRequested: home.toggleFavorite()
        onQuitRequested: home.quitRunningGame()
        onOptionChanged: function(key, index) { home.applyOption(key, index) }
        onOptionAction: function(key) {
            if (key === "settings") {
                options.close()
                home.openSettings("")
            }
        }
        onForgetRequested: {
            options.close()
            home.forgetHost()
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
        shown: home.setupDone && home.libraryEmpty && !pinScreen.shown && !companionPairing.shown
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
        onActivated: { home.wakeHost(); Sounds.play("select") }
        onHintTriggered: function(glyph) { if (glyph === "Y") homeScreen.options.open() }
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
        onHintTriggered: function(glyph) { if (glyph === "Y") homeScreen.options.open() }
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
        onActivated: home.welcome()
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
        onActivated: home.openWifi()
    }
    function welcome() {
        Sounds.play("select")
        welcomed = true
        if (!needsNetwork)
            setupDone = true
    }

    // Oublier ce PC : son appairage Moonlight ET celui du Companion.
    function forgetHost() {
        CompanionClient.forgetHost()
        if (home.activeComputerIndex >= 0)
            home.computerModel.deleteComputer(home.activeComputerIndex)
    }

    // --- Réglages plein écran (« Tous les réglages » des options) ---
    property var settingsPages: []
    function openSettings(key) {
        refreshSettings()
        settingsScreen.open(key)
    }
    // Les rubriques et leurs lignes, lues dans la conf console, le système et les manettes.
    // Une rubrique sans réglage qui existe n'apparaît pas (Réseau mobile, Bibliothèque,
    // Notifications, Confidentialité : cf. next_steps.md).
    function refreshSettings() {
        if (!optionChoices.sleep) refreshOptions()
        var c = optionChoices, pages = []
        var indexOf = function(list, value) { return Math.max(0, list.findIndex(function(o) { return o.value === value })) }
        var labels = function(list) { return list.map(function(o) { return o.label }) }

        if (WifiSetup.available) {
            var rows = [], w = SystemStatus.wifi || {}
            if (WifiSetup.currentNetwork !== "") {
                var band = w.frequency > 5900 ? qsTr("6 GHz") : w.frequency > 4900 ? qsTr("5 GHz")
                         : w.frequency > 0 ? qsTr("2,4 GHz") : ""
                var quality = w.strength >= 70 ? qsTr("signal excellent") : w.strength >= 40 ? qsTr("signal bon")
                            : w.strength !== undefined ? qsTr("signal faible") : ""
                rows.push({ key: "wifi:current", info: true, label: WifiSetup.currentNetwork, group: "current",
                            tile: { color: Theme.setTileWifi, icon: "wifi" },
                            sub: [qsTr("Connecté"), band, quality].filter(Boolean).join(" · "),
                            stats: [ w.strength !== undefined ? { label: qsTr("Signal"), value: qsTr("%1 %").arg(w.strength) } : null,
                                     w.bitrate > 0 ? { label: qsTr("Lien"), value: qsTr("%1 Mb/s").arg(w.bitrate) } : null,
                                     SystemStatus.latencyMs >= 0 ? { label: qsTr("Vers le PC"), value: qsTr("%1 ms").arg(SystemStatus.latencyMs) } : null
                                   ].filter(Boolean) })
            }
            WifiSetup.networks.filter(function(n) { return !n.active }).forEach(function(n) {
                rows.push({ key: "wifi:" + n.ssid, label: n.ssid, action: true, chevron: false, lock: n.secured,
                            bars: n.bars, group: "others", section: qsTr("Autres réseaux"), sectionBusy: WifiSetup.scanning })
            })
            pages.push({ key: "wifi", label: qsTr("Wi-Fi"), tile: { color: Theme.setTileWifi, icon: "wifi" },
                         value: WifiSetup.currentNetwork, group: "network", rows: rows })
        }

        var pads = InputStatus.controllers.map(function(pad, i) {
            return { key: "pad:" + i, label: pad.name || qsTr("Manette"), sub: qsTr("Joueur %1").arg(i + 1),
                     tile: { color: Theme.listTileDark, icon: "gamepad" }, group: "pads", section: qsTr("Connectées"),
                     battery: pad.battery >= 0 ? Math.round(pad.battery / 3 * 100) : undefined }
        })
        pages.push({ key: "pads", label: qsTr("Bluetooth et manettes"), tile: { color: Theme.setTilePads, icon: "gamepad" },
                     value: pads.length > 0 ? "" + pads.length : "", group: "network",
                     rows: pads.concat([
                         { key: "buttons", label: qsTr("Glyphes à l'écran"), choice: true, options: labels(c.buttons),
                           index: indexOf(c.buttons, consoleConfig.buttonLayout), group: "controls", section: qsTr("Commandes") },
                         { key: "rumble", label: qsTr("Vibrations"), choice: true, options: labels(c.rumble),
                           index: indexOf(c.rumble, consoleConfig.haptics), group: "controls" } ]) })

        if (activeHostName !== "")
            pages.push({ key: "pc", label: qsTr("PC et streaming"), tile: { color: Theme.accent, icon: "monitor" },
                         value: activeHostName, group: "pc",
                         rows: [ { key: "pc:host", label: activeHostName, group: "pc",
                                   sub: activeHostOnline ? [qsTr("Connecté")].concat(SystemStatus.latencyMs >= 0
                                                          ? [qsTr("%1 ms").arg(SystemStatus.latencyMs)] : []).join(" · ")
                                                       : qsTr("Hors ligne"),
                                   tile: { color: Theme.accent, icon: "monitor" } },
                                 { key: "forget", label: qsTr("Oublier ce PC"), hold: true, doneLabel: qsTr("PC oublié"), group: "pc" } ] })

        var screenRows = []
        if (SystemStatus.brightness >= 0)
            screenRows.push({ key: "brightness", label: qsTr("Luminosité"), slider: true, icons: ["dot", "sun"],
                              value: SystemStatus.brightness, min: brightnessMin, max: 100, stops: percentStops,
                              format: qsTr("%1 %"), group: "screen", section: qsTr("Écran") })
        if (SystemStatus.volume >= 0)
            screenRows.push({ key: "volume", label: qsTr("Volume"), slider: true, icons: ["speaker-low", "speaker"],
                              value: SystemStatus.volume, min: 0, max: 100, stops: percentStops,
                              format: qsTr("%1 %"), group: "sound", section: qsTr("Son") })
        if (SystemStatus.volume >= 0)
            screenRows.push({ key: "volumeHud", label: qsTr("Indicateur du volume"), choice: true, options: labels(c.volumeHud),
                              index: indexOf(c.volumeHud, consoleConfig.volumeHud), group: "sound" })
        screenRows.push({ key: "sounds", label: qsTr("Sons de l'interface"), toggle: true, options: labels(c.sounds),
                          index: consoleConfig.sounds ? 1 : 0, group: "sound", section: qsTr("Son"),
                          footnote: qsTr("Les sons de l'interface ne s'entendent jamais par-dessus le jeu, sauf le volume, les captures et les alertes.") })
        pages.push({ key: "screen", label: qsTr("Écran et son"), tile: { color: Theme.setTileScreen, icon: "sun" },
                     group: "device", rows: screenRows })

        if (SystemStatus.batteryPercent >= 0) {
            var d = SystemStatus.batteryDetails || {}, charging = SystemStatus.charging
            pages.push({ key: "battery", label: qsTr("Batterie"), tile: { color: Theme.setTileBattery, icon: "battery" },
                         value: qsTr("%1 %").arg(SystemStatus.batteryPercent), group: "device",
                         rows: [ { key: "battery:state", label: qsTr("État"), group: "battery",
                                   value: charging ? qsTr("En charge") : d.status === "Full" ? qsTr("Chargée")
                                        : d.status === "Not charging" ? qsTr("Branchée, sans charger") : qsTr("Sur batterie") },
                                 { key: "battery:time", label: charging ? qsTr("Pleine dans") : qsTr("Autonomie restante"),
                                   value: Format.duration(d.minutes), group: "battery", hidden: !(d.minutes >= 0) },
                                 { key: "battery:power", label: charging ? qsTr("Puissance de charge") : qsTr("Consommation"),
                                   value: d.watts > 0 ? qsTr("%1 W").arg(Format.decimal(d.watts)) : "",
                                   group: "battery", hidden: !(d.watts > 0) } ] })
        }

        var sleepIndex = indexOf(c.sleep, consoleConfig.idleSeconds)
        pages.push({ key: "sleep", label: qsTr("Mise en veille"), tile: { color: Theme.setTileSleep, icon: "moon" },
                     value: c.sleep[sleepIndex].label, group: "device",
                     rows: [ { key: "sleep", label: qsTr("Veille après"), options: labels(c.sleep), index: sleepIndex, group: "sleep" } ] })

        pages.push({ key: "general", label: qsTr("Général"), tile: { color: Theme.setTileGeneral, icon: "general" },
                     group: "system",
                     rows: [ { key: "about:name", label: qsTr("Nom"), value: SystemStatus.deviceName, group: "about",
                               section: qsTr("À propos") },
                             { key: "about:version", label: qsTr("Version"), group: "about",
                               value: qsTr("CocoOS alpha · moonlight-qt %1").arg(Qt.application.version) } ] })
        pages.push({ key: "accessibility", label: qsTr("Accessibilité"), tile: { color: Theme.setTileScreen, icon: "accessibility" },
                     group: "system",
                     rows: [ { key: "motion", label: qsTr("Réduire les animations"), toggle: true, options: labels(c.motion),
                               index: consoleConfig.reduceMotion ? 1 : 0, group: "motion" } ] })
        settingsPages = pages
    }
    // Les réglages suivent ce qui change dessous tant qu'ils sont ouverts.
    Connections {
        target: SystemStatus
        enabled: settingsScreen.opened
        function onChanged() { home.refreshSettings() }
        function onNetworkChanged() { home.refreshSettings() }
    }
    Connections {
        target: InputStatus
        enabled: settingsScreen.opened
        function onControllersChanged() { home.refreshSettings() }
    }
    Connections {
        target: WifiSetup
        enabled: settingsScreen.opened
        function onNetworksChanged() { home.refreshSettings() }
        function onStateChanged() { home.refreshSettings() }
    }
    function applySetting(key, value) {
        if (key === "forget") {
            settingsScreen.close()
            forgetHost()
            return
        }
        applyOption(key, value)
        refreshSettings()
    }
    function settingAction(key) {
        if (key.indexOf("wifi:") === 0) chooseNetwork(key.slice(5))
    }

    // --- Wi-Fi : la page Wi-Fi des réglages, puis le mot de passe ---
    property string wifiTarget: ""      // réseau en cours de connexion

    // L'état « PC hors ligne » à la souris.
    Connections {
        target: homeScreen.offline
        function onWakeRequested() { home.wakeFromOffline() }
        function onPickRequested() { home.openHostPicker() }
        function onNetworkRequested() { home.openWifi() }
    }

    // --- Choix du PC (ChoixPC) : la pastille du PC, ou Y à l'état « PC hors ligne » ---
    // Les PC appairés : connecté (coché), en ligne, en veille (réveillable), introuvable.
    function pickerHosts() {
        var list = []
        for (var i = 0; i < hostScanner.count; i++) {
            var it = hostScanner.objectAt(i)
            if (!it || !it.isPaired) continue
            var current = i === activeComputerIndex
            var games = current && allTiles.length > 0
                      ? (allTiles.length === 1 ? qsTr("1 jeu") : qsTr("%1 jeux").arg(allTiles.length)) : ""
            var state = it.isOnline ? (current ? "connected" : "online")
                      : it.isWakeable ? "asleep" : "missing"
            var detail = state === "connected" ? [qsTr("Connecté")].concat(SystemStatus.latencyMs >= 0 ? [qsTr("%1 ms").arg(SystemStatus.latencyMs)] : [])
                       : state === "online" ? [qsTr("En ligne")]
                       : state === "asleep" ? [qsTr("En veille")] : [qsTr("Introuvable sur ce réseau")]
            if (games !== "" && state !== "missing") detail.push(games)
            list.push({ index: i, name: it.hostName, state: state, detail: detail.join(" · "), current: current })
        }
        return list
    }
    function openHostPicker() {
        var hosts = pickerHosts()
        hostPicker.hosts = hosts
        hostPicker.open(Math.max(0, hosts.findIndex(function(h) { return h.current })))
        homeScreen.statusBar.hostRing = true
    }
    // A Basculer : ce PC devient celui de l'accueil (retenu dans la conf) ; endormi, on le réveille.
    function chooseHost(row) {
        var host = hostPicker.hosts[row]
        hostPicker.close()
        if (!host) return
        if (host.index !== activeComputerIndex) {
            consoleConfig.preferredHost = host.name
            pickActiveComputer()
        }
        if (!activeHostOnline && activeHostWakeable) wakeHost(true)
    }

    function openWifi() {
        WifiSetup.scan()
        openSettings("wifi")
        settingsScreen.focusContent(true)
    }

    function chooseNetwork(ssid) {
        var network = WifiSetup.networks.find(function(n) { return n.ssid === ssid })
        if (!network || network.active) return
        wifiTarget = ssid
        if (network.secured && !network.known) {
            keyboard.prompt = qsTr("Mot de passe de « %1 »").arg(ssid)
            keyboard.open("")           // (par-dessus les réglages : B sur le clavier vide y ramène)
        } else {
            connectWifi("")
        }
    }

    function connectWifi(password) {
        settingsScreen.close()
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
                keyboard.prompt = qsTr("Mot de passe de « %1 »").arg(home.wifiTarget)
                keyboard.open("")
            }
        }
    }

    // --- Confirmations (« un autre jeu tourne déjà », quitter le jeu, éteindre…) ---
    // Toutes destructives : confirmer demande de maintenir A.
    ConsoleDialog {
        id: confirmDialog
        anchors.fill: parent
        holdToConfirm: true
        property var pending: null
        // Pose la question ; `action` est appelée si l'on confirme (A maintenu), `doneLabel`
        // s'affiche alors à la place du libellé.
        function ask(title, message, confirmLabel, action, doneLabel) {
            confirmDialog.title = title
            confirmDialog.message = message
            confirmDialog.confirmLabel = confirmLabel
            confirmDialog.doneLabel = doneLabel || ""
            pending = action
            open()
        }
        onConfirmed: if (pending) pending()
        onClosed: homeScreen.forceActiveFocus()
    }

    // Réglages plein écran : sur le canevas, comme le panneau d'options.
    Item {
        width: home.width / Theme.scale
        height: Theme.canvasHeight
        scale: Theme.scale
        transformOrigin: Item.TopLeft

        SettingsScreen {
            id: settingsScreen
            anchors.fill: parent
            pages: home.settingsPages
            deviceName: SystemStatus.deviceName
            deviceInfo: {
                var free = opened ? SystemStatus.freeStorage() : -1
                return ["CocoOS"].concat(SystemStatus.batteryPercent >= 0 ? [qsTr("%1 %").arg(SystemStatus.batteryPercent)] : [],
                                         free >= 0 ? [qsTr("%1 libres").arg(home.humanSize(free))] : []).join(" · ")
            }
            timeText: homeScreen.timeText
            signalStrength: SystemStatus.signalStrength
            batteryPercent: SystemStatus.batteryPercent
            onChanged: function(key, value) { home.applySetting(key, value) }
            onActionRequested: function(key) { home.settingAction(key) }
            onHoldCompleted: function(key) { home.applySetting(key, 0) }
            onClosed: if (!keyboard.opened) homeScreen.forceActiveFocus()
        }
        SearchScreen {
            id: findScreen
            anchors.fill: parent
            recent: Library.parse(consoleConfig.recentSearches, [])
            hostName: home.activeHostName
            connected: homeScreen.connected
            latencyMs: homeScreen.latencyMs
            jitterMs: homeScreen.jitterMs
            timeText: homeScreen.timeText
            signalStrength: SystemStatus.signalStrength
            batteryPercent: SystemStatus.batteryPercent
            charging: SystemStatus.charging
            qwerty: home.english
            startDown: function() { return InputStatus.startHeld() }
            onChosen: function(index, query) { home.searchChosen(index, query) }
            onClosed: homeScreen.forceActiveFocus()
        }
        PowerMenu {
            id: powerMenu
            anchors.fill: parent
            z: 9
            actions: ["suspend", "reboot", "poweroff"].filter(function(k) { return SystemStatus.powerActions.indexOf(k) >= 0 })
            header: home.powerHeader
            onChosen: function(key) { home.powerAction(key) }
            onClosed: homeScreen.forceActiveFocus()
        }
        VolumeHud {
            id: volumeHud
            z: 10
            position: consoleConfig.volumeHud
            level: SystemStatus.volume / 100
        }
        HostPicker {
            id: hostPicker
            anchors.fill: parent
            onChosen: function(row) { home.chooseHost(row) }
            // « Ajouter un PC » mène au choix du PC de la première configuration (SetupPC,
            // phase 8) : refusé d'ici là.
            onAddRequested: { refuse(); Sounds.play("deny") }
            onClosed: {
                homeScreen.statusBar.hostRing = false
                homeScreen.forceActiveFocus()
            }
        }
        // Tant que la page Wi-Fi est ouverte, la liste se met à jour.
        Timer {
            interval: Theme.wifiRescan; repeat: true
            running: settingsScreen.opened && settingsScreen.pages[settingsScreen.page] !== undefined
                     && settingsScreen.pages[settingsScreen.page].key === "wifi"
            onTriggered: WifiSetup.scan()
        }
    }

    OnScreenKeyboard {
        id: keyboard
        anchors.fill: parent
        qwerty: home.english
        minLength: 8                    // WPA : 8 caractères au moins
        startDown: function() { return InputStatus.startHeld() }
        onAccepted: function(text) {
            home.connectWifi(text)
            homeScreen.forceActiveFocus()   // le clavier fermé ne doit plus rien avaler
        }
        onCancelled: settingsScreen.opened ? settingsScreen.forceActiveFocus() : home.openWifi()
    }

    // --- Menu Home : reprendre ou quitter le jeu en cours, veille, redémarrage, extinction ---
    ConsoleDialog {
        id: homeMenu
        anchors.fill: parent
        title: qsTr("Menu")
        onChosen: function(key) { home.homeMenuChosen(key) }
        onClosed: if (!confirmDialog.opened) homeScreen.forceActiveFocus()
    }

    // --- Téléchargement d'un jeu pas encore installé : pause / reprise, annulation ---
    ConsoleDialog {
        id: downloadMenu
        anchors.fill: parent
        property string gameId: ""
        onChosen: function(key) { home.downloadMenuChosen(key) }
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
            onRetryRequested: home.retryLaunch()
            // Y Réveiller le PC : retour à l'accueil, où la pastille du PC suit le réveil.
            onWakeRequested: {
                home.endLaunch()
                homeScreen.forceActiveFocus()
                home.wakeHost(true)
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
            onSoundCue: function(name) { Sounds.play(mode === "wake" ? "wake" : "boot-" + name) }
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
        IdleOverlay {
            id: sleepScreen
            anchors.fill: parent
            z: 1
            status: home.idleStatus
            onWoke: function(resuming) {
                var item = home.focusBeforeSleep
                home.focusBeforeSleep = null
                if (item) item.forceActiveFocus()
                else homeScreen.forceActiveFocus()
                home.rearmSleep()
                // A sur « Appuyez sur A pour reprendre » : le flux du jeu en cours repart.
                var index = resuming && home.runningGame !== "" ? home.findAppIndexByName(home.runningGame) : -1
                if (index >= 0) home.launchApp(index)
                else home.playWake()
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
                steps.splice(1, 0, size !== "" ? qsTr("Mise à jour de %1 sur le PC…").arg(size)
                                               : qsTr("Mise à jour sur le PC…"))
                launchScreen.steps = steps
                launchScreen.progress = 0
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

    // --- Fiche du jeu sélectionné (bas du pad) : à la place du héros, sur le fond du jeu ---
    // Fiche éditoriale du jeu (FicheEditoriale) : les champs du Companion qu'il connaît ; un
    // champ absent disparaît. Note critique et modes de jeu : pas dans l'API (next_steps.md, Q11).
    GamePage {
        id: gamePage
        parent: homeScreen.detailStage
        readonly property var info: homeScreen.info
        title: homeScreen.title
        logo: homeScreen.logo
        label: info ? Format.publisher(info) : ""
        meta: info ? Format.ficheMeta(info) : ""
        tags: info && Format.pegi(info.ageRatings) !== "" ? [Format.pegi(info.ageRatings)] : []
        description: info ? Format.plainText(info.description) : ""
        stats: info ? Format.ficheStats(info, home.humanSize(info.installSizeBytes)) : []
        details: info ? Format.ficheDetails(info, Qt.locale(home.english ? "en_US" : "fr_FR"), new Date()) : []
        favorite: homeScreen.favorite
        facts: info ? Format.facts(info)
                          .concat(info.installSizeBytes > 0 ? [home.humanSize(info.installSizeBytes)] : [])
                          .join(" · ") : ""
        credits: info ? Format.credits(info) : ""
        canUninstall: info ? info.uninstallable === true : false
        uninstalling: info ? home.uninstalls[info.id] === "UNINSTALLING" : false
        banner: homeScreen.favoriteBanner
        onUninstallRequested: home.confirmUninstall(info)
        onFavoriteRequested: home.toggleFavorite()
        onOptionsRequested: homeScreen.options.open()
        onPlayRequested: homeScreen.launchRequested(homeScreen.currentIndex)
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

        function onUninstallStateChanged(gameId, state) {
            home.setUninstall(gameId, state === "UNINSTALLING" ? state : "")
            if (state === "DONE") {
                homeScreen.toast(qsTr("%1 a été désinstallé").arg(home.gameName(gameId)))
                if (gamePage.info && gamePage.info.id === gameId) gamePage.close()
            } else if (state === "FAILED") {
                homeScreen.toast(qsTr("La désinstallation de %1 a échoué").arg(home.gameName(gameId)))
            }
        }
        function onUninstallFailed(gameId, code) {
            home.setUninstall(gameId, "")
            homeScreen.toast(code === "SESSION_ACTIVE" ? qsTr("Impossible pendant le lancement d'un jeu")
                           : code === "STEAM_UNAVAILABLE" ? qsTr("Steam est introuvable sur %1").arg(home.activeHostName)
                           : qsTr("La désinstallation de %1 a échoué").arg(home.gameName(gameId)))
        }

        function onDownloadStateChanged(gameId, state, bytesDone, bytesTotal) {
            home.setDownload(gameId, state === "CANCELLED" ? "" : state, bytesDone, bytesTotal)
        }
        function onDownloadFailed(gameId, code) {
            var name = home.gameName(gameId)
            // Rien côté PC : on oublie le téléchargement supposé (A le relancera).
            if (code === "NO_DOWNLOAD") home.setDownload(gameId, "", 0, 0)
            else if (!home.downloads[gameId] || home.downloads[gameId].bytesTotal === 0)
                home.setDownload(gameId, "", 0, 0)
            homeScreen.toast(code === "SESSION_ACTIVE" ? qsTr("Impossible pendant le lancement d'un jeu")
                           : code === "STEAM_UNAVAILABLE" ? qsTr("Steam est introuvable sur %1").arg(home.activeHostName)
                           : qsTr("Le téléchargement de %1 a échoué").arg(name))
        }

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
                launchScreen.progress = -1
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
                launchScreen.progress = bytesTotal > 0 ? bytesDone / bytesTotal : 0
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
            home.launchFailed((message && message !== "") ? message : code)
        }
    }
}
