import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    readonly property int barSidePadding: 6
    readonly property int titleAreaWidth: 280
    readonly property color barOpaqueColor: "#cc11111b"

    property var screen: root.QsWindow.window?.screen
    readonly property HyprlandMonitor barMonitor: Hyprland.monitorFor(root.screen)
    readonly property int barActiveWorkspaceId: HyprlandData.monitorActiveWorkspaceId(root.barMonitor)
    readonly property bool workspaceHasWindows: {
        const wsId = root.barActiveWorkspaceId;
        if (wsId < 1)
            return false;

        const wsData = HyprlandData.workspaceById[wsId];
        if (wsData !== undefined && typeof wsData.windows === "number")
            return wsData.windows > 0;

        return HyprlandData.hyprlandClientsForWorkspace(wsId).some(
            win => win.mapped && !win.hidden
        );
    }
    readonly property color barBackgroundColor: Config.options.bar.showBackground && root.workspaceHasWindows
        ? root.barOpaqueColor
        : "transparent"
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

    // Background shadow
    Loader {
        active: Config.options.bar.showBackground && Config.options.bar.cornerStyle === 1 && Config.options.bar.floatStyleShadow && root.workspaceHasWindows
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: root.barBackgroundColor
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: 0
        border.color: Appearance.colors.colLayer0Border

        Behavior on color {
            ColorAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }
        }
    }

    RowLayout {
        id: leftSectionRowLayout
        anchors.left: parent.left
        anchors.leftMargin: root.barSidePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        BarTextButton {
            Layout.alignment: Qt.AlignVCenter
            text: "Applications"
            onTriggered: GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }

        Workspaces {
            id: workspacesWidget
            Layout.alignment: Qt.AlignVCenter
        }

        ActiveWindow {
            id: activeWindowItem
            Layout.alignment: Qt.AlignVCenter
            titleAreaWidth: root.titleAreaWidth
            visible: root.useShortenedForm === 0
        }
    }

    MouseArea { // Center clock
        id: centerClock
        z: 1
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.max(centerClockWidget.implicitWidth + 24, 140)
        implicitHeight: centerClockWidget.implicitHeight

        onClicked: {
            GlobalStates.scheduleOpen = !GlobalStates.scheduleOpen;
        }

        ClockWidget {
            id: centerClockWidget
            anchors.verticalCenter: parent.verticalCenter
            showHoverPopup: false
        }
    }

    FocusedScrollMouseArea { // Right side
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: centerClock.right
            right: parent.right
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        // Visual content

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            spacing: 5
            layoutDirection: Qt.RightToLeft

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.rightMargin: Appearance.rounding.screenRounding
                Layout.fillWidth: false

                implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2
                implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)
                colBackgroundToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
                colBackgroundToggledHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerHover, 1)
                colRippleToggled: ColorUtils.transparentize(Appearance.colors.colSecondaryContainerActive, 1)
                toggled: GlobalStates.sidebarRightOpen
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                RowLayout {
                    id: indicatorsRowLayout
                    anchors.centerIn: parent
                    property real realSpacing: 15
                    spacing: 0

                    Revealer {
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        reveal: Audio.source?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        color: rightSidebarButton.colText
                    }
                    Revealer {
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        text: "power_settings_new"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: {
                    GlobalStates.barDialogType = "bluetooth";
                    GlobalStates.barDialogOpen = true;
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Bluetooth")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: {
                    GlobalStates.barDialogType = "wifi";
                    GlobalStates.barDialogOpen = true;
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Connect to Wi-Fi")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: {
                    GlobalStates.barDialogType = "clipboard";
                    GlobalStates.barDialogOpen = true;
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "content_paste"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Clipboard")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            UtilButtons {
                visible: (Config.options.bar.verbose && root.useShortenedForm === 0)
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: {
                    GlobalStates.barDialogType = "nightlight";
                    GlobalStates.barDialogOpen = true;
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: Hyprsunset.temperatureActive ? "bedtime" : "bedtime_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Hyprsunset.temperatureActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Night Light")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: Idle.toggleInhibit()
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "free_cancellation"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Idle.inhibit ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Keep system awake")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            CircleUtilButton {
                visible: root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                onClicked: {
                    GlobalStates.barDialogType = "audio";
                    GlobalStates.barDialogOpen = true;
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    PopupToolTip {
                        text: Translation.tr("Audio output")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }

            BatteryIndicator {
                visible: Battery.available && root.useShortenedForm === 0
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
            }

            Media {
                visible: root.useShortenedForm === 0
                Layout.fillHeight: true
            }

            SysTray {
                visible: root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config?.options.bar.bottom
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Weather
            Loader {
                Layout.leftMargin: 4
                active: Config.options.bar.weather.enable
                sourceComponent: WeatherBar {}
            }
        }
    }
}
