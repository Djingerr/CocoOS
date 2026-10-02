import QtQuick
import QtTest
import "../../../../app/gui/console/BootTimeline.js" as Boot

// BootTimeline.js contre le prototype : `ref` est produit par
// docs/boot-animation/reference-values.js, qui évalue le JavaScript de
// prototype.html lui-même. Plus les points de contrôle de BOOT_ANIMATION.md §11.
TestCase {
    name: "BootTimeline"

    readonly property var ref: {"easings":{"E_OUT":[0.2720924690196416,0.6554731021763147,0.8722018601010123,0.9914041378210551],"E_INOUT":[0.008942470518593213,0.1123862466211207,0.49999964237213135,0.9584646328423947],"E_EMPH":[0.15624973177918378,0.6880670355615273,0.8778335367325447,0.9848621249043839],"E_DRAW":[0.007861784628557536,0.10806874666542633,0.6357690975522916,0.9731005717863578],"E_STD":[0.025863113239237116,0.3672957225648559,0.7755613193532701,0.9752675124746406]},"springs":[[300,620,0.9,0.8544323368682119],[300,520,0.78,0.9814888024649365],[700,520,0.78,1.000673486016979]],"instants":{"release":1230,"revealEnd":1985,"normalE":2385,"loaderShowAt":2785},"exitStart":[["fast",2385,2385],[1000,3385,4285],[4000,6385,7285]],"spinner":[[0,{"tail":0,"head":0.78}],[500,{"tail":1.0384550878861687,"head":1.098877551020408}],[2000,{"tail":2.7755102040816326,"head":2.8055110850089644}]],"loader":[[3000,{"vis":0.8983823431752533,"tail":0.37998850908104276,"len":0.5371288378577328,"bump":0}],[4000,{"vis":1,"tail":1.524872448979592,"len":0.7657791849311542,"bump":0}],[6645,{"vis":0.1277981398989877,"tail":4.711734693877551,"len":0.9706386974075194,"bump":0}],[7085,{"vis":0,"tail":5.5224838073451155,"len":1,"bump":0.45009509493129163}]]}

    function near(actual, expected, tolerance, what) {
        verify(Math.abs(actual - expected) <= tolerance, what + " : " + actual + " au lieu de " + expected)
    }

    function test_easingsAndSpringsMatchThePrototype() {
        var x = [0.1, 0.3, 0.5, 0.8]
        for (var name in ref.easings)
            for (var i = 0; i < x.length; i++)
                near(Boot[name](x[i]), ref.easings[name][i], 1e-9, name + "(" + x[i] + ")")
        ref.springs.forEach(function(s) {
            near(Boot.spring(s[0], s[1], s[2]), s[3], 1e-9, "spring(" + s.slice(0, 3) + ")")
        })
    }

    function test_instants() {
        compare(Boot.release, ref.instants.release)
        compare(Boot.revealEnd, ref.instants.revealEnd)
        compare(Boot.normalE, ref.instants.normalE)
        compare(Boot.loaderShowAt, ref.instants.loaderShowAt)
    }

    // Prêt d'emblée, 1000 ms ou 4000 ms après normalE : la sortie commence au même
    // instant que dans le prototype (chargeur affiché au moins 600 ms).
    function test_exitStartFollowsReadiness() {
        ref.exitStart.forEach(function(e) {
            var r = e[0] === "fast" ? 0 : e[1]
            compare(Boot.exitStart(r), e[2], "prêt à " + r)
        })
        verify(!isFinite(Boot.exitStart(null)))
        verify(!Boot.loaderShown(300))                 // prêt vite : pas de chargeur
        verify(Boot.loaderShown(4000))
        verify(Boot.completeAt(2800) - Boot.loaderShowAt >= Boot.T.loaderMin)
    }

    function test_spinnerAndLoaderMatchThePrototype() {
        ref.spinner.forEach(function(s) {
            var sp = Boot.spinner(s[0])
            near(sp.tail, s[1].tail, 1e-9, "spinner(" + s[0] + ").tail")
            near(sp.head, s[1].head, 1e-9, "spinner(" + s[0] + ").head")
        })
        var r = ref.exitStart[2][1]                    // prêt 4000 ms après normalE
        ref.loader.forEach(function(l) {
            var st = Boot.loader(l[0], r)
            near(st.vis, l[1].vis, 1e-9, "vis à " + l[0])
            near(st.len, l[1].len, 1e-9, "len à " + l[0])
            near(st.bump, l[1].bump, 1e-9, "bump à " + l[0])
            near(st.a0, -Math.PI / 2 + 2 * Math.PI * (l[1].tail - 0.78), 1e-9, "a0 à " + l[0])
        })
    }

    // BOOT_ANIMATION.md §11.2 (boot rapide).
    function test_controlPoints() {
        near(Boot.draw(500).len, 0.15, 0.04, "O tracé à 500 ms")
        near(Boot.draw(600).len, 0.5, 0.12, "O tracé à 600 ms")
        compare(Boot.draw(1000).len, 1)
        compare(Boot.oColor(1000), Boot.BRIGHT)        // complet, plus clair
        verify(Boot.oState(1200, 0, 0).s < Boot.T.oScale, "O comprimé à 1200 ms")
        for (var i = 0; i < 2; i++) {                  // « C » et « o » sortis à 1400 ms :
            var l = Boot.letter(1400, i, 0, 100, 40)    // plus de 30 % du trajet (de -20 à 100)
            verify(l.shown && l.x > -20 + 0.3 * 120, "lettre " + i + " à 1400 ms : " + l.x)
        }
        compare(Boot.exitStart(0), 2385)
        compare(Boot.exitStart(0) + Boot.T.exitDur, 3135)
    }
}
