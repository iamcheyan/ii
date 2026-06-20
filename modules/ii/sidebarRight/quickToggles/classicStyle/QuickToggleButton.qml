import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    baseWidth: 38
    baseHeight: 38
    clickedWidth: baseWidth
    bounce: false
    toggled: false
    buttonRadius: 0
    buttonRadiusPressed: 0
    colBackground: "#1d1d1d"
    colBackgroundHover: "#252525"
    colBackgroundActive: "#303030"
    colBackgroundToggled: "#285577"
    colBackgroundToggledHover: "#34658b"
    colBackgroundToggledActive: "#1f425d"
    borderWidth: 1
    borderColor: toggled ? "#4c7899" : "#333333"

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

}
