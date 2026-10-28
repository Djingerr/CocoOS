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
//   time      heure affichée (21:42 par défaut)
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

    title: game ? game.name : ""
    meta: !game ? [] : category === "recent" && game.lastPlayed
          ? [Format.lastPlayed(game.lastPlayed, new Date("2026-10-28T21:42:00")), Format.playtime(game.playtimeSeconds)].filter(Boolean)
          : Format.meta(game)
    pegi: game ? Format.pegi(game.ageRatings) : ""
    playLabel: game && Library.isUtility(game.name) ? "Ouvrir" : ""
    backdrop: game && game.background && backdropArrived ? game.background : ""

    hostName: "PC-Salon"
    connected: true
    latencyMs: 4
    signalStrength: 4
    batteryPercent: 82
    batteryDetails: ({ minutes: 190, watts: 6.8, status: "Discharging" })
    wifi: ({ ssid: "Livebox-7A3C", strength: 86, secured: true })
    timeText: args.time || "21:42"
    optionsHost: "PC-Salon"
    optionTabs: [{ label: "Stream", rows: [] }, { label: "Console", rows: [] }]

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
