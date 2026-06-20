import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

GroupButton {
    id: button
    property string buttonIcon: ""
    property string buttonText: ""

    baseHeight: 34
    baseWidth: content.implicitWidth + 42
    clickedWidth: baseWidth
    bounce: false

    buttonRadius: 0
    buttonRadiusPressed: 0
    colBackground: "#1d1d1d"
    colBackgroundHover: "#252525"
    colBackgroundActive: "#303030"
    colBackgroundToggled: "#285577"
    colBackgroundToggledHover: "#34658b"
    colBackgroundToggledActive: "#1f425d"
    borderWidth: 1
    borderColor: toggled ? "#4c7899" : "#303030"
    property color colText: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1

    contentItem: Item {
        id: content
        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight
        RowLayout {
            id: contentRowLayout
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                visible: buttonIcon !== ""
                text: buttonIcon
                iconSize: Appearance.font.pixelSize.huge
                color: button.colText
            }
            StyledText {
                visible: buttonText !== ""
                text: buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                color: button.colText
            }
        }
    }

}
