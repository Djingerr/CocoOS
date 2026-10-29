import QtQuick
import "../../../../app/gui/console"
import "../../../../app/gui/console/Format.js" as Format
import "../../../../app/gui/console/Library.js" as Library
import "Mock.js" as Mock

// L'accueil CocoOS (HomeScreen) sur les données du mock (../mock/library.mock.json), sans
// ConsoleHome ni backend Moonlight : flèches pour parcourir (maintenir : rapide), Page préc. /
// suiv. pour les catégories, Maj + ← / → pour le saut de lettre (avec big=1), X pour épingler.
//
//   ./shot.sh /tmp/a.png view=HomeDemo                     (AccueilCarrousel : Minecraft au centre)
//   ./shot.sh /tmp/a.png view=HomeDemo category=favorites favorites=0   (EtatFavorisVide)
//
// Arguments :
//   order     ids du mock dans l'ordre du carrousel (par défaut celui des maquettes :
//             ha,ce,hk,mc,fh,sv,er), ou « all » pour les dix
//   focus     index du jeu au centre (3 : Minecraft)
//   category  all | favorites | recent | apps
//   favorites 0 : aucun favori
//   big       1 : 214 jeux de A à Z (saut de lettre)
//   do        actions jouées à `at` ms, espacées de 150 ms : left, right, holdright (maintenue
//             jusqu'à `release`), release, lb, rb, jump, jumpback, x
//   at        instant de `do` (300 ms par défaut)
//   script    actions à des instants absolus, « t:action » séparés par des virgules (le
//             minutage des renderVals des maquettes) ; actions : right, left, fastright,
//             fastleft (pas rapide, flèche maintenue), release, rb, lb, jump, jumpback
//   start     décalage du script, en ms (laisser l'accueil finir son entrée)
//   loading   1 : jaquettes et fond arrivent comme dans MotionJaquettes (squelettes d'abord)
//   fiche     1 : la fiche du jeu au centre ouverte d'entrée (FicheEditoriale)
// Actions (script) en plus : down (la fiche), up (la referme), x (favori), y / b (la feuille
// d'options), key-down, key-up, key-left, key-right, key-a, key-lb, key-rb (dans la feuille).
// Lancement (MotionLancement) : press (A enfoncé), launch (A relâché : l'écran s'ouvre ;
// wake=0 sans « Réveil de … »), step (état suivant), full (anneau plein), stream (le flux prend
// l'écran : le rideau). Retour (MotionQuitter) : ingame (le rideau, image du jeu, comme au
// retour d'un flux), back (il se lève). Échec (MotionEchec) : reach (l'écran ouvert sur
// « Connexion à PC-Salon… »), fail, retry.
//   time      heure affichée (21:42 par défaut)
//   picker    1 : le choix du PC ouvert, PC-Bureau sous la manette (ChoixPC)
//   idlein, idleout (actions) : l'écran de veille (son fond), puis la sortie (MotionReveil)
//   shutdown, sleep, wake (actions) : extinction (MotionExtinction), mise en veille et réveil
//             (MotionVeille)
//   power     1 : le menu d'alimentation (MenuAlimentation) ; powerFocus=0..2 ; action hold
//             (la touche power tenue : la pastille se remplit puis le menu)
//   pc        asleep | offline | waking : état du PC (MotionReveilPC, EtatHorsLigne) ; actions
//             asleep, offline, waking, woke (« … est en ligne », puis connecté)
HomeScreen {
    id: demo

    property var args: ({})
    readonly property var mock: Mock.load(Qt.resolvedUrl("../mock/library.mock.json"))
    readonly property var library: Mock.games(mock, Qt.resolvedUrl("art/"))
    readonly property var picked: {
        var ids = (args.order || "ha,ce,hk,mc,fh,sv,er").split(",")
        var list = args.order === "all" ? library
                 : ids.map(function(id) { return library.filter(function(g) { return g.id === id })[0] })
        list = list.concat([{ id: "desk", name: "Desktop" }, { id: "vd", name: "Virtual Display" }])
        if (args.favorites === "0") list.forEach(function(g) { g.favorite = false })
        return args.big === "1" ? Mock.expand(list, 214) : list
    }
    readonly property var categories: ["all", "favorites", "recent", "apps"]
    property string category: args.category || "all"
    readonly property var items: Library.collection(picked, category, function(name) {
        var g = picked.filter(function(x) { return x.name === name })[0]
        return g && g.lastPlayed ? Date.parse(g.lastPlayed) : 0
    })
    readonly property var game: currentIndex < items.length ? items[currentIndex] : null
    // MotionJaquettes : instant d'arrivée de chaque jaquette (ms), le fond à 1300.
    readonly property var arrivals: ({ ha: 2600, ce: 2150, hk: 1600, mc: 1200, fh: 1750, sv: 2000, er: 2400 })
    property var arrived: ({})
    property bool backdropArrived: args.loading !== "1"
    function cover(g) {
        return args.loading === "1" && !arrived[g.id] ? Qt.resolvedUrl("art/pas-encore-" + g.id + ".png") : (g.cover || "")
    }

    ListModel { id: games }
    function fill() {
        Library.sync(games, items.map(function(g) {
            return { name: g.name, boxart: "", cover: cover(g), publisher: Format.publisher(g), favorite: !!g.favorite }
        }))
    }
    onItemsChanged: fill()

    focus: true
    model: games
    ready: true
    favoritesEmpty: category === "favorites" && items.length === 0
    driftAllowed: false
    collectionLabels: ["Tout", "Favoris", "Récents", "Apps"]
    collectionIndex: categories.indexOf(category)
    onCollectionRequested: function(direction) { demo.switchCategory(direction) }
    onRecentRequested: switchCategory(2 - collectionIndex)
    onDetailsRequested: fiche.open()
    detailOpen: fiche.shown
    onFavoriteRequested: toggleFavorite()
    favorite: !!(game && game.favorite)

    function toggleFavorite() {
        if (!game) return
        game.favorite = !game.favorite
        fill()
        favoriteFeedback(game.favorite)
    }

    GamePage {
        id: fiche
        parent: demo.detailStage
        readonly property var info: demo.game || ({})
        title: demo.title
        label: Format.publisher(info)
        meta: Format.ficheMeta(info)
        tags: demo.pegi !== "" ? [demo.pegi] : []
        // (Le mock n'a pas de description : celle de la maquette pour Minecraft.)
        description: info.id === "mc" ? "Explorez des mondes générés à l'infini, récoltez des ressources et construisez tout ce que vous imaginez. Survivez la nuit face aux créatures, ou laissez libre cours à votre créativité, seul ou entre amis."
                                      : Format.plainText(info.description || "")
        stats: Format.ficheStats(info, "")
        details: Format.ficheDetails(info, Qt.locale("fr_FR"), new Date("2026-10-28T21:42:00"))
        favorite: demo.favorite
        banner: demo.favoriteBanner
        onFavoriteRequested: demo.toggleFavorite()
        onOptionsRequested: demo.options.open()
    }

    title: game ? game.name : ""
    meta: !game ? [] : category === "recent" && game.lastPlayed
          ? [Format.lastPlayed(game.lastPlayed, new Date("2026-10-28T21:42:00")), Format.playtime(game.playtimeSeconds)].filter(Boolean)
          : Format.meta(game)
    pegi: game ? Format.pegi(game.ageRatings) : ""
    playLabel: game && Library.isUtility(game.name) ? "Ouvrir" : ""
    backdrop: game && game.background && backdropArrived ? game.background : ""

    // --- Lancement, échec et retour d'un jeu ---
    launching: launchScreen.covering || curtain.covering || shutdown.active || demo.napping && demo.dozed || demo.idling
    property bool idling: false
    // (l'écran de veille, réduit à son fond noir : idlein / idleout, MotionReveil)
    Rectangle {
        anchors.fill: parent; z: 8; color: "black"
        opacity: demo.idling ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 380 } }
    }
    property bool dozed: false
    LaunchScreen {
        id: launchScreen
        anchors.fill: parent
        z: 10
        title: demo.title
        canWake: true
        onCancelRequested: { close(true); demo.pressed = false; demo.shelf.forceActiveFocus() }
        onRetryRequested: demo.act("retry")
    }
    StreamCurtain {
        id: curtain
        anchors.fill: parent
        z: 11
        title: demo.title
    }
    function placeLaunch(fromCover) {
        launchScreen.image = game.background || ""
        launchScreen.thumbnail = game.cover || ""
        launchScreen.origin = fromCover ? activeThumbRect : Qt.rect(0, 0, 0, 0)
        curtain.image = launchScreen.image
        curtain.thumbnail = launchScreen.thumbnail
        curtain.origin = activeThumbRect
    }
    Timer { id: launchOpen; interval: Theme.launchPress; onTriggered: launchScreen.open() }

    // Choix du PC (ChoixPC), avec les PC de la maquette.
    HostPicker {
        id: picker
        anchors.fill: parent
        z: 9
        hosts: [ { name: "PC-Salon", state: "connected", detail: "Connecté · 4 ms · 214 jeux", current: true },
                 { name: "PC-Bureau", state: "asleep", detail: "En veille · 38 jeux" },
                 { name: "Portable-Gaming", state: "missing", detail: "Introuvable sur ce réseau" } ]
        onClosed: { demo.statusBar.hostRing = false; demo.shelf.forceActiveFocus() }
        onChosen: close()
    }
    ShutdownScreen {
        id: shutdown
        anchors.fill: parent
        z: 12
    }
    Timer { id: doze; interval: Theme.sleepFade; onTriggered: demo.dozed = true }
    PowerMenu {
        id: powerMenu
        anchors.fill: parent
        z: 9
        actions: ["suspend", "reboot", "poweroff"]
        header: "Batterie 82 % · environ 3 h 10"
        onClosed: demo.shelf.forceActiveFocus()
    }
    function openPicker() { statusBar.hostRing = true; picker.open(1) }
    menuShown: picker.opened || powerMenu.opened

    property string pc: args.pc || ""
    hostName: "PC-Salon"
    connected: pc === "" || pc === "online"
    hostState: pc
    hostOffline: pc === "offline"
    waking: pc === "waking"
    Timer { id: woke; interval: Theme.hostOnlineShow; onTriggered: demo.pc = "" }
    latencyMs: 4
    signalStrength: 4
    batteryPercent: 82
    batteryDetails: ({ minutes: 190, watts: 6.8, status: "Discharging" })
    wifi: ({ ssid: "Livebox-7A3C", strength: 86, secured: true })
    timeText: args.time || "21:42"
    optionsSubtitle: "PC-Salon · connecté · 4 ms"
    // La feuille d'options des maquettes (OptionsFeuille, MotionOptions) ; les choix s'appliquent ici.
    property var opt: ({ profile: 2, advanced: 1, res: 0, fps: 1, rate: 10, codec: 0, brightness: 100, volume: 40,
                         sleep: 0, sounds: 1, motion: 0, language: 0 })
    onOptionChanged: function(key, value) {
        var next = Object.assign({}, opt)
        next[key] = value
        opt = next
    }
    optionTabs: {
        var o = opt, adv = function(r) { r.advanced = true; r.group = "advanced"; return r }
        return [
            { label: "Stream", rows: [
                { key: "profile", label: "Profil", segments: true, group: "profile", section: "Profil de stream",
                  options: ["Compétitif", "Équilibré", "Qualité", "Éco", "Manuel"], index: o.profile,
                  footnote: "Réseau faible : le profil descend automatiquement de deux crans.",
                  description: "La plus belle image, quand le réseau suit.",
                  stats: [{ label: "Résolution", value: ["720p", "1080p"][o.res] }, { label: "Images/s", value: ["30", "60", "90", "120"][o.fps] },
                          { label: "Débit", value: o.rate + " Mb/s" }, { label: "Priorité", value: "Image" }] },
                { key: "advanced", label: "Réglages avancés", toggle: true, revealsAdvanced: true, group: "advanced",
                  section: "Avancé", options: ["Désactivés", "Activés"], index: o.advanced },
                adv({ key: "res", label: "Résolution", options: ["720p", "1080p"], index: o.res }),
                adv({ key: "fps", label: "Images par seconde", options: ["30", "60", "90", "120"], index: o.fps }),
                adv({ key: "rate", label: "Débit", slider: true, value: o.rate, min: 5, max: 150, stops: [10, 20, 40, 80], format: "%1 Mb/s" }),
                adv({ key: "codec", label: "Codec", options: ["Auto", "H.264", "HEVC", "AV1"], index: o.codec }),
                { key: "forget", label: "Oublier ce PC", hold: true, doneLabel: "PC oublié", group: "pc" } ] },
            { label: "Console", rows: [
                { key: "brightness", label: "Luminosité", slider: true, value: o.brightness, min: 5, max: 100, stops: [25, 50, 75],
                  format: "%1 %", group: "screen", section: "Écran et son" },
                { key: "volume", label: "Volume", slider: true, value: o.volume, min: 0, max: 100, stops: [25, 50, 75],
                  format: "%1 %", group: "screen" },
                { key: "sleep", label: "Veille après", options: ["30 s", "1 min", "2 min", "5 min"], index: o.sleep,
                  group: "console", section: "Console" },
                { key: "sounds", label: "Sons", toggle: true, options: ["Coupés", "Activés"], index: o.sounds, group: "console" },
                { key: "motion", label: "Réduire les animations", toggle: true, options: ["Non", "Oui"], index: o.motion, group: "console" },
                { key: "language", label: "Langue", options: ["Français", "English"], index: o.language, group: "console" } ] } ]
    }

    function switchCategory(direction) {
        var next = collectionIndex + direction
        if (next < 0 || next >= categories.length) {
            Sounds.play("edge")
            return
        }
        categoryStart(direction)
        Sounds.play(direction > 0 ? "category_next" : "category_prev")
        category = categories[next]
        currentIndex = 0
        shelf.slideIn(direction)
    }

    Component.onCompleted: {
        fill()
        currentIndex = Number(args.focus !== undefined ? args.focus : 3)
        Sounds.enabled = args.out === undefined && args.sound !== "0"
        if (args.do) actions.start()
        if (args.fiche === "1") fiche.open()
        if (args.picker === "1") openPicker()
        if (args.power === "1") { powerMenu.open(); powerMenu.current = Number(args.powerFocus || 1) }
        var start = Number(args.start || 0)
        var steps = args.script ? args.script.split(",").map(function(x) {
            var p = x.split(":"); return { t: start + Number(p[0]), action: p[1] } }) : []
        if (args.loading === "1") {
            Object.keys(arrivals).forEach(function(id) { steps.push({ t: start + arrivals[id], action: "arrive:" + id }) })
            steps.push({ t: start + 1300, action: "backdrop" })
            steps.push({ t: start + 1350, action: "ready" })
        }
        timeline.steps = steps.sort(function(a, b) { return a.t - b.t })
        // L'horloge part avec celle de la capture du harnais (une fois la fenêtre créée).
        Qt.callLater(function() { timeline.t0 = Date.now(); timeline.next() })
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Y) options.open()
    }

    // Actions scriptées (captures de transitions).
    Timer {
        id: actions
        property var steps: (demo.args.do || "").split(",")
        property int i: 0
        interval: Number(demo.args.at || 300)
        onTriggered: {
            var s = steps[i++]
            if (s === "left") demo.shelf.move(-1)
            else if (s === "right") demo.shelf.move(1)
            else if (s === "holdright") { demo.shelf.fast = true; holdTimer.start(); demo.shelf.move(1) }
            else if (s === "release") { holdTimer.stop(); demo.shelf.fast = false }
            else if (s === "rb") demo.switchCategory(1)
            else if (s === "lb") demo.switchCategory(-1)
            else if (s === "jump") demo.shelf.jump(1)
            else if (s === "jumpback") demo.shelf.jump(-1)
            if (i < steps.length) { interval = 150; restart() }
        }
    }
    Timer { id: holdTimer; interval: Theme.navFastStep; repeat: true; onTriggered: demo.shelf.move(1) }

    // Minutage absolu (`script`, `loading`).
    function act(action) {
        if (action === "right" || action === "left") { shelf.fast = false; shelf.move(action === "right" ? 1 : -1) }
        else if (action === "fastright" || action === "fastleft") { shelf.fast = true; shelf.move(action === "fastright" ? 1 : -1) }
        else if (action === "release") shelf.fast = false
        else if (action === "rb") switchCategory(1)
        else if (action === "lb") switchCategory(-1)
        else if (action === "jump") shelf.jump(1)
        else if (action === "jumpback") shelf.jump(-1)
        else if (action === "down") fiche.open()
        else if (action === "up") fiche.close()
        else if (action === "x") toggleFavorite()
        else if (action === "y") options.open()
        else if (action === "b") options.close()
        else if (action.indexOf("key-") === 0) {       // touches de la feuille : key-down, key-rb, key-a…
            var keys = { down: Qt.Key_Down, up: Qt.Key_Up, left: Qt.Key_Left, right: Qt.Key_Right,
                         rb: Qt.Key_PageDown, lb: Qt.Key_PageUp }
            var k = action.slice(4)
            if (k === "a") { options.list.pressing = true; options.list.pressing = false; options.list.activate() }
            else if (k === "rb" || k === "lb") options.switchTab(k === "rb" ? 1 : -1)
            else if (k === "down" || k === "up") options.list.step(k === "down" ? 1 : -1)
            else options.list.change(k === "right" ? 1 : -1, false)
        }
        else if (action === "asleep" || action === "offline" || action === "waking") pc = action
        else if (action === "woke") { pc = "online"; woke.start(); Sounds.play("host_online") }
        else if (action === "hold") powerMenu.startHold()
        else if (action === "shutdown") {
            leaveStyle = "collapse"
            shutdown.origin = activeThumbRect
            shutdown.cover = game.cover || ""
            shutdown.start()
        }
        else if (action === "sleep") { napping = true; doze.start() }
        else if (action === "idlein") { returnStyle = "idle"; idling = true }
        else if (action === "idleout") idling = false
        else if (action === "wake") { returnStyle = "wake"; napping = false; dozed = false }
        else if (action === "press") { pressed = true; Sounds.play("launch") }
        else if (action === "launch") {
            placeLaunch(true)
            launchScreen.steps = (args.wake === "0" ? [] : ["Réveil de PC-Salon…"])
                .concat(["Lancement de " + game.name + "…", "Connexion au flux vidéo…"])
            launchScreen.step = 0
            launchOpen.start()
        }
        else if (action === "step") launchScreen.step++
        else if (action === "full") { launchScreen.complete(); Sounds.play("ready") }
        else if (action === "stream") { curtain.cover(); launchScreen.close(false); pressed = false }
        else if (action === "ingame") { placeLaunch(true); curtain.cover(); curtain.reveal("") }
        else if (action === "back") curtain.dismiss()
        else if (action === "reach") {
            placeLaunch(false)
            launchScreen.steps = ["Connexion à PC-Salon…", "Nouvelle tentative…"]
            launchScreen.step = 0
            launchScreen.open()
        }
        else if (action === "fail") {
            launchScreen.errorTitle = "PC-Salon ne répond pas"
            launchScreen.error = "Vérifiez que le PC est allumé et relié au même réseau,\nou réveillez-le à distance."
        }
        else if (action === "retry") { launchScreen.error = ""; launchScreen.step = 0 }
        else if (action === "backdrop") backdropArrived = true
        else if (action === "ready") Sounds.play("library_ready")
        else if (action.indexOf("arrive:") === 0) {
            var next = Object.assign({}, arrived)
            next[action.slice(7)] = true
            arrived = next
            fill()
        }
    }
    Timer {
        id: timeline
        property var steps: []
        property int i: 0
        property double t0: Date.now()
        function next() {
            if (i >= steps.length) return
            interval = Math.max(0, t0 + steps[i].t - Date.now())
            restart()
        }
        onTriggered: {
            while (i < steps.length && t0 + steps[i].t <= Date.now() + 1)
                demo.act(steps[i++].action)
            next()
        }
    }
}
