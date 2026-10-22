import QtQuick
import QtTest
import "../../../../app/gui/console"
import "../../../../app/gui/console/Spring.js" as Spring

// Spring.js contre le prototype des micro-interactions : `ref` est produit par
// docs/ui/micro-interactions/reference-values.js, qui évalue spring() du prototype
// lui-même. Puis les jetons de Theme.qml tels que Qt les joue vraiment.
TestCase {
    id: test
    name: "Spring"

    readonly property var ref: {"snappy":{"k":380,"c":28,"ms":394,"over":4,"points":[0,0.011,0.0407,0.0849,0.1397,0.2018,0.2685,0.3375,0.4069,0.475,0.5408,0.6032,0.6617,0.7158,0.7651,0.8097,0.8494,0.8845,0.9151,0.9414,0.9637,0.9824,0.9977,1.0101,1.0198,1.0271,1.0324,1.036,1.0381,1.039,1.0389,1.038,1.0364,1.0344,1.0321,1.0295,1.0269,1.0242,1.0215,1.0189,1.0164,1.014,1.0118,1.0099,1.008,1.0064,1.005,1.0037,1.0026,1.0017,1]},"bouncy":{"k":300,"c":18,"ms":613,"over":15,"points":[0,0.0209,0.0772,0.1596,0.2597,0.3697,0.4834,0.5955,0.7016,0.7988,0.8848,0.9585,1.0192,1.0671,1.1028,1.1273,1.1418,1.1477,1.1464,1.1395,1.1284,1.1142,1.0983,1.0815,1.0648,1.0488,1.034,1.0207,1.0092,0.9997,0.992,0.9862,0.9821,0.9795,0.9783,0.9782,0.979,0.9804,0.9824,0.9847,0.9872,0.9897,0.9921,0.9943,0.9964,0.9982,0.9997,1.0009,1.0018,1.0025,1]},"gentle":{"k":220,"c":24,"ms":460,"over":1,"points":[0,0.0087,0.0321,0.0671,0.1107,0.1606,0.2145,0.2709,0.3283,0.3855,0.4416,0.4959,0.5479,0.5971,0.6433,0.6863,0.726,0.7624,0.7956,0.8256,0.8526,0.8767,0.898,0.9169,0.9334,0.9477,0.9601,0.9706,0.9796,0.9872,0.9934,0.9985,1.0027,1.0059,1.0085,1.0104,1.0117,1.0126,1.0131,1.0132,1.0132,1.0129,1.0124,1.0119,1.0112,1.0105,1.0098,1.009,1.0083,1.0075,1]}}
    property real value: 0

    function near(actual, expected, tolerance, what) {
        verify(Math.abs(actual - expected) <= tolerance, what + " : " + actual + " au lieu de " + expected)
    }

    // Durée et dépassement affichés par le prototype.
    function test_durationAndOvershoot() {
        for (var name in ref) {
            var r = ref[name], peak = 0
            compare(Spring.duration(r.k, r.c, 1), r.ms, name)
            for (var ms = 0; ms <= r.ms; ms++)
                peak = Math.max(peak, Spring.state(r.k, r.c, 1, ms / 1000).x)
            compare(Math.round((peak - 1) * 100), r.over, name + " : dépassement en %")
        }
    }

    // Les 51 points de la courbe linear() du prototype (arrondis au 1/10 000).
    function test_positionsMatchThePrototype() {
        for (var name in ref) {
            var r = ref[name], T = Spring.params(r.k, r.c, 1).T
            for (var i = 0; i < 50; i++)
                near(Spring.state(r.k, r.c, 1, T * i / 50).x, r.points[i], 6e-5, name + " au point " + i)
        }
    }

    // Les jetons de Theme.qml joués par Qt (NumberAnimation en BezierSpline), à chaque
    // milliseconde : moins de 1 % de la course d'écart avec le ressort. Le plus gros
    // écart est au dernier instant, où le prototype saute lui aussi à 1 (0,4 % au plus).
    function test_qtPlaysTheSpring() {
        var tokens = { snappy: Theme.springSnappy, bouncy: Theme.springBouncy, gentle: Theme.springGentle }
        for (var name in tokens) {
            var token = tokens[name], r = ref[name], T = Spring.params(r.k, r.c, 1).T
            compare(token.duration, r.ms, name)
            verify(token.curve.length <= 6 * 10, name + " : Qt ne garde que 10 segments")
            var ctl = Qt.createQmlObject('import QtQuick; AnimationController { animation: NumberAnimation {'
                                         + ' property: "value"; from: 0; to: 1; easing.type: Easing.BezierSpline } }', test)
            ctl.animation.target = test
            ctl.animation.duration = token.duration
            ctl.animation.easing.bezierCurve = token.curve
            ctl.reload()
            for (var ms = 0; ms < token.duration; ms++) {
                ctl.progress = (ms + 0.5) / token.duration      // (Qt tronque le temps en ms entières)
                near(value, Spring.state(r.k, r.c, 1, T * ms / token.duration).x, 0.008, name + " à " + ms + " ms")
            }
            ctl.progress = 1
            compare(value, 1, name + " : arrivée")
            ctl.destroy()
        }
    }
}
