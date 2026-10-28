import QtQuick
import QtTest
import StreamingPreferences 1.0
import CompanionClient 1.0
import ComputerManager 1.0
import SystemStatus 1.0
import InputStatus 1.0
import WifiSetup 1.0
import "../../../../app/gui/console"
import "../../../../app/gui/console/StreamProfiles.js" as Profiles
import "../../../../app/gui/console/BootTimeline.js" as Boot

// Le vrai ConsoleHome sur de faux modules Moonlight (stubs/) : les données des
// modèles arrivent dans l'accueil, la manette navigue, Y ouvre les options et les
// écrit dans les préférences, A lance le jeu (en direct, puis via le Companion).
//
//   XDG_CONFIG_HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen \
//       qmltestrunner-qt6 -import stubs -input tst_ConsoleHome.qml
Item {
    id: window
    width: Theme.canvasWidth; height: Theme.canvasHeight

    // ConsoleHome empile ses écrans de stream sur le `stackView` de main.qml.
    QtObject {
        id: stackView
        property int pushes: 0
        function push(item) { pushes++ }
    }

    ConsoleHome { id: home; anchors.fill: parent; focus: true }

    TestCase {
        name: "ConsoleHome"
        when: windowShown

        // Premier élément, sous `from`, qui porte la propriété `property`.
        function find(from, property) {
            for (var i = 0; i < from.children.length; i++) {
                var c = from.children[i]
                if (c[property] !== undefined) return c
                var deeper = find(c, property)
                if (deeper) return deeper
            }
            return null
        }
        readonly property var screen: find(home, "ready")
        // L'écran de lancement vit dans la fenêtre, au-dessus de ConsoleHome.
        readonly property var launchScreen: find(home.Window.window.contentItem, "progressShown")
        readonly property var updateDialog: find(home.Window.window.contentItem, "answered")
        readonly property var sleepScreen: find(home.Window.window.contentItem, "asleep")
        readonly property var curtain: find(home.Window.window.contentItem, "covering")
        // Les panneaux latéraux de ConsoleHome (confirmation, menu Home), par leur titre.
        function dialog(title) {
            var found = null
            var walk = function(from) {
                for (var i = 0; i < from.children.length && !found; i++) {
                    var c = from.children[i]
                    if (c.actions !== undefined && c.opened && c.title === title) found = c
                    else walk(c)
                }
            }
            walk(home)
            return found
        }

        function initTestCase() {
            find(home.Window.window.contentItem, "systemReady").finishNow()   // pas d'animation de démarrage
            Sounds.enabled = false
            verify(screen && launchScreen && updateDialog && curtain)
        }
        function init() {
            CompanionClient.paired = false
            CompanionClient.eventsConnected = false
            home.autoWakeDone = true                // pas de réveil d'office hors des tests qui le veulent
            home.setupDone = true                   // premier démarrage : cf. test_9l
            home.forceActiveFocus()
            tryCompare(screen, "count", 10)
            tryCompare(launchScreen, "active", false, 2000)
            screen.currentIndex = 0
        }

        function test_1_gamesAndHostReachTheHomeScreen() {
            verify(screen.ready)
            compare(screen.hostName, "Djinger")
            verify(screen.connected)
            compare(screen.title, "Minecraft")
            compare(screen.source, "Prism Launcher")
            compare(screen.lastPlayed, "Hier, 23:40")
            compare(screen.playtime, "412 h de jeu")
            verify(screen.backdrop.toString().endsWith("art/minecraft.jpg"))
            compare(screen.batteryPercent, 82)      // SystemStatus
            compare(screen.signalStrength, 4)
            compare(SystemStatus.probed, "Djinger") // le réseau vers le PC est sondé…
            compare(screen.latencyMs, 9)            // …et affiché
        }

        function test_2_padMovesBetweenGames() {
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 1)
            compare(screen.title, "Elden Ring")
            compare(screen.source, "Steam")
            compare(screen.lastPlayed, "Il y a 2 jours")
            keyClick(Qt.Key_Left)
            compare(screen.currentIndex, 0)
        }

        // Une ligne de l'onglet Flux par sa clé, et la manette jusqu'à elle.
        function fluxRow(key) { return home.optionTabs[0].rows.find(function(r) { return r.key === key }) }
        function goTo(key) {
            var sheet = screen.options
            var target = sheet.rows.findIndex(function(r) { return r.key === key })
            for (var i = 0; i < 20 && sheet.current !== target; i++)
                keyClick(sheet.current < target ? Qt.Key_Down : Qt.Key_Up)
            compare(sheet.rows[sheet.current].key, key)
        }

        function test_3_optionsWriteMoonlightPreferences() {
            var p = StreamingPreferences, sheet = screen.options
            p.width = 1920; p.height = 1080; p.fps = 60
            p.autoAdjustBitrate = true; p.bitrateKbps = 30000    // profil du premier démarrage
            home.refreshOptions()
            var shown = function(key) { var r = fluxRow(key); return r.options[r.index] }
            var hidden = function(key) { return sheet.isHidden(sheet.rows.indexOf(fluxRow(key))) }

            keyClick(Qt.Key_Hangup)                 // bouton Y
            verify(sheet.opened)
            compare(sheet.rows[0].label, "Profil")  // en tête : le profil de flux, Équilibré par défaut…
            compare(shown("streamProfile"), "Équilibré")
            compare(shown("advanced"), "Désactivé") // …et l'essentiel seulement
            verify(hidden("res") && hidden("profile") && hidden("hdr"))
            keyClick(Qt.Key_Down)                   // « Réglages avancés »…
            compare(sheet.rows[sheet.current].key, "advanced")
            keyClick(Qt.Key_Down)                   // …puis « Oublier ce PC » : les lignes repliées sont sautées
            compare(sheet.current, sheet.rows.length)
            keyClick(Qt.Key_Up)
            keyClick(Qt.Key_Return)                 // A : les réglages avancés
            compare(shown("advanced"), "Activé")
            verify(!hidden("res") && !hidden("hdr"))
            compare(fluxRow("profile").label, "Minecraft")   // dont les réglages du jeu sélectionné
            compare(shown("profile"), "Réglages communs")
            verify(fluxRow("res").auto)             // le profil choisit la définition (grisée)…
            verify(hidden("rateAuto"))              // …et le débit
            goTo("streamProfile")                   // le profil, jusqu'à Manuel : les réglages tels quels
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
            compare(shown("streamProfile"), "Manuel")
            verify(!fluxRow("res").auto)
            compare(shown("res"), "1080p")
            verify(!hidden("rateAuto"))
            compare(shown("rateAuto"), "Désactivé") // 30 Mb/s n'est pas la valeur automatique…
            compare(fluxRow("rate").value, 30)      // …le curseur la montre telle quelle

            goTo("res")
            keyClick(Qt.Key_Left)                   // résolution précédente
            verify(p.width !== 1920 || p.height !== 1080)
            compare(p.bitrateKbps, 30000)           // débit fixe : inchangé
            keyClick(Qt.Key_Right)
            compare(p.width, 1920)
            compare(screen.currentIndex, 0)         // les flèches ne touchent pas à la liste des jeux

            goTo("fps"); keyClick(Qt.Key_Right)     // images par seconde : 60 → 90
            compare(p.fps, 90)
            keyClick(Qt.Key_Left)
            compare(p.fps, 60)

            goTo("rate")                            // le curseur du débit : un cran, en débit fixe
            var before = fluxRow("rate").value      // (30 Mb/s est la valeur automatique à 90 i/s : le débit a pu le devenir)
            keyClick(Qt.Key_Right)
            compare(p.bitrateKbps, (before + 1) * 1000)
            verify(!p.autoAdjustBitrate)
            compare(shown("rateAuto"), "Désactivé")
            goTo("rateAuto"); keyClick(Qt.Key_Right)            // « Débit automatique » (après l'étirement du pouce)
            tryVerify(function() { return p.autoAdjustBitrate }, 500)
            compare(p.bitrateKbps, p.getDefaultBitrate(1920, 1080, 60, false))
            verify(fluxRow("rate").auto)            // le curseur montre la valeur automatique, grisée
            goTo("fps"); keyClick(Qt.Key_Right)     // 90 images par seconde : le débit automatique suit
            compare(p.bitrateKbps, p.getDefaultBitrate(1920, 1080, 90, false))
            keyClick(Qt.Key_Left)
            goTo("rate")                            // pousser le curseur repasse en débit fixe, depuis l'automatique
            var auto = fluxRow("rate").value
            keyClick(Qt.Key_Left)
            verify(!p.autoAdjustBitrate)
            compare(p.bitrateKbps, (auto - 1) * 1000)
            compare(shown("rateAuto"), "Désactivé")

            goTo("codec"); keyClick(Qt.Key_Return)  // codec : A passe au suivant
            compare(p.videoCodecConfig, p.VCC_FORCE_H264)
            keyClick(Qt.Key_Left)
            compare(p.videoCodecConfig, p.VCC_AUTO)
            goTo("hdr"); keyClick(Qt.Key_Return)    // HDR
            verify(p.enableHdr)
            keyClick(Qt.Key_Return)
            verify(!p.enableHdr)
            verify(p.saves > 0)

            keyClick(Qt.Key_Escape)                 // bouton B
            verify(!sheet.opened)
            keyClick(Qt.Key_Right)                  // le focus est revenu à l'étagère
            compare(screen.currentIndex, 1)
        }

        // A maintenu jusqu'au bout (action destructive) : remplissage, rebond, puis l'action.
        function holdA() {
            keyPress(Qt.Key_Return)
            wait(Theme.holdDuration + Theme.springBouncy.duration + 200)
            keyRelease(Qt.Key_Return)
        }

        // « Oublier ce PC » se maintient : un appui bref ne fait rien, un maintien lâché trop
        // tôt se vide (l'oubli lui-même : test_9z, en dernier).
        function test_4_forgettingThePcIsHeld() {
            keyClick(Qt.Key_Hangup)
            for (var i = 0; i < screen.optionRows.length; i++) keyClick(Qt.Key_Down)   // jusqu'à « Oublier ce PC »
            keyClick(Qt.Key_Return)
            compare(home.computerModel.count, 1)    // appui bref : rien
            var fill = find(screen.options, "holding")
            keyPress(Qt.Key_Return)
            tryVerify(function() { return fill.progress > 0.3 }, Theme.holdDuration)
            keyRelease(Qt.Key_Return)               // lâché trop tôt : il se vide
            tryCompare(fill, "progress", 0, Theme.holdDrain + 300)
            compare(home.computerModel.count, 1)
            keyClick(Qt.Key_Escape)
        }

        function test_5_directLaunch() {
            var before = stackView.pushes
            ignoreWarning(/.*/)                     // StreamSegue.qml n'existe pas dans le harnais
            keyClick(Qt.Key_Return)                 // bouton A
            verify(screen.pressed)
            compare(stackView.pushes, before)       // le flux attend l'ouverture de l'écran de lancement
            tryCompare(launchScreen, "active", true, 1000)
            verify(screen.launching)
            verify(launchScreen.fromThumb)              // l'écran part de la vignette du jeu…
            compare(launchScreen.origin, screen.activeThumbRect)
            verify(launchScreen.thumbnail.toString().endsWith("art/minecraft.jpg"))
            tryCompare(launchScreen, "grow", 1, 2000)   // …et finit en plein écran
            compare(launchScreen.steps.length, 2)
            compare(launchScreen.steps[0], "Lancement de Minecraft")
            keyClick(Qt.Key_Right)                  // la manette n'agit plus sur l'accueil
            compare(screen.currentIndex, 0)

            tryCompare(stackView, "pushes", before + 1, 3000)
            compare(launchScreen.step, 1)
            verify(launchScreen.frozen)             // immobile tant que Moonlight prépare son décodeur
            var session = home.appModel.lastSession
            session.stageStarting("RTSP handshake")
            verify(!launchScreen.frozen)
            verify(launchScreen.stepProgress > 0)

            compare(InputStatus.streamMenu, ["Minecraft", SystemStatus.powerActions, "xbox"])   // le menu en jeu
            session.connectionStarted()             // le flux est à l'écran
            verify(!launchScreen.active)
            verify(curtain.covering)                // le rideau CocoOS couvre l'accueil, caché
            verify(curtain.revealed)                // logo à l'écran, sous la fenêtre du flux
            verify(!screen.entryAllowed)
            session.sessionFinished(0)              // fin du jeu : l'accueil revient
            verify(!screen.launching)
            verify(!screen.pressed)
            home.returnedHome()                     // (StreamSegue dépilé)
            tryCompare(curtain, "covering", false, 3000)   // fin sans action du menu en jeu : il se lève
            verify(screen.entryAllowed)
        }

        // Fin du flux : la fenêtre de l'accueil réapparaît noire, avec le logo.
        function test_5b_curtainLogoWhenTheWindowReturns() {
            var win = home.Window.window
            curtain.cover()
            verify(!curtain.revealed)
            win.visible = false                     // pendant le flux
            win.visible = true                      // fin du flux
            verify(curtain.revealed && !curtain.waiting)
            compare(curtain.status, "")
            curtain.dismiss()
            tryCompare(curtain, "covering", false, 3000)   // après son temps minimal
            win.requestActivate()
        }

        function test_6_companionLaunchWithUpdate() {
            CompanionClient.paired = true
            CompanionClient.eventsConnected = true
            var before = stackView.pushes, cancels = CompanionClient.cancels
            ignoreWarning(/.*/)
            keyClick(Qt.Key_Return)
            compare(CompanionClient.launched, "game-0")
            tryCompare(launchScreen, "active", true, 1000)
            compare(launchScreen.steps.length, 3)
            verify(launchScreen.cancellable)

            CompanionClient.launchStateChanged("s", "game-0", "CHECKING")
            compare(launchScreen.step, 0)
            CompanionClient.updateRequired("s", "game-0", 2576980378)     // 2,4 Go
            verify(updateDialog.visible)
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Return)               // « Mettre à jour »
            compare(CompanionClient.updateAnswers[CompanionClient.updateAnswers.length - 1], true)
            compare(launchScreen.steps.length, 4)
            compare(launchScreen.steps[1], "Mise à jour de 2,4 Go sur le PC")
            compare(launchScreen.step, 1)
            CompanionClient.updateProgress("s", 50, 1, 2)
            compare(launchScreen.stepProgress, 0.5)
            CompanionClient.launchStateChanged("s", "game-0", "ARMING")
            compare(launchScreen.step, 2)

            wait(1200)                              // l'écran est ouvert depuis longtemps…
            compare(stackView.pushes, before)       // …mais pas de flux avant le READY de l'hôte
            CompanionClient.launchReady("s", "Minecraft")
            compare(stackView.pushes, before + 1)
            compare(launchScreen.step, 3)
            home.appModel.lastSession.sessionFinished(0)
            compare(CompanionClient.cancels, cancels)
        }

        function test_7_companionLaunchCancelledWithB() {
            CompanionClient.paired = true
            CompanionClient.eventsConnected = true
            var before = stackView.pushes, cancels = CompanionClient.cancels
            keyClick(Qt.Key_Return)
            tryCompare(launchScreen, "active", true, 1000)
            keyClick(Qt.Key_Escape)                 // bouton B
            compare(CompanionClient.cancels, cancels + 1)
            verify(!screen.launching)
            tryCompare(launchScreen, "active", false, 2000)
            wait(1200)
            compare(stackView.pushes, before)       // aucun flux n'a démarré
            keyClick(Qt.Key_Right)                  // l'accueil a repris la main
            compare(screen.currentIndex, 1)
        }

        function test_8_companionLaunchError() {
            CompanionClient.paired = true
            CompanionClient.eventsConnected = true
            keyClick(Qt.Key_Return)
            tryCompare(launchScreen, "active", true, 1000)
            CompanionClient.launchFailed("s", "GAME_NOT_INSTALLED", "Le jeu n'est pas installé sur le PC.")
            compare(launchScreen.error, "Le jeu n'est pas installé sur le PC.")
            var cancels = CompanionClient.cancels
            keyClick(Qt.Key_Escape)                 // B ferme l'écran d'erreur, sans rien annuler côté PC
            compare(CompanionClient.cancels, cancels)
            verify(!screen.launching)
        }

        function test_9a_companionBackgroundReplacesTheBoxArt() {
            CompanionClient.backgrounds = { "game-1": "file:///cache/bg-elden.jpg" }
            CompanionClient.libraryChanged()
            verify(screen.backdrop.toString().endsWith("art/minecraft.jpg"))   // pas d'image 16:9 : la jaquette
            keyClick(Qt.Key_Right)
            compare(screen.backdrop.toString(), "file:///cache/bg-elden.jpg")
            CompanionClient.backgrounds = {}
            CompanionClient.libraryChanged()
        }

        // Un logo dans la bibliothèque du Companion : il remplace le titre en texte.
        function test_9a_companionLogoReplacesTheTitle() {
            CompanionClient.logos = { "game-1": Qt.resolvedUrl("art/logo-elden.png").toString() }
            CompanionClient.libraryChanged()
            compare(screen.logo.toString(), "")            // Minecraft : pas de logo
            keyClick(Qt.Key_Right)                          // Elden Ring
            verify(screen.logo.toString().endsWith("art/logo-elden.png"))
            var lines = find(screen, "showLogo")
            tryVerify(function() {
                for (var i = 0; i < lines.parent.children.length; i++) {
                    var c = lines.parent.children[i]
                    if (c.showLogo && c.value.title === "Elden Ring") return true
                }
                return false
            }, 2000)
            CompanionClient.logos = {}
            CompanionClient.libraryChanged()
        }

        function test_9b_soundsSetting() {
            keyClick(Qt.Key_Hangup)
            keyClick(Qt.Key_PageDown)                       // onglet Console (R1)
            for (var i = 0; i < 4; i++) keyClick(Qt.Key_Down)
            var row = screen.optionRows[4]
            var sons = function() { return screen.optionRows[4].index }
            compare(row.label, "Sons")
            verify(row.toggle)                              // un interrupteur
            compare(row.options[row.index], "Activés")
            keyClick(Qt.Key_Right)                          // → vers l'état déjà là : une butée
            verify(screen.options.bump < 1)
            compare(screen.options.bumpDir, 1)
            wait(Theme.pressDuration + 50)
            compare(sons(), 1)
            keyClick(Qt.Key_Left)                           // ← coupe, après l'étirement du pouce
            compare(sons(), 1)
            tryVerify(function() { return sons() === 0 }, Theme.pressDuration + 200)
            verify(!Sounds.enabled)
            keyClick(Qt.Key_Right)                          // → active
            tryVerify(function() { return sons() === 1 }, Theme.pressDuration + 200)
            verify(Sounds.enabled)
            keyClick(Qt.Key_Return)                         // A bascule, au relâché
            compare(sons(), 0)
            keyClick(Qt.Key_Right)
            keyClick(Qt.Key_Escape)                         // refermé avant la fin de l'étirement :
            compare(sons(), 1)                              // la valeur est appliquée quand même
            verify(Sounds.enabled)
            Sounds.enabled = false
        }

        // Langue : écrite dans les préférences Moonlight, qui rechargent la traduction
        // (pas de traduction chargée dans le harnais : les textes restent en français).
        function test_9b_languageSetting() {
            keyClick(Qt.Key_Hangup)
            keyClick(Qt.Key_PageDown)                       // onglet Console (R1)
            for (var i = 0; i < 6; i++) keyClick(Qt.Key_Down)
            var retranslations = StreamingPreferences.retranslations
            compare(screen.optionRows[6].label, "Langue")
            compare(screen.optionRows[6].options[screen.optionRows[6].index], "Français")
            keyClick(Qt.Key_Right)
            compare(StreamingPreferences.language, StreamingPreferences.LANG_EN)
            compare(StreamingPreferences.retranslations, retranslations + 1)
            compare(screen.optionRows[6].options[screen.optionRows[6].index], "English")
            compare(home.humanSize(1.5 * 1024 * 1024 * 1024), "1.5 Go")   // virgule → point
            keyClick(Qt.Key_Left)
            compare(StreamingPreferences.language, StreamingPreferences.LANG_FR)
            compare(home.humanSize(1.5 * 1024 * 1024 * 1024), "1,5 Go")
            keyClick(Qt.Key_Escape)
        }

        // Vibrations : chaque son joué est transmis à InputStatus (qui choisit lesquels vibrent),
        // même sons coupés.
        function test_9b_rumbleFollowsSounds() {
            InputStatus.feedbacks = []
            keyClick(Qt.Key_Left)                           // tout à gauche : une butée
            verify(InputStatus.feedbacks.indexOf("edge") >= 0)
        }

        // « Réduire les animations » : plus de ressort ni de flou des textes, tout de suite.
        function test_9b_reduceMotion() {
            keyClick(Qt.Key_Hangup)
            keyClick(Qt.Key_PageDown)                       // onglet Console (R1)
            for (var i = 0; i < 5; i++) keyClick(Qt.Key_Down)
            compare(screen.optionRows[5].label, "Réduire les animations")
            verify(!Theme.reducedMotion)
            verify(Theme.springSnappy.duration > Theme.reducedSpring.duration)
            keyClick(Qt.Key_Return)                         // A bascule, au relâché
            verify(Theme.reducedMotion)
            compare(Theme.springSnappy, Theme.reducedSpring)
            compare(Theme.swapBlur, 0)
            keyClick(Qt.Key_Return)
            verify(!Theme.reducedMotion)
            verify(Theme.swapBlur > 0)
            keyClick(Qt.Key_Escape)
        }

        // Onglet Console : luminosité, volume, veille de l'écran, boutons. L1 / R1
        // (InputStatus) changent d'onglet.
        function test_9c_consoleSettings() {
            keyClick(Qt.Key_Hangup)
            InputStatus.bumperPressed(1)
            compare(screen.optionRows.map(function(r) { return r.label }),
                    ["Luminosité", "Volume", "Mise en veille après", "Boutons", "Sons", "Réduire les animations",
                     "Langue", "Wi-Fi"])
            verify(screen.optionRows[0].slider && screen.optionRows[1].slider)   // des curseurs
            keyClick(Qt.Key_Right)                          // luminosité 60 → 61 %
            compare(SystemStatus.brightness, 61)
            compare(screen.optionRows[0].value, 61)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Left)    // volume 75 → 74 %
            compare(SystemStatus.volume, 74)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)   // veille : 5 → 10 min
            compare(screen.optionRows[2].options[screen.optionRows[2].index], "10 min")
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)   // Boutons : PlayStation
            compare(Theme.buttonLayout, "playstation")
            keyClick(Qt.Key_Left); keyClick(Qt.Key_Left)    // Auto : sans manette, Xbox
            compare(Theme.buttonLayout, "xbox")
            InputStatus.bumperPressed(-1)                   // retour à l'onglet Flux
            compare(screen.optionRows[0].label, "Profil")
            keyClick(Qt.Key_Escape)
        }

        // Le Companion est découvert mais pas appairé : son écran de code remplace
        // l'accueil et prend la manette, puis la rend à l'étagère une fois appairé.
        function test_9c_companionPairingTakesThePad() {
            CompanionClient.certFingerprint = "ab12"
            verify(screen.staged)
            keyClick(Qt.Key_Up)                             // 1re case : 0 → 1
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Down)   // 2e case : 0 → 9
            compare(screen.currentIndex, 0)                 // l'étagère n'a rien reçu
            keyClick(Qt.Key_Return)
            compare(CompanionClient.confirmedCode, "190000")
            var pairing = find(home, "errorText")
            CompanionClient.pairingFailed("PAIR_INVALID")    // code refusé : les cases se secouent
            compare(pairing.errorText, "Code incorrect — réessayez.")
            tryVerify(function() { return find(pairing, "shakeProgress").shakeProgress < 1 }, 300)
            CompanionClient.paired = true
            verify(!screen.staged)
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 1)
            CompanionClient.certFingerprint = ""
        }

        // Au prochain démarrage, l'accueil s'ouvre sur le dernier jeu lancé.
        Component { id: anotherHome; ConsoleHome { anchors.fill: parent } }
        function test_9d_reopensOnTheLastGamePlayed() {
            ignoreWarning(/.*/)
            for (var i = 0; i < 3; i++) keyClick(Qt.Key_Right)  // Hades II
            var before = stackView.pushes
            keyClick(Qt.Key_Return)
            tryCompare(stackView, "pushes", before + 1, 3000)
            home.appModel.lastSession.sessionFinished(0)
            wait(800)                                       // Settings écrit après un court délai

            var again = createTemporaryObject(anotherHome, window)
            var screen2 = find(again, "ready")
            tryCompare(screen2, "count", 10)
            compare(screen2.currentIndex, 0)               // le plus récent passe en tête
            compare(screen2.title, "Hades II")
            Sounds.enabled = false
        }

        // PC endormi : A le réveille d'abord (première étape du lancement), puis le
        // lancement reprend tout seul quand il répond.
        function test_9g_launchWakesTheSleepingPc() {
            var pc = home.computerModel
            pc.setProperty(0, "online", false)
            var wakes = pc.wakes, before = stackView.pushes, name = screen.title
            ignoreWarning(/.*/)
            keyClick(Qt.Key_Return)
            compare(pc.wakes, wakes + 1)
            tryCompare(launchScreen, "active", true, 1000)
            compare(launchScreen.steps[0], "Réveil de Djinger")
            compare(launchScreen.step, 0)
            wait(1200)
            compare(stackView.pushes, before)       // rien tant que le PC dort
            pc.setProperty(0, "online", true)
            tryCompare(launchScreen, "step", 2, 2000)   // réveil fait, lancement fait : ouverture du flux
            compare(launchScreen.steps.length, 3)
            compare(launchScreen.steps[1], "Lancement de " + name)
            tryCompare(stackView, "pushes", before + 1, 2000)
            home.appModel.lastSession.sessionFinished(0)
        }

        // Au démarrage, un PC connu mais hors ligne est réveillé d'office, une fois.
        // Sans jeu à afficher, l'écran de recherche propose A pour le réveiller.
        function test_9h_offlinePcIsWokenAtStartAndOnDemand() {
            var pc = home.computerModel
            var wakes = pc.wakes
            pc.setProperty(0, "online", false)
            home.autoWakeDone = false
            tryCompare(pc, "wakes", wakes + 1, Theme.autoWakeDelay + 1000)
            verify(home.waking)
            home.waking = false                     // (sans réponse du PC)
            home.wakeFailed = true
            home.appModel.clear()                   // pas de jeu : l'écran de recherche
            tryCompare(screen, "staged", true, 1000)
            keyClick(Qt.Key_Return)                 // A : réessayer
            compare(pc.wakes, wakes + 2)
            pc.setProperty(0, "online", true)
            verify(!home.waking && !home.wakeFailed)
            home.rebuildAppModel()
        }

        // Bouton Home : le menu, puis « Éteindre », qui demande confirmation.
        function test_9i_homeButtonMenuPowersOff() {
            SystemStatus.lastPower = ""
            InputStatus.homePressed()
            var menu = dialog("Menu")
            verify(menu)
            compare(menu.labels, ["Mettre en veille", "Redémarrer", "Éteindre"])
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
            verify(!menu.opened)
            var confirm = dialog("Éteindre la console ?")
            verify(confirm)
            compare(SystemStatus.lastPower, "")           // rien sans confirmation
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
            compare(SystemStatus.lastPower, "")           // un appui bref ne confirme pas : A se maintient
            holdA()
            compare(SystemStatus.lastPower, "poweroff")
            InputStatus.homePressed(); verify(dialog("Menu"))
            InputStatus.homePressed(); verify(!dialog("Menu"))   // Home referme le menu
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 1)               // la manette est revenue à l'étagère
        }

        // Ctrl + Maj + Alt + Tab : le bouton Home au clavier (Qt dit Backtab avec Maj).
        function test_9i_keyboardHomeShortcut() {
            var all = Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier
            keyClick(Qt.Key_Tab, all); verify(dialog("Menu"))
            keyClick(Qt.Key_Backtab, all); verify(!dialog("Menu"))
            keyClick(Qt.Key_Backtab, all); verify(dialog("Menu"))
            keyClick(Qt.Key_Tab, all); verify(!dialog("Menu"))
        }

        // Les panneaux valident au relâché de A, et seulement après un appui fait chez
        // eux : le relâché qui a ouvert la confirmation ne la valide pas.
        function test_9i_panelsActOnRelease() {
            SystemStatus.lastPower = ""
            InputStatus.homePressed()
            var menu = dialog("Menu")
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Down)
            keyPress(Qt.Key_Return)
            verify(menu.opened && menu.pressing)          // rien à l'appui
            keyRelease(Qt.Key_Return)
            var confirm = dialog("Éteindre la console ?")
            verify(confirm && !confirm.pressing)
            keyClick(Qt.Key_Down)
            keyRelease(Qt.Key_Return)                     // relâché sans appui : rien
            verify(confirm.opened)
            compare(SystemStatus.lastPower, "")
            keyClick(Qt.Key_Escape)
            verify(!dialog("Éteindre la console ?"))
        }

        // Quitté par le menu en jeu : « Quitter » ferme le jeu sur le PC, « Retour à
        // l'accueil » ne fait rien de plus, une action d'alimentation part aussitôt
        // (déjà confirmée dans le menu).
        function test_9j_leavingAGameFromTheInGameMenu() {
            var apps = home.appModel
            apps.runningName = "Hades II"
            var quits = apps.quits
            InputStatus.streamExit = "quit"
            home.streamStarted = true
            home.returnedHome()
            compare(apps.quits, quits + 1)

            InputStatus.streamExit = "home"
            home.streamStarted = true
            home.returnedHome()
            compare(apps.quits, quits + 1)
            verify(!dialog("Menu"))

            SystemStatus.lastPower = ""
            InputStatus.streamExit = "suspend"
            home.streamStarted = true
            home.returnedHome()
            compare(SystemStatus.lastPower, "suspend")
            apps.runningName = ""
            home.homeGuardUntil = 0
        }

        // Quitter le jeu depuis le menu en jeu : le rideau CocoOS couvre l'accueil, dit
        // « Fermeture de … », garde la manette, et se lève à la réponse du PC.
        function test_9n_curtainWhileQuittingTheGame() {
            var apps = home.appModel
            apps.runningName = "Hades II"
            var quits = apps.quits
            curtain.cover()                         // posé au début du flux
            InputStatus.streamExit = "quit"
            home.streamStarted = true
            home.returnedHome()
            compare(apps.quits, quits + 1)
            verify(curtain.revealed && curtain.waiting)
            compare(curtain.status, "Fermeture de Hades II…")
            verify(!screen.entryAllowed)
            InputStatus.homePressed()               // la manette reste au rideau
            verify(!dialog("Menu"))
            ComputerManager.quitAppCompleted(null)
            tryCompare(curtain, "covering", false, 3000)   // après son temps minimal
            verify(screen.entryAllowed)                    // l'accueil rentre
            tryCompare(curtain, "visible", false, 3000)
            apps.runningName = ""
            home.homeGuardUntil = 0
        }

        // La veille : la touche qui réveille n'atteint pas l'accueil, la suivante si.
        function test_9k_sleepSwallowsTheWakingKey() {
            screen.currentIndex = 2
            sleepScreen.sleep()
            verify(sleepScreen.asleep)
            keyClick(Qt.Key_Right)
            verify(!sleepScreen.asleep)
            compare(screen.currentIndex, 2)
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 3)
            sleepScreen.sleep()
            InputStatus.homePressed()                     // Home réveille, sans ouvrir le menu
            verify(!sleepScreen.asleep)
            verify(!dialog("Menu"))
        }

        // Veille pendant une partie : A (« Appuyez sur A pour reprendre ») relance le flux du jeu
        // en cours ; une autre touche ne fait que réveiller. Sans partie, A ne fait que réveiller.
        function test_9k_aResumesTheRunningGame() {
            var apps = home.appModel, tile = home.currentTile()
            sleepScreen.sleep()
            keyClick(Qt.Key_Return)                       // pas de partie : simple réveil
            verify(!sleepScreen.asleep)
            verify(!launchScreen.active)
            apps.setProperty(tile.appIndex, "running", true)
            apps.runningName = tile.name
            sleepScreen.sleep()
            keyClick(Qt.Key_Down)                         // une autre touche : simple réveil
            verify(!sleepScreen.asleep)
            verify(!launchScreen.active)
            sleepScreen.sleep()
            keyClick(Qt.Key_Return)
            verify(!sleepScreen.asleep)
            tryCompare(launchScreen, "active", true, 1000)
            launchScreen.cancelRequested()                // B : annule le lancement
            tryCompare(launchScreen, "active", false, 3000)
            apps.setProperty(tile.appIndex, "running", false)
            apps.runningName = ""
        }

        // Réglages à part pour un jeu : ils ne touchent pas aux réglages communs, et ne
        // remplacent ceux-ci que le temps de sa session.
        function test_9m_gameWithItsOwnStreamSettings() {
            var p = StreamingPreferences
            p.fps = 60
            var name = screen.title
            home.applyOption("advanced", 1)                // (la ligne du jeu est un réglage avancé)
            keyClick(Qt.Key_Hangup)
            compare(fluxRow("profile").label, name)
            goTo("profile")
            keyClick(Qt.Key_Right)                          // « Réglages à part »
            goTo("fps")
            keyClick(Qt.Key_Right)                          // 60 → 90 images par seconde
            var fps = screen.optionRows.indexOf(fluxRow("fps"))
            compare(screen.optionRows[fps].options[screen.optionRows[fps].index], "90")
            compare(p.fps, 60)                              // les réglages communs n'ont pas bougé
            keyClick(Qt.Key_Escape)

            ignoreWarning(/.*/)
            var before = stackView.pushes
            keyClick(Qt.Key_Return)
            tryCompare(launchScreen, "active", true, 1000)
            verify(launchScreen.steps[launchScreen.steps.length - 1].indexOf("p90") > 0)
            tryCompare(stackView, "pushes", before + 1, 3000)
            compare(p.fps, 90)                              // le temps de la session…
            home.appModel.lastSession.sessionFinished(0)
            compare(p.fps, 60)                              // …puis les communs reviennent
            home.returnedHome()                             // (ce que fait la pile d'écrans au retour)

            keyClick(Qt.Key_Hangup)                         // retour aux réglages communs
            goTo("profile")
            keyClick(Qt.Key_Left)
            compare(fluxRow("fps").options[fluxRow("fps").index], "60")
            keyClick(Qt.Key_Escape)
        }

        // L'animation de démarrage attend que l'accueil sache quoi montrer : des jeux,
        // ou un écran qui n'attend plus le réseau (ici : PC hors ligne confirmé).
        function test_9n_bootWaitsForSomethingToShow() {
            verify(home.bootReady)                  // des jeux
            compare(SystemStatus.started, true)     // relevés lancés à la fin de l'animation
            var pc = home.computerModel
            home.appModel.clear()
            tryCompare(home, "bootReady", false)    // PC en ligne, bibliothèque vide : on attend
            compare(home.bootStep, "Chargement de la bibliothèque")
            pc.setProperty(0, "online", false)
            verify(home.bootReady)                  // hors ligne, confirmé : l'écran du PC éteint
            compare(home.bootStep, "Recherche de l’hôte")
            pc.setProperty(0, "online", true)
            home.rebuildAppModel()
            tryCompare(screen, "count", 10)
        }

        // Fin de l'animation de démarrage : l'accueil n'entre qu'à E + 250, et le logo
        // vole jusqu'à celui de la barre haute, au pixel près (BOOT_ANIMATION.md §11.6).
        Component { id: freshHome; ConsoleHome { anchors.fill: parent } }
        function test_9o_bootLogoLandsOnTheTopBarLogo() {
            var h = createTemporaryObject(freshHome, window)
            var sp = h.splash
            var screen2 = find(h, "ready")
            tryVerify(function() { return sp.running && sp.readyAt >= 0 }, 3000)
            sp.running = false                              // le temps avance à la main
            var E = sp.exitAt
            sp.advance(E + 200 - sp.t)
            verify(!screen2.entryAllowed)
            verify(!screen2.statusLogoShown)                // le vrai logo attend le relais
            sp.advance(100)                                 // E + 300
            verify(screen2.entryAllowed)
            sp.advance(E + Boot.T.exitDur - 0.01 - sp.t)    // fin du vol
            var flying = find(sp, "letters"), bar = screen2.statusLogo
            var a = flying.mapToItem(null, 0, 0), b = flying.mapToItem(null, flying.width, flying.height)
            var c = bar.mapToItem(null, 0, 0), d = bar.mapToItem(null, bar.width, bar.height)
            ;[[a.x, c.x], [a.y, c.y], [b.x, d.x], [b.y, d.y]].forEach(function(p) {
                verify(Math.abs(p[0] - p[1]) <= 1, "écart au relais : " + p[0] + " / " + p[1])
            })
            sp.advance(1)
            verify(!sp.visible)
            verify(screen2.statusLogoShown)                 // même image : le vrai logo prend le relais
        }

        // Sortie de veille : l'accueil rentre, le logo de la barre haute respire puis
        // revient tel quel ; la manette reste à l'accueil.
        function test_9p_wakeReplaysTheEntry() {
            var sp = home.splash, bar = screen.statusLogo
            home.playWake()
            sp.running = false
            verify(!screen.entryAllowed)
            sp.advance(200)                                 // u = 120 ms
            verify(screen.entryAllowed)
            verify(bar.opacity > 0 && bar.opacity < 1)
            verify(bar.lum < 1)
            sp.advance(400)                                 // u = 520 ms : le O respire
            verify(bar.oScale > 1)
            sp.advance(600)
            verify(sp.done)
            compare([bar.opacity, bar.lum, bar.oScale], [1, 1, 1])
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 1)
        }

        // Premier démarrage hors ligne : bienvenue, choix du réseau, mot de passe au
        // clavier à l'écran ; l'accueil arrive une fois la console en ligne.
        function test_9l_firstRunAsksForTheNetwork() {
            WifiSetup.online = false
            home.welcomed = false
            home.setupDone = false
            verify(screen.staged)
            keyClick(Qt.Key_Return)                         // « Commencer »
            verify(home.welcomed && !home.setupDone)
            keyClick(Qt.Key_Return)                         // « Choisir un réseau »
            var sheet = null
            var walk = function(from) {
                for (var i = 0; i < from.children.length && !sheet; i++) {
                    var c = from.children[i]
                    if (c.tabs !== undefined && c.title === "Wi-Fi") sheet = c
                    else walk(c)
                }
            }
            walk(home)
            verify(sheet && sheet.opened)
            compare(sheet.rows.map(function(r) { return r.label }), ["Maison", "Voisins", "Café"])
            verify(sheet.rows[0].checked && !sheet.rows[1].checked)  // le réseau connecté est coché…
            keyClick(Qt.Key_Return)                         // …et le choisir à nouveau est refusé…
            verify(sheet.opened)
            compare(WifiSetup.lastConnect, null)
            verify(sheet.hintShown)                         // …avec pourquoi, sous la liste
            compare(sheet.hint, "La console est déjà connectée à ce réseau.")
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)  // « Voisins » : protégé, inconnu
            verify(!sheet.opened)
            keyClick(Qt.Key_S); keyClick(Qt.Key_E); keyClick(Qt.Key_C); keyClick(Qt.Key_R)
            keyClick(Qt.Key_E); keyClick(Qt.Key_T); keyClick(Qt.Key_1); keyClick(Qt.Key_2)
            keyClick(Qt.Key_Return)
            compare(WifiSetup.lastConnect.ssid, "Voisins")
            compare(WifiSetup.lastConnect.password, "secret12")
            WifiSetup.online = true                         // connecté : la suite du démarrage
            verify(home.setupDone)
            verify(!screen.staged)
            keyClick(Qt.Key_Right)                          // la manette est revenue à l'étagère
            compare(screen.currentIndex, 1)
        }

        // X épingle le jeu en tête de l'étagère (la sélection le suit), puis le détache.
        function test_9e_xPinsTheGameInFront() {
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
            var name = screen.title
            verify(!screen.favorite)
            keyClick(Qt.Key_Menu)                           // bouton X
            compare(screen.currentIndex, 0)
            compare(screen.title, name)
            verify(screen.favorite)
            verify(find(screen, "shown").shown !== undefined)
            keyClick(Qt.Key_Right); keyClick(Qt.Key_Left)   // il reste en tête
            compare(screen.title, name)
            keyClick(Qt.Key_Menu)
            verify(!screen.favorite)
            compare(screen.title, name)
            verify(screen.currentIndex > 0)                 // revenu à sa place
        }

        // Collections : R1 sur l'étagère passe aux favoris (le jeu épinglé seul), L1 revient à
        // tout ; détacher le dernier favori fait disparaître la collection.
        function test_9e_collections() {
            compare(home.collections.indexOf("favorites"), -1)  // aucun favori : pas d'onglet
            keyClick(Qt.Key_Right)
            var name = screen.title
            keyClick(Qt.Key_Menu)                           // X : épinglé
            verify(home.collections.indexOf("favorites") > 0)
            InputStatus.bumperPressed(1)
            compare(home.collection, "favorites")
            compare(screen.count, 1)
            compare(screen.title, name)
            InputStatus.bumperPressed(-1)
            compare(home.collection, "all")
            compare(screen.count, 10)
            compare(screen.title, name)                     // la sélection suit le jeu
            InputStatus.bumperPressed(1)
            keyClick(Qt.Key_Menu)                           // détaché : plus de favori
            compare(home.collection, "all")
            compare(home.collections.indexOf("favorites"), -1)
            InputStatus.triggerPressed(1)                   // R2 : dix plus loin, le dernier
            compare(screen.currentIndex, 9)
        }

        // Les utilitaires d'Apollo (ici « Desktop ») ne sont pas sur l'étagère.
        function test_9f_utilitiesAreNotOnTheShelf() {
            compare(home.appModel.count, 11)
            compare(screen.count, 10)
            for (var i = 0; i < 10; i++) {
                screen.currentIndex = i
                verify(screen.title !== "Desktop")
            }
        }

        // Un jeu du PC pas encore installé : en fin d'étagère, A le télécharge sans autre
        // question, puis A ouvre le menu de son téléchargement (pause, annulation).
        function test_9q_downloadAGameNotYetInstalled() {
            var lastCall = function() { return CompanionClient.downloadCalls[CompanionClient.downloadCalls.length - 1] }
            CompanionClient.paired = true
            CompanionClient.eventsConnected = true
            CompanionClient.extraGames = [{ id: "dl-1", name: "Celeste", isInstalled: false, downloadable: true, cover: "" }]
            CompanionClient.libraryChanged()
            tryCompare(screen, "count", 11)
            screen.currentIndex = 10                        // après les 10 jeux installés
            compare(screen.title, "Celeste")
            compare(screen.playLabel, "Télécharger")
            compare(screen.updateNote, "Non installé")

            keyClick(Qt.Key_Return)
            compare(lastCall(), "download:dl-1")
            verify(!screen.launching)                       // pas d'écran de lancement
            compare(screen.playLabel, "Téléchargement")
            CompanionClient.downloadStateChanged("dl-1", "DOWNLOADING", 1, 4)
            tryCompare(screen, "updateNote", "Téléchargement en cours")
            compare(home.downloadFraction("dl-1"), 0.25)

            keyClick(Qt.Key_Return)                         // le menu du téléchargement
            verify(dialog("Celeste"))
            keyClick(Qt.Key_Return)                         // « Mettre en pause »
            compare(lastCall(), "pause:dl-1")
            CompanionClient.downloadStateChanged("dl-1", "PAUSED", 1, 4)
            tryCompare(screen, "updateNote", "Téléchargement en pause")

            keyClick(Qt.Key_Return)
            verify(dialog("Celeste"))
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)  // « Annuler le téléchargement »
            verify(dialog("Annuler le téléchargement ?"))   // les fichiers seront supprimés : on confirme
            keyClick(Qt.Key_Right); holdA()
            compare(lastCall(), "cancel:dl-1")
            CompanionClient.downloadStateChanged("dl-1", "CANCELLED", 0, 0)
            tryCompare(screen, "playLabel", "Télécharger")

            // Installé : la vignette reste le temps que l'app arrive dans la liste du PC.
            CompanionClient.extraGames = [{ id: "dl-1", name: "Celeste", isInstalled: true, downloadable: false, cover: "" }]
            CompanionClient.libraryChanged()
            tryCompare(screen, "updateNote", "Installé — prêt dans un instant")
            compare(screen.playLabel, "")
            CompanionClient.extraGames = []
            CompanionClient.libraryChanged()
            tryCompare(screen, "count", 10)
        }

        // Bas sur un jeu : sa fiche sur le même fond (héros et étagère s'effacent) ; B, ou haut
        // une fois en haut, la referme. Tout en bas, « Désinstaller » → confirmation → le PC.
        function test_9r_gamePageAndUninstall() {
            CompanionClient.paired = true
            CompanionClient.eventsConnected = true
            var page = find(home, "uninstalling")
            // Elden Ring porte la fiche de démo ; sa place dépend des tests précédents (récents).
            for (var j = 0; j < screen.count && screen.title !== "Elden Ring"; j++) screen.currentIndex = j
            compare(screen.title, "Elden Ring")
            keyClick(Qt.Key_Down)
            tryCompare(page, "shown", true)
            verify(screen.staged)
            compare(page.facts, "Action · RPG · 2022 · PEGI 16 · 49,7 Go")
            compare(page.credits, "FromSoftware · Bandai Namco")
            compare(page.description.indexOf("Lève-toi, Sans-éclat"), 0)
            verify(page.canUninstall)
            keyClick(Qt.Key_Escape)                         // B
            tryCompare(page, "shown", false)
            verify(!screen.staged)
            compare(screen.title, "Elden Ring")

            keyClick(Qt.Key_Down)
            tryCompare(page, "shown", true)
            keyClick(Qt.Key_Up)                             // déjà en haut : on referme
            tryCompare(page, "shown", false)

            keyClick(Qt.Key_Down)
            tryCompare(page, "shown", true)
            for (var i = 0; i < 40 && !page.onButton; i++) keyClick(Qt.Key_Down)   // la description défile…
            verify(page.onButton)                           // …puis le bouton
            keyClick(Qt.Key_Return)
            verify(dialog("Désinstaller Elden Ring ?"))
            keyClick(Qt.Key_Right); holdA()                 // confirmer : A maintenu
            compare(CompanionClient.uninstallCalls[CompanionClient.uninstallCalls.length - 1], "game-1")
            verify(page.uninstalling)
            verify(page.shown)                              // la fiche reste ouverte pendant le travail du PC
            CompanionClient.uninstallStateChanged("game-1", "DONE")
            tryCompare(page, "shown", false)
            verify(!page.uninstalling)
        }

        // Sans fiche Companion (console non appairée) : bas reste une butée.
        function test_9s_noGamePageWithoutCompanion() {
            CompanionClient.paired = false
            var page = find(home, "uninstalling")
            var saved = CompanionClient.details
            CompanionClient.details = ({})
            home.companionGames = ({})
            keyClick(Qt.Key_Down)
            wait(100)
            verify(!page.shown)
            CompanionClient.details = saved
            CompanionClient.libraryChanged()
        }

        // Débit au curseur : maintenu, le pas accélère (1, 2, puis 5) avec un arrêt sur
        // chaque cran marqué ; en bout de course, la butée élastique, comme une valeur au
        // bout de sa liste. Les valeurs numériques roulent, les autres glissent.
        function test_9t_bitrateSliderAndRubber() {
            var p = StreamingPreferences, sheet = screen.options
            home.applyOption("streamProfile", 4)            // Manuel
            p.width = 1920; p.height = 1080; p.fps = 30
            p.autoAdjustBitrate = false; p.bitrateKbps = 30000
            home.refreshOptions()
            compare(sheet.numberParts("40 %").n, 40)
            compare(sheet.numberParts("40 %").suffix, " %")
            compare(sheet.numberParts("120").n, 120)
            compare(sheet.numberParts("Natif 2560×1600"), null)

            var values = []
            var record = function(key, value) { if (key === "rate") values.push([Date.now(), value]) }
            sheet.changed.connect(record)
            home.applyOption("advanced", 1)
            keyClick(Qt.Key_Hangup)
            goTo("rate")
            keyPress(Qt.Key_Right)
            tryVerify(function() { return p.bitrateKbps >= 75000 }, 8000)
            keyRelease(Qt.Key_Right)
            sheet.changed.disconnect(record)
            var steps = values.map(function(v, i) { return v[1] - (i > 0 ? values[i - 1][1] : 30) })
            compare(steps[0], 1)
            verify(steps.indexOf(2) > 0 && steps.lastIndexOf(5) > steps.indexOf(2), "pas : " + steps)
            var at40 = values.findIndex(function(v) { return v[1] === 40 })
            verify(at40 > 0, "arrêt sur 40 : " + values.map(function(v) { return v[1] }))
            verify(values[at40 + 1][0] - values[at40][0] >= Theme.sliderStopHold - 30, "arrêté sur 40")
            verify(sheet.pulseStop === 40 || sheet.pulseStop === 80, "un cran franchi pulse")

            // À la souris : la poignée suit le pointeur, accrochée à un cran proche ; au-delà
            // du bout, la butée s'étire, et revient au relâché.
            var slider = function() { return screen.optionRows[sheet.current] }
            var track = 384, at = function(mbps) { return track * (mbps - 5) / 145 }
            sheet.dragTo(slider(), at(39), track)
            compare(p.bitrateKbps, 40000)                   // 39 : accroché au cran 40
            sheet.dragTo(slider(), at(66), track)
            compare(p.bitrateKbps, 66000)
            sheet.dragTo(slider(), track + Theme.sliderDragSpan, track)
            compare(p.bitrateKbps, 150000)
            compare(sheet.rubberX, Theme.sliderDragRubber / 2)
            sheet.dragEnd()
            tryCompare(sheet, "rubberX", 0, 1500)
            var area = null                                 // et un vrai clic, au milieu de la piste
            var walk = function(from) {
                for (var i = 0; i < from.children.length && !area; i++) {
                    var c = from.children[i]
                    if (c.preventStealing === true && c.enabled && c.visible) area = c
                    else walk(c)
                }
            }
            walk(sheet)
            verify(area)
            mouseClick(area, area.width / 2, area.height / 2)
            compare(p.bitrateKbps, 78000)                   // (5 + 150) / 2, arrondi

            p.bitrateKbps = 150000; home.refreshOptions()
            keyClick(Qt.Key_Right)                          // au bout : la butée
            compare(p.bitrateKbps, 150000)
            tryVerify(function() { return sheet.rubberX > 0 }, 300)
            tryCompare(sheet, "rubberX", 0, 1500)
            goTo("fps")                                     // images par seconde, déjà à 30
            keyClick(Qt.Key_Left)
            compare(p.fps, 30)
            tryVerify(function() { return sheet.rubberX < 0 }, 300)
            tryCompare(sheet, "rubberX", 0, 1500)
            keyClick(Qt.Key_Escape)
        }

        // Changer une valeur ne fait pas bouger le soulignement des onglets (la liste des
        // réglages est reconstruite à chaque changement, pas les onglets).
        function test_9u_tabUnderlineStaysWhenAValueChanges() {
            keyClick(Qt.Key_Hangup)
            keyClick(Qt.Key_PageDown)                       // onglet Console
            var underline = find(screen.options, "targetLeft")
            wait(800)                                       // posé sur « Console »
            var left = underline.leftEdge, moved = 0
            verify(left > 0)
            var watch = function() { moved = Math.max(moved, Math.abs(underline.leftEdge - left)) }
            underline.leftEdgeChanged.connect(watch)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Left)    // volume : -10 %
            wait(600)
            underline.leftEdgeChanged.disconnect(watch)
            compare(moved, 0)
            keyClick(Qt.Key_Right)
            keyClick(Qt.Key_Escape)
        }

        // Profils de flux : sous un profil automatique, le lancement prend ce qu'il choisit
        // pour cet écran et ce réseau, sans rien enregistrer ; un réseau mauvais retire deux
        // paliers (la note le dit) ; toucher un réglage du lancement passe en Manuel, à partir
        // de ce que le profil choisissait.
        function test_9v_streamProfiles() {
            var p = StreamingPreferences
            var row = function(key) { return home.optionTabs[0].rows.find(function(r) { return r.key === key }) }
            var shown = function(key) { return row(key).options[row(key).index] }
            home.applyOption("streamProfile", 1)            // Équilibré
            p.width = 1920; p.height = 1080; p.fps = 60; p.bitrateKbps = 30000; p.autoAdjustBitrate = false
            home.refreshOptions()
            compare(shown("streamProfile"), "Équilibré")
            var chosen = Profiles.launchSettings("balanced", home.profileContext())
            compare(row("streamProfile").stats[0].value, chosen.height + "p")
            compare(row("streamProfile").stats[3].value, "équilibre")
            verify(row("res").auto && row("fps").auto && row("rate").auto)
            verify(row("rateAuto").hidden)                  // le profil choisit le débit

            var saves = p.saves
            home.applyGameProfile("")                       // au lancement
            compare([p.width, p.height, p.fps, p.bitrateKbps], [chosen.width, chosen.height, chosen.fps, chosen.bitrateKbps])
            compare(p.saves, saves)                         // rien d'enregistré
            home.restoreCommonSettings()                    // au retour
            compare([p.width, p.height, p.fps, p.bitrateKbps], [1920, 1080, 60, 30000])

            SystemStatus.latencyMs = 90                     // réseau mauvais
            home.refreshOptions()
            compare(row("streamProfile").note, "Réseau faible : deux crans plus bas")
            SystemStatus.latencyMs = 9
            home.refreshOptions()
            compare(row("streamProfile").note, "")

            home.applyOption("advanced", 1)
            keyClick(Qt.Key_Hangup)                         // toucher la définition : Manuel
            goTo("res")
            var before = shown("res")
            keyClick(row("res").index > 0 ? Qt.Key_Left : Qt.Key_Right)   // (vers une autre définition)
            compare(shown("streamProfile"), "Manuel")
            verify(!row("res").auto)
            verify(shown("res") !== before)
            verify(!row("rateAuto").hidden)                 // en Manuel, le débit automatique revient
            compare(p.fps, chosen.fps)                      // le reste vient du profil
            keyClick(Qt.Key_Escape)
        }

        // Réglages avancés : allumés, les lignes avancées apparaissent en cascade, du haut vers le
        // bas ; éteints, elles s'effacent du bas vers le haut.
        function test_9w_advancedSettingsUnfoldInCascade() {
            home.applyOption("advanced", 0)
            keyClick(Qt.Key_Hangup)
            var sheet = screen.options
            var line = function(key) {
                var found = null
                var walk = function(from) {
                    for (var i = 0; i < from.children.length && !found; i++) {
                        var c = from.children[i]
                        if (c.row !== undefined && c.focused !== undefined && c.row.key === key) found = c
                        else walk(c)
                    }
                }
                walk(sheet)
                return found
            }
            var first = line("res"), last = line("hdr")
            verify(first && last)
            compare(first.opacity, 0)
            goTo("advanced")
            keyClick(Qt.Key_Return)                         // A : allumés
            tryVerify(function() { return first.opacity > 0.5 }, 1000)
            verify(last.opacity < first.opacity, "en cascade : la dernière après la première")
            tryCompare(last, "opacity", 1, 1500)
            keyClick(Qt.Key_Return)                         // éteints
            tryVerify(function() { return last.opacity < 0.5 }, 1000)
            verify(first.opacity > last.opacity, "du bas vers le haut")
            tryCompare(first, "opacity", 0, 1500)
            keyClick(Qt.Key_Escape)
        }

        // Manuel n'est proposé qu'avec les réglages avancés ; les éteindre sous Manuel ramène au
        // profil par défaut.
        function test_9x_manualOnlyWithAdvancedSettings() {
            var row = function() { return fluxRow("streamProfile") }
            var shown = function() { return row().options[row().index] }
            home.applyOption("advanced", 0)
            home.applyOption("streamProfile", 3)            // Économie, la dernière case visible
            compare(row().hiddenOptions, [4])
            keyClick(Qt.Key_Hangup)
            goTo("streamProfile")
            keyClick(Qt.Key_Right)                          // pas de Manuel au bout : la butée
            compare(shown(), "Économie")
            home.applyOption("advanced", 1)
            compare(row().hiddenOptions, [])
            keyClick(Qt.Key_Right)
            compare(shown(), "Manuel")
            home.applyOption("advanced", 0)                 // éteints sous Manuel
            compare(shown(), "Équilibré")
            compare(row().hiddenOptions, [4])
            keyClick(Qt.Key_Escape)
        }

        // Une partie en cours : haut amène la manette aux boutons du héros (Reprendre, Quitter) ;
        // Quitter se tient jusqu'au bout ; bas la rend à l'étagère, la fin de la partie aussi.
        function test_9y_resumeAndQuitButtons() {
            var apps = home.appModel, tile = home.currentTile(), hero = screen.hero
            keyClick(Qt.Key_Up)                             // pas de partie : la barre haute
            verify(!screen.heroFocused && screen.statusBar.activeFocus)
            keyClick(Qt.Key_Down)
            verify(!screen.statusFocused && screen.shelf.activeFocus)
            apps.setProperty(tile.appIndex, "running", true)
            apps.runningName = tile.name
            verify(screen.running)
            keyClick(Qt.Key_Up)
            verify(screen.heroFocused && hero.activeFocus)
            compare(hero.selected, 0)                       // Reprendre d'abord
            keyClick(Qt.Key_Right)
            compare(hero.selected, 1)
            var quits = apps.quits
            keyClick(Qt.Key_Return)                         // appui bref : rien
            compare(apps.quits, quits)
            holdA()
            compare(apps.quits, quits + 1)
            keyClick(Qt.Key_Down)                           // la manette revient à l'étagère
            verify(!screen.heroFocused)
            keyClick(Qt.Key_Up)
            verify(screen.heroFocused)
            apps.setProperty(tile.appIndex, "running", false)   // la partie s'arrête
            verify(!screen.heroFocused)
            keyClick(Qt.Key_Right)                          // l'étagère a bien la manette
            compare(screen.currentIndex, 1)
            apps.runningName = ""
        }

        // Barre haute : haut depuis l'étagère (ou le héros) donne la manette à ses icônes
        // (Wi-Fi, batterie, réglages) ; l'icône choisie ouvre sa fiche, A agit : réglages →
        // options sur l'onglet Console, Wi-Fi → liste des réseaux ; bas ou B la rendent.
        function test_9y_statusBarIcons() {
            var bar = screen.statusBar
            keyClick(Qt.Key_Up)
            verify(bar.activeFocus)
            compare(bar.selected, "settings")
            compare(bar.cardKey, "settings")
            keyClick(Qt.Key_Right)                          // déjà au bout
            compare(bar.selected, "settings")
            keyClick(Qt.Key_Return)
            verify(screen.options.opened)
            compare(screen.options.tab, 1)                  // Console
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return bar.activeFocus }) // la manette revient à la barre
            keyClick(Qt.Key_Left)
            compare(bar.cardKey, "battery")
            keyClick(Qt.Key_Return)                         // la batterie n'a rien à faire
            verify(!screen.options.opened && !screen.panelOpen)
            keyClick(Qt.Key_Left)
            compare(bar.cardKey, "wifi")
            var scans = WifiSetup.scans
            keyClick(Qt.Key_Return)                         // la liste des réseaux
            compare(WifiSetup.scans, scans + 1)
            verify(screen.panelOpen)
            compare(bar.cardKey, "")                        // fiches masquées sous un panneau
            keyClick(Qt.Key_Escape)
            tryVerify(function() { return !screen.panelOpen && bar.activeFocus })
            keyClick(Qt.Key_Escape)                         // B rend la manette à l'étagère
            verify(screen.shelf.activeFocus)
            compare(bar.cardKey, "")
        }

        // En dernier : l'hôte du faux modèle est supprimé.
        function test_9z_forgettingThePcForgetsTheCompanionToo() {
            var forgets = CompanionClient.forgets
            keyClick(Qt.Key_Hangup)
            for (var i = 0; i < screen.optionRows.length; i++) keyClick(Qt.Key_Down)   // jusqu'à « Oublier ce PC »
            holdA()
            compare(CompanionClient.forgets, forgets + 1)
            compare(home.computerModel.count, 0)
        }
    }
}
