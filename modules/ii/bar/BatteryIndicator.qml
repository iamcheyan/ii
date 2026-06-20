import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color colIcon: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer0

    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: isCharging ? "battery_charging_full" : Icons.getBatteryIcon(Battery.percentage * 100)
            iconSize: Appearance.font.pixelSize.larger
            color: root.colIcon
            animateChange: true
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font {
                pixelSize: Appearance.font.pixelSize.small
                weight: Font.DemiBold
            }
            color: root.colIcon
            text: `${Math.round(percentage * 100)}%`
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
