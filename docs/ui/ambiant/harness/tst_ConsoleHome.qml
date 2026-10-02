import QtQuick
import QtTest
import StreamingPreferences 1.0
import CompanionClient 1.0
import ComputerManager 1.0
import SystemStatus 1.0
import InputStatus 1.0
import WifiSetup 1.0
import "../../../../app/gui/console"
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

        function test_3_optionsWriteMoonlightPreferences() {
            var p = StreamingPreferences
            p.width = 1920; p.height = 1080; p.fps = 60
            p.autoAdjustBitrate = true; p.bitrateKbps = 30000    // profil du premier démarrage
            home.refreshOptions()
            var rows = function() { return screen.optionRows }
            var shown = function(i) { return rows()[i].options[rows()[i].index] }

            keyClick(Qt.Key_Hangup)                 // bouton Y
            verify(screen.options.opened)
            compare(rows()[0].label, "Minecraft")   // en tête : les réglages du jeu sélectionné
            compare(shown(0), "Réglages communs")
            compare(shown(1), "1080p")
            compare(shown(3), "30 Mb/s")            // 30 Mb/s n'est pas la valeur automatique : affiché tel quel

            keyClick(Qt.Key_Down)
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
            for (var i = 0; i < 4 && shown(3) !== "Auto"; i++) keyClick(Qt.Key_Left)
            compare(shown(3), "Auto")
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
            verify(!screen.entryAllowed)
            session.sessionFinished(0)              // fin du jeu : l'accueil revient
            verify(!screen.launching)
            verify(!screen.pressed)
            home.returnedHome()                     // (StreamSegue dépilé)
            verify(!curtain.covering)               // fin sans action du menu en jeu : il se lève
            verify(!curtain.revealed)
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
            compare(row.label, "Sons")
            compare(row.options[row.index], "Activés")
            keyClick(Qt.Key_Right)
            compare(screen.optionRows[4].index, 1)          // « Coupés »
            verify(!Sounds.enabled)
            keyClick(Qt.Key_Left)
            compare(screen.optionRows[4].index, 0)
            verify(Sounds.enabled)
            Sounds.enabled = false
            keyClick(Qt.Key_Escape)
        }

        // Onglet Console : luminosité, volume, veille de l'écran, boutons. L1 / R1
        // (InputStatus) changent d'onglet.
        function test_9c_consoleSettings() {
            keyClick(Qt.Key_Hangup)
            InputStatus.bumperPressed(1)
            compare(screen.optionRows.map(function(r) { return r.label }),
                    ["Luminosité", "Volume", "Veille de l'écran", "Boutons", "Sons", "Wi-Fi"])
            keyClick(Qt.Key_Right)                          // luminosité 60 → 70 %
            compare(SystemStatus.brightness, 70)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Left)    // volume 80 → 70 % (le stub part de 75)
            verify(SystemStatus.volume === 70 || SystemStatus.volume === 60)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)   // veille : 5 → 10 min
            compare(screen.optionRows[2].options[screen.optionRows[2].index], "10 min")
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)   // Boutons : PlayStation
            compare(Theme.buttonLayout, "playstation")
            keyClick(Qt.Key_Left); keyClick(Qt.Key_Left)    // Auto : sans manette, Xbox
            compare(Theme.buttonLayout, "xbox")
            InputStatus.bumperPressed(-1)                   // retour à l'onglet Flux
            compare(screen.optionRows[1].label, "Résolution")
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
            compare(SystemStatus.lastPower, "poweroff")
            InputStatus.homePressed(); verify(dialog("Menu"))
            InputStatus.homePressed(); verify(!dialog("Menu"))   // Home referme le menu
            keyClick(Qt.Key_Right)
            compare(screen.currentIndex, 1)               // la manette est revenue à l'étagère
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

        // Réglages à part pour un jeu : ils ne touchent pas aux réglages communs, et ne
        // remplacent ceux-ci que le temps de sa session.
        function test_9m_gameWithItsOwnStreamSettings() {
            var p = StreamingPreferences
            p.fps = 60
            var name = screen.title
            keyClick(Qt.Key_Hangup)
            compare(screen.optionRows[0].label, name)
            keyClick(Qt.Key_Right)                          // « Réglages à part »
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Down); keyClick(Qt.Key_Right)   // 60 → 90 images par seconde
            compare(screen.optionRows[2].options[screen.optionRows[2].index], "90")
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
            keyClick(Qt.Key_Left)
            compare(screen.optionRows[2].options[screen.optionRows[2].index], "60")
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
