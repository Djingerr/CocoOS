import QtQuick

// Bannière des favoris (MotionFavori), en bas au centre : « Ajouté aux favoris » (cœur plein)
// ou « Retiré des favoris » (cœur au trait). Elle monte en rebondissant, reste
// Theme.bannerHold, puis redescend. Un nouvel appel la remplace sans attendre.
Rectangle {
    id: root

    property bool added: true
    property bool shown: false
    function show(isAdded) {
        added = isAdded
        shown = true
        hold.restart()
    }
    Timer { id: hold; interval: Theme.bannerHold; onTriggered: root.shown = false }

    width: row.width + Theme.backPillPadRight + Theme.space3
    height: Theme.bannerHeight
    radius: height / 2
    color: Theme.bannerFill
    border.color: Theme.hairlineStrong
    visible: opacity > 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    property real lift: shown ? 0 : Theme.bannerTravel
    Behavior on lift {
        NumberAnimation {
            duration: root.shown ? Theme.bannerIn : Theme.bannerOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Theme.curveBannerIn : Theme.curveExit
        }
    }
    transform: Translate { y: root.lift }
    Behavior on opacity { NumberAnimation { duration: root.shown ? 240 : Theme.durExit; easing.type: root.shown ? Easing.Linear : Easing.InQuad } }
    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? Theme.bannerIn : Theme.bannerOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Theme.curveBannerIn : Theme.curveExit
        }
    }

    Row {
        id: row
        x: Theme.space3 + 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space2 + 2
        Heart { anchors.verticalCenter: parent.verticalCenter; size: 16; filled: root.added }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.added ? qsTr("Ajouté aux favoris") : qsTr("Retiré des favoris")
            color: Theme.ink
            font.family: Theme.fontUi; font.pixelSize: Theme.textCaption.size; font.weight: Font.DemiBold
        }
    }
}
