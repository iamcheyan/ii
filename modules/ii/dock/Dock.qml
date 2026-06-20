import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            readonly property string dockPosition: "left"
            readonly property bool horizontal: false
            readonly property bool onLeft: true
            readonly property bool onRight: false

            readonly property HyprlandMonitor dockMonitor: Hyprland.monitorFor(modelData)
            readonly property int activeWorkspaceId: HyprlandData.monitorActiveWorkspaceId(dockRoot.dockMonitor)
            readonly property bool workspaceIsEmpty: {
                const wsId = dockRoot.activeWorkspaceId;
                if (wsId < 1)
                    return true;
                const wsData = HyprlandData.workspaceById[wsId];
                if (wsData !== undefined && typeof wsData.windows === "number")
                    return wsData.windows === 0;
                return !HyprlandData.hyprlandClientsForWorkspace(wsId).some(
                    win => win.mapped && !win.hidden
                );
            }

            readonly property real dockWidth: 104
            readonly property real dockPadding: 12
            readonly property bool hoverRevealEnabled: Config.options?.dock.hoverToReveal ?? true
            readonly property real hoverRegion: Config.options?.dock.hoverRegionHeight ?? 4

            property bool requestDockShow: dockAppsVertical.requestDockShow
            property bool reveal: dockRoot.requestDockShow
                || dockRoot.workspaceIsEmpty
                || (dockRoot.hoverRevealEnabled && dockMouseArea.containsMouse)

            anchors {
                bottom: dockRoot.horizontal
                left: dockRoot.horizontal || dockRoot.onLeft
                right: dockRoot.horizontal || dockRoot.onRight
                top: false
            }

            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:dock"

            implicitWidth: dockRoot.dockWidth
            implicitHeight: dockBackground.implicitHeight

            mask: Region {
                item: dockMouseArea
            }

            MouseArea {
                id: dockMouseArea
                anchors.fill: parent

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent

                    Item {
                        id: dockBackground
                        width: dockRoot.dockWidth
                        height: implicitHeight
                        anchors.verticalCenter: parent.verticalCenter
                        x: dockRoot.reveal ? 0 : -width + dockRoot.hoverRegion
                        implicitWidth: dockRoot.dockWidth
                        implicitHeight: dockRowVertical.implicitHeight + dockRoot.dockPadding * 2

                        Behavior on x {
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Easing.OutCubic
                            }
                        }

                        StyledRectangularShadow {
                            target: dockVisualBackground
                        }

                        Rectangle {
                            id: dockVisualBackground
                            anchors.fill: parent
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, 0.06)
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            radius: width / 2
                        }

                        ColumnLayout {
                            id: dockRowVertical
                            anchors.centerIn: parent
                            spacing: 3

                            DockApps {
                                id: dockAppsVertical
                                vertical: true
                                buttonPadding: dockRoot.dockPadding
                            }
                            DockSeparator { vertical: true; padding: dockRoot.dockPadding }
                            DockButton {
                                vertical: true
                                onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                                contentItem: MaterialSymbol {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: parent.width / 2
                                    text: "apps"
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }
                }

            }
        }
    }
}
