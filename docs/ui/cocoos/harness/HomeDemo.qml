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

    ListModel { id: games }
    function fill() {
        Library.sync(games, items.map(function(g) {
            return { name: g.name, boxart: "", cover: g.cover || "", publisher: Format.publisher(g), favorite: !!g.favorite }
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
    backdrop: game && game.background ? game.background : ""

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
}
