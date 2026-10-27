pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../components"
import "../IdleFormat.js" as F

// Écran 12 : repos, ni partie ni téléchargement (SPEC §3). Lueur accent qui respire sous la
// date, l'heure en dégradé et la capsule d'état.
Item {
    id: root

    property IdleStatus status
    property bool drift: true
    property bool animated: true
    property bool entryStarted: true

    readonly property var network: status.network
    readonly property var battery: status.battery
    readonly property var lastGame: status.lastGame

    width: IdleTheme.reference.width
    height: IdleTheme.reference.height

    // --- Lueur (14 s : opacité 0,7 ↔ 1, échelle 1 ↔ 1,08) ---
    // L'opacité de 0,22 de la spec ne s'applique pas : dans la maquette, l'animation CSS
    // `cocoGlow` remplace l'opacité écrite sur l'élément (et la référence le confirme).
    BlurredBackdrop {
        readonly property var g: IdleTheme.restGlow
        property real pulse: 0
        box: Qt.rect(g.centerX - g.width / 2, g.top, g.width, g.height)
        blurPx: g.blurCssPx
        layerOpacity: 0.7 + 0.3 * pulse
        layerScale: 1 + 0.08 * pulse
        SequentialAnimation on pulse {
            running: root.animated
            loops: Animation.Infinite
            NumberAnimation {
                from: 0; to: 1; duration: IdleTheme.restGlowPeriod / 2
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
            NumberAnimation {
                from: 1; to: 0; duration: IdleTheme.restGlowPeriod / 2
                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.easeInOut
            }
        }
        // radial-gradient(ellipse, accent 0 %, transparent 65 %) : rayons « farthest-corner ».
        ShaderEffect {
            anchors.fill: parent
            property size canvasSize: Qt.size(width, height)
            property point center: Qt.point(width / 2, height / 2)
            property size radii: Qt.size(width / 2 * Math.SQRT2, height / 2 * Math.SQRT2)
            property real stopAt: IdleTheme.restGlow.stopAt
            property color color: IdleTheme.accent
            fragmentShader: "../shaders/glowsource.frag.qsb"
        }
    }

    // Segment de la capsule : icône + 12 px + titre et sous-titre.
    component Segment: Row {
        id: segment
        property string title
        property string subtitle
        property bool tabular: false
        default property alias icon: iconBox.data
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 22; rightPadding: 22
        spacing: 12
        Item {
            id: iconBox
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width; height: childrenRect.height
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            IdleText {
                text: segment.title
                textStyle: IdleTheme.capsuleTitle
                tabular: segment.tabular
            }
            IdleText {
                text: segment.subtitle
                textStyle: IdleTheme.capsuleSub
                color: IdleTheme.textSecondary
            }
        }
    }
    component Hairline: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1; height: 30
        color: IdleTheme.hairline
    }

    DriftGroup {
        running: root.animated && root.drift

        // --- Date et heure ---
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            spacing: 2
            EntryReveal {
                anchors.horizontalCenter: parent.horizontalCenter
                started: root.entryStarted
                delay: IdleTheme.entryDelays.restDate
                width: date.implicitWidth; height: date.implicitHeight
                IdleText {
                    id: date
                    text: F.longDate(root.status.now)
                    textStyle: IdleTheme.restDate
                    color: IdleTheme.textDate
                }
            }
            EntryReveal {
                anchors.horizontalCenter: parent.horizontalCenter
                started: root.entryStarted
                delay: IdleTheme.entryDelays.restClock
                duration: IdleTheme.entryDurations.restClock
                width: clock.implicitWidth; height: clock.implicitHeight
                GradientText {
                    id: clock
                    text: F.clock(root.status.now)
                }
            }
        }

        // --- Capsule d'état ---
        EntryReveal {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 452
            started: root.entryStarted
            delay: IdleTheme.entryDelays.restCapsule
            duration: IdleTheme.entryDurations.restCapsule
            width: capsule.implicitWidth; height: capsule.implicitHeight
            GlassCapsule {
                id: capsule
                Segment {
                    title: root.status.host.name
                    subtitle: F.hostState(root.status.host)
                    StatusIcon { name: "monitor"; large: true }
                }
                Hairline { visible: wifiSegment.visible }
                Segment {
                    id: wifiSegment
                    visible: root.network.kind === "wifi"
                    title: F.latency(root.network.latencyMs)
                    subtitle: F.wifiQuality(root.network.quality || F.wifiQualityKey(root.network.rssiDbm), true)
                    tabular: true
                    StatusIcon { name: "wifi"; large: true }
                }
                Hairline { visible: batterySegment.visible }
                Segment {
                    id: batterySegment
                    visible: root.battery.percent >= 0
                    title: F.percentValue(root.battery.percent)
                    subtitle: F.autonomy(root.battery.minutesLeft, root.battery.charging)
                    // L'anneau se dessine de 0 au niveau, 600 ms après le début de l'entrée.
                    ProgressRing {
                        id: batteryRing
                        width: 26; height: 26
                        radius: 11; strokeWidth: 3
                        trackColor: IdleTheme.ringTrackRest
                        property real drawn: 0
                        progress: drawn * root.battery.percent / 100
                        SequentialAnimation on drawn {
                            running: root.entryStarted
                            PauseAnimation { duration: IdleTheme.batteryRingDelay }
                            NumberAnimation {
                                from: 0; to: 1; duration: IdleTheme.batteryRingDuration
                                easing.type: Easing.BezierSpline; easing.bezierCurve: IdleTheme.appleOut
                            }
                        }
                    }
                }
                Hairline { visible: gameSegment.visible }
                Segment {
                    id: gameSegment
                    visible: root.lastGame !== null
                    leftPadding: 18
                    title: root.lastGame ? root.lastGame.title : ""
                    subtitle: root.lastGame ? F.lastSession(root.lastGame.lastPlayedAt, root.status.now) : ""
                    Item {
                        width: 32; height: 45
                        // box-shadow 0 0 0 1px : liseré extérieur.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            radius: IdleTheme.radiusCoverThumb + 1
                            color: "transparent"
                            border.width: 1
                            border.color: IdleTheme.thumbRing
                        }
                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: ShaderEffect {
                                property size itemSize: Qt.size(32, 45)
                                property real radius: IdleTheme.radiusCoverThumb
                                property real fadeAlpha: 1
                                property real fadeEnd: 0
                                property real pixel: 1 / IdleTheme.scale
                                fragmentShader: "../shaders/card.frag.qsb"
                            }
                            Image {
                                anchors.fill: parent
                                source: root.lastGame ? root.lastGame.coverUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(64 * IdleTheme.scale, 90 * IdleTheme.scale)
                            }
                            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.25 }   // brightness(0.75)
                        }
                    }
                }
            }
        }

        // --- Indication du bas ---
        EntryReveal {
            started: root.entryStarted
            delay: IdleTheme.entryDelays.keyHint
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 44 - height
            width: hint.implicitWidth; height: hint.implicitHeight
            KeyHint { id: hint; action: qsTr("pour ouvrir l'accueil") }
        }
    }
}
