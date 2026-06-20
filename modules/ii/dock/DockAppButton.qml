import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 44
    property real countDotWidth: 12
    property real countDotHeight: 4
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    readonly property string iconName: desktopEntry?.icon || AppSearch.guessIcon(appToplevel.appId)
    readonly property string appLabel: desktopEntry?.name || appToplevel.appId || "?"
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : squareSide
    implicitHeight: isSeparator ? 1 : (vertical ? squareSide : background.implicitHeight)

    function iconSource(icon) {
        if (!icon) return "";
        if (icon.startsWith("/")) return "file://" + icon;
        const resolved = Quickshell.iconPath(icon, true);
        if (resolved && resolved.startsWith("/")) return "file://" + resolved;
        if (resolved) return resolved;
        return "";
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    onAppToplevelChanged: {
        root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: Appearance.sizes.hyprlandGapsOut + Appearance.rounding.normal
            bottomMargin: Appearance.sizes.hyprlandGapsOut + Appearance.rounding.normal
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel.toplevels.length > 0
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    onClicked: {
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    contentItem: Item {
        implicitWidth: root.squareSide
        implicitHeight: root.squareSide
        visible: !root.isSeparator

        Item {
            id: iconWrapper
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: appToplevel.toplevels.length > 0 ? -3 : 0
            }
            width: root.iconSize
            height: root.iconSize

                IconImage {
                    id: iconImage
                    anchors.fill: parent
                    source: root.iconSource(root.iconName)
                    implicitSize: root.iconSize
                    asynchronous: true
                    mipmap: true
                }

                Rectangle {
                    visible: iconImage.source === "" || iconImage.status === Image.Error
                    anchors.fill: parent
                radius: 10
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.25)

                StyledText {
                    anchors.centerIn: parent
                    text: root.appLabel.charAt(0).toUpperCase()
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        RowLayout {
            spacing: 3
            anchors {
                top: iconWrapper.bottom
                topMargin: 2
                horizontalCenter: parent.horizontalCenter
            }
            Repeater {
                model: Math.min(appToplevel.toplevels.length, 3)
                delegate: Rectangle {
                    required property int index
                    radius: Appearance.rounding.full
                    implicitWidth: (appToplevel.toplevels.length <= 3) ? 
                        root.countDotWidth : root.countDotHeight // Circles when too many
                    implicitHeight: root.countDotHeight
                    color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                }
            }
        }
    }
}
