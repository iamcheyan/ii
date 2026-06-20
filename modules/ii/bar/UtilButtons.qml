import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: Config.options.bar.utilButtons.showScreenSnip
            sourceComponent: Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: screenshotButton.implicitWidth
                implicitHeight: screenshotButton.implicitHeight
                property bool hovered: screenshotButton.hovered

                RippleButton {
                    id: screenshotButton
                    anchors.centerIn: parent
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

                    onClicked: {
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: (event) => {
                        if (event.button === Qt.RightButton) {
                            screenshotMenu.open();
                        }
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: screenshotButton
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer2
                }

                PopupToolTip {
                    text: Translation.tr("Screenshot tool")
                    anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                }

                Loader {
                    id: screenshotMenu
                    function open() {
                        screenshotMenu.active = true;
                    }
                    active: false
                    sourceComponent: ScreenshotContextMenu {
                        Component.onCompleted: this.open();
                        anchor {
                            window: screenshotButton.QsWindow.window
                            item: screenshotButton
                            gravity: Config.options.bar.vertical
                                ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                                : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                            edges: Config.options.bar.vertical
                                ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                                : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                        }
                        onMenuClosed: {
                            screenshotMenu.active = false;
                        }
                    }
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showColorPicker
            visible: Config.options.bar.utilButtons.showColorPicker
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1
                        text: "colorize"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                    PopupToolTip {
                        text: Translation.tr("Color picker")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showMicToggle
            visible: Config.options.bar.utilButtons.showMicToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                    PopupToolTip {
                        text: Translation.tr("Microphone")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showDarkModeToggle
            visible: Config.options.bar.utilButtons.showDarkModeToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`])
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`])
                    }
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                    PopupToolTip {
                        text: Translation.tr("Dark Mode")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showPerformanceProfileToggle
            visible: Config.options.bar.utilButtons.showPerformanceProfileToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                Item {
                    implicitWidth: 20
                    implicitHeight: 20
                    property bool hovered: parent.hovered
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: return "energy_savings_leaf"
                            case PowerProfile.Balanced: return "airwave"
                            case PowerProfile.Performance: return "local_fire_department"
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                    PopupToolTip {
                        text: Translation.tr("Click to cycle through power profiles")
                        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
                    }
                }
            }
        }
    }
}
