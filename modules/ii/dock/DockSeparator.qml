import qs.modules.common
import QtQuick
import QtQuick.Layouts

Rectangle {
    property bool vertical: false
    property real padding: 8

    Layout.topMargin: vertical ? 0 : (Appearance.sizes.elevationMargin + padding + Appearance.rounding.normal)
    Layout.bottomMargin: vertical ? 0 : (Appearance.sizes.hyprlandGapsOut + padding + Appearance.rounding.normal)
    Layout.leftMargin: 0
    Layout.rightMargin: 0
    Layout.fillHeight: !vertical
    Layout.fillWidth: false
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: vertical ? 52 : 1
    implicitHeight: vertical ? 1 : -1
    color: Appearance.colors.colOutlineVariant
}
