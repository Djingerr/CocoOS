pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import ".."

// Jaquette de l'écran de veille (SPEC §2.2), 326 × 460 : ombre pré-rendue, liseré, image
// assombrie, lumière à 135°, reflet qui glisse toutes les 11 s, reflet au sol, le tout
// incliné en perspective (18 s, aller-retour). Ombre et reflet au sol débordent de l'élément.
Item {
    id: root

    property url source
    property string label                       // libellé de la jaquette de test ; vide sinon
    property real brightness: label !== "" ? IdleTheme.coverBrightnessPlaceholder : IdleTheme.coverBrightnessReal
    property bool animated: true

    // Inclinaison (degrés) et position du reflet glissant (en largeurs de bande).
    property real rotY: 9
    property real rotX: 1
    property real sheenX: -1.6

    width: 326; height: 460

    // perspective(1400px) rotateY() rotateX(), origine au centre : T(c) · P · Ry · Rx · T(−c)
    // (Rotation de Qt Quick projette à 1024 px fixes).
    function tilt(ry, rx) {
        var a = ry * Math.PI / 180, b = rx * Math.PI / 180, cx = width / 2, cy = height / 2
        var t = Qt.matrix4x4(1, 0, 0, cx, 0, 1, 0, cy, 0, 0, 1, 0, 0, 0, 0, 1)
        var p = Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -1 / IdleTheme.perspective, 1)
        var my = Qt.matrix4x4(Math.cos(a), 0, Math.sin(a), 0, 0, 1, 0, 0, -Math.sin(a), 0, Math.cos(a), 0, 0, 0, 0, 1)
        var mx = Qt.matrix4x4(1, 0, 0, 0, 0, Math.cos(b), -Math.sin(b), 0, 0, Math.sin(b), Math.cos(b), 0, 0, 0, 0, 1)
        var back = Qt.matrix4x4(1, 0, 0, -cx, 0, 1, 0, -cy, 0, 0, 1, 0, 0, 0, 0, 1)
        var m = t.times(p).times(my).times(mx).times(back)
        // Ligne z mise à zéro, comme QMatrix4x4::projectedRotate : x, y et w ne changent pas,
        // mais Qt Quick rognerait en profondeur les coins qui sortent de z ∈ [−1, 1].
        return Qt.matrix4x4(m.m11, m.m12, m.m13, m.m14, m.m21, m.m22, m.m23, m.m24,
                            0, 0, 0, 0, m.m41, m.m42, m.m43, m.m44)
    }

    ParallelAnimation {
        running: root.animated
        loops: Animation.Infinite
        SequentialAnimation {
            NumberAnimation {
                target: root; property: "rotY"; from: 9; to: 3; duration: IdleTheme.coverTiltPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
            NumberAnimation {
                target: root; property: "rotY"; from: 3; to: 9; duration: IdleTheme.coverTiltPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
        }
        SequentialAnimation {
            NumberAnimation {
                target: root; property: "rotX"; from: 1; to: -1; duration: IdleTheme.coverTiltPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
            NumberAnimation {
                target: root; property: "rotX"; from: -1; to: 1; duration: IdleTheme.coverTiltPeriod
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
        }
    }
    // Reflet : tenu à gauche jusqu'à 55 % du cycle, glisse jusqu'à 85 %, tenu à droite.
    SequentialAnimation {
        running: root.animated
        loops: Animation.Infinite
        PropertyAction { target: root; property: "sheenX"; value: -1.6 }
        PauseAnimation { duration: 0.55 * IdleTheme.coverSheenPeriod }
        NumberAnimation {
            target: root; property: "sheenX"; to: 4.2; duration: 0.30 * IdleTheme.coverSheenPeriod
            easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
        }
        PauseAnimation { duration: 0.15 * IdleTheme.coverSheenPeriod }
    }

    Item {
        id: tilted
        width: root.width; height: root.height
        transform: Matrix4x4 { matrix: root.tilt(root.rotY, root.rotX) }

        // box-shadow 0 40px 90px rgba(0,0,0,0.6), pré-rendue (dessinée avant le reflet au sol,
        // qui passe par-dessus comme dans la maquette).
        Image {
            x: -150; y: -150
            width: 626; height: 760
            source: "../assets/cover_shadow_626x760.png"
        }

        // Reflet au sol : l'image retournée, 6 px sous la carte, qui s'efface vers le bas.
        Item {
            y: root.height + IdleTheme.reflectionGap
            width: root.width; height: root.height
            layer.enabled: true
            layer.effect: ShaderEffect {
                property size itemSize: Qt.size(root.width, root.height)
                property real radius: IdleTheme.radiusCover
                property real fadeAlpha: IdleTheme.reflectionStartAlpha
                property real fadeEnd: IdleTheme.reflectionFadeAt
                property real pixel: 1 / IdleTheme.scale
                fragmentShader: "../shaders/card.frag.qsb"
            }
            Image {
                anchors.fill: parent
                source: root.source
                fillMode: Image.PreserveAspectCrop
                mirrorVertically: true
            }
            Rectangle { anchors.fill: parent; color: "black"; opacity: 1 - root.brightness }
        }

        // Liseré : box-shadow 0 0 0 1px, autour de la carte.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: IdleTheme.radiusCover + 1
            color: "transparent"
            border.width: 1
            border.color: IdleTheme.coverRing
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: ShaderEffect {
                property size itemSize: Qt.size(root.width, root.height)
                property real radius: IdleTheme.radiusCover
                property real fadeAlpha: 1
                property real fadeEnd: 0
                property real pixel: 1 / IdleTheme.scale
                fragmentShader: "../shaders/card.frag.qsb"
            }
            Image {
                anchors.fill: parent
                source: root.source
                fillMode: Image.PreserveAspectCrop
            }
            Rectangle { anchors.fill: parent; color: "black"; opacity: 1 - root.brightness }
            // Lumière : linear-gradient(135deg, blanc 10 % → transparent à 42 %).
            Shape {
                id: lightShape
                anchors.fill: parent
                readonly property real span: (root.width + root.height) * Math.SQRT1_2
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: root.width / 2 - 0.5 * lightShape.span * Math.SQRT1_2
                        y1: root.height / 2 - 0.5 * lightShape.span * Math.SQRT1_2
                        x2: root.width / 2 + 0.5 * lightShape.span * Math.SQRT1_2
                        y2: root.height / 2 + 0.5 * lightShape.span * Math.SQRT1_2
                        GradientStop { position: 0; color: IdleTheme.coverLightFrom }
                        GradientStop { position: IdleTheme.coverLightStop; color: Qt.rgba(1, 1, 1, 0) }
                    }
                    PathRectangle { width: root.width; height: root.height }
                }
            }
            // Reflet glissant : bande de 30 % × 140 %, inclinée de −18°.
            Rectangle {
                id: sheen
                width: 0.30 * root.width
                height: 1.40 * root.height
                y: -0.20 * root.height
                x: root.sheenX * width
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.13) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
                readonly property real skew: Math.tan(-18 * Math.PI / 180)
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, sheen.skew, 0, -sheen.skew * sheen.height / 2,
                                         0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
            }
            Text {
                visible: root.label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: root.label
                color: IdleTheme.textTertiary
                font.family: IdleTheme.fontFamily
                font.pixelSize: IdleTheme.coverLabel.size
                font.weight: IdleTheme.coverLabel.weight
                font.letterSpacing: IdleTheme.coverLabel.letterSpacing
            }
        }
    }
}
