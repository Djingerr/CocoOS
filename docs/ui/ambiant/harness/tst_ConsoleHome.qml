import QtQuick
import QtTest
import StreamingPreferences 1.0
import CompanionClient 1.0
import "../../../../app/gui/console"

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

        function initTestCase() {
            Sounds.enabled = false
            verify(screen && launchScreen && updateDialog)
        }
        function init() {
            CompanionClient.paired = false
            CompanionClient.eventsConnected = false
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

        function test_3_optionsWriteMoonlightPreferences() {
            var p = StreamingPreferences
            p.width = 1920; p.height = 1080; p.fps = 60
            p.autoAdjustBitrate = true; p.bitrateKbps = 30000    // profil du premier démarrage
            home.refreshOptions()
            var rows = function() { return screen.optionRows }
            var shown = function(i) { return rows()[i].options[rows()[i].index] }

            keyClick(Qt.Key_Hangup)                 // bouton Y
            verify(screen.options.opened)
            compare(shown(0), "1080p")
            compare(shown(2), "30 Mb/s")            // 30 Mb/s n'est pas la valeur automatique : affiché tel quel

            keyClick(Qt.Key_Left)                   // résolution précédente (celle de l'écran, ou 720p)
            verify(p.width !== 1920 || p.height !== 1080)
            compare(p.bitrateKbps, 30000)           // débit fixe : inchangé
            keyClick(Qt.Key_Right)
            compare(p.width, 1920)
            compare(screen.currentIndex, 0)         // les flèches ne touchent pas à la liste des jeux

            keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)       // images par seconde : 60 → 90
            compare(p.fps, 90)
            keyClick(Qt.Key_Left)
            compare(p.fps, 60)

            keyClick(Qt.Key_Down)                   // débit : gauche jusqu'à « Auto »
            for (var i = 0; i < 4 && shown(2) !== "Auto"; i++) keyClick(Qt.Key_Left)
            compare(shown(2), "Auto")
            verify(p.autoAdjustBitrate)
            compare(p.bitrateKbps, p.getDefaultBitrate(1920, 1080, 60, false))
            keyClick(Qt.Key_Up); keyClick(Qt.Key_Right)         // 90 images par seconde : le débit automatique suit
            compare(p.bitrateKbps, p.getDefaultBitrate(1920, 1080, 90, false))
            keyClick(Qt.Key_Left)

            keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)   // codec : A passe au suivant
            compare(p.videoCodecConfig, p.VCC_FORCE_H264)
            keyClick(Qt.Key_Left)
            compare(p.videoCodecConfig, p.VCC_AUTO)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)      // HDR
            verify(p.enableHdr)
            keyClick(Qt.Key_Return)
            verify(!p.enableHdr)
            verify(p.saves > 0)

            keyClick(Qt.Key_Escape)                 // bouton B
            verify(!screen.options.opened)
            keyClick(Qt.Key_Right)                  // le focus est revenu à l'étagère
            compare(screen.currentIndex, 1)
        }

        function test_4_forgettingThePcAsksTwice() {
            keyClick(Qt.Key_Hangup)
            for (var i = 0; i < 6; i++) keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Return)
            verify(screen.options.confirming)
            compare(home.computerModel.count, 1)    // rien n'est supprimé à la première pression
            keyClick(Qt.Key_Up)                     // s'éloigner annule
            verify(!screen.options.confirming)
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

            session.connectionStarted()             // le flux est à l'écran
            verify(!launchScreen.active)
            session.sessionFinished(0)              // fin du jeu : l'accueil revient
            verify(!screen.launching)
            verify(!screen.pressed)
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

        function test_9b_soundsSetting() {
            keyClick(Qt.Key_Hangup)
            for (var i = 0; i < 5; i++) keyClick(Qt.Key_Down)
            var row = screen.optionRows[5]
            compare(row.label, "Sons")
            compare(row.options[row.index], "Activés")
            keyClick(Qt.Key_Right)
            compare(screen.optionRows[5].index, 1)          // « Coupés »
            verify(!Sounds.enabled)
            keyClick(Qt.Key_Left)
            compare(screen.optionRows[5].index, 0)
            verify(Sounds.enabled)
            Sounds.enabled = false
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

        // Les utilitaires d'Apollo (ici « Desktop ») ne sont pas sur l'étagère.
        function test_9f_utilitiesAreNotOnTheShelf() {
            compare(home.appModel.count, 11)
            compare(screen.count, 10)
            for (var i = 0; i < 10; i++) {
                screen.currentIndex = i
                verify(screen.title !== "Desktop")
            }
        }

        // En dernier : l'hôte du faux modèle est supprimé.
        function test_9z_forgettingThePcForgetsTheCompanionToo() {
            var forgets = CompanionClient.forgets
            keyClick(Qt.Key_Hangup)
            for (var i = 0; i < 6; i++) keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Return); keyClick(Qt.Key_Return)
            compare(CompanionClient.forgets, forgets + 1)
            compare(home.computerModel.count, 0)
        }
    }
}
