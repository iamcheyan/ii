import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    property bool overviewGrabbed: false

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    signal requestOverviewFocus()

    function overviewModelForFocusedMonitor() {
        return HyprlandData.overviewWorkspaceEntriesOnMonitor(
            overviewScope.focusedMonitorName());
    }

    function overviewGridColumnsForModel(model) {
        return Math.min(Math.max(model.length, 1), Config.options.overview.columns);
    }

    function overviewIndexForWorkspace(model, wsId) {
        const idx = model.findIndex(entry => entry.id === wsId);
        return idx >= 0 ? idx : 0;
    }

    function overviewFocusedWorkspaceId() {
        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            return GlobalStates.overviewFocusedWorkspaceId;
        return overviewScope.currentWorkspaceId();
    }

    function dispatchFocusWorkspace(wsId) {
        if (wsId < 1)
            return;
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
    }

    function focusOverviewWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewFocusedWorkspaceId = wsId;
        overviewScope.dispatchFocusWorkspace(wsId);
        if (!overviewScope.overviewGrabbed) {
            Qt.callLater(overviewScope.syncOverviewScreen);
        }
    }

    function navigateOverviewByIndex(delta) {
        const model = overviewScope.overviewModelForFocusedMonitor();
        if (model.length === 0)
            return;

        const ws = overviewScope.overviewFocusedWorkspaceId();
        let idx = overviewScope.overviewIndexForWorkspace(model, ws);
        idx = (idx + delta + model.length) % model.length;
        overviewScope.focusOverviewWorkspace(model[idx].id);
    }

    function navigateOverviewGrid(deltaRow, deltaCol) {
        const model = overviewScope.overviewModelForFocusedMonitor();
        const n = model.length;
        if (n === 0)
            return;

        const cols = overviewScope.overviewGridColumnsForModel(model);
        const ws = overviewScope.overviewFocusedWorkspaceId();
        let idx = overviewScope.overviewIndexForWorkspace(model, ws);

        if (deltaCol !== 0)
            overviewScope.navigateOverviewByIndex(deltaCol);
        else if (deltaRow !== 0)
            overviewScope.navigateOverviewByIndex(deltaRow * cols);
    }

    function cycleOverviewWorkspace(dir) {
        overviewScope.navigateOverviewByIndex(dir);
    }

    function openGrabbedMode(dir) {
        if (GlobalStates.overviewOpen && overviewScope.overviewGrabbed) {
            overviewScope.cycleOverviewWorkspace(dir);
        } else {
            overviewScope.overviewGrabbed = true;
            GlobalStates.overviewOpen = true;
            Qt.callLater(() => {
                overviewScope.cycleOverviewWorkspace(dir);
                overviewScope.requestOverviewFocus();
            });
        }
    }

    function commitGrabbedMode() {
        overviewScope.overviewGrabbed = false;
        GlobalStates.overviewOpen = false;
    }

    function overviewNavigationActive() {
        return GlobalStates.overviewOpen
            && panelWindow.searchingText === "";
    }

    function handleOverviewNavigationKey(event) {
        if (!overviewScope.overviewNavigationActive())
            return;

        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter
                && event.key !== Qt.Key_Return && event.text.charCodeAt(0) >= 0x20) {
            searchWidget.focusSearchInput();
            searchWidget.setSearchingText(event.text);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            overviewScope.navigateOverviewGrid(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            overviewScope.navigateOverviewGrid(0, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            overviewScope.navigateOverviewGrid(-1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            overviewScope.navigateOverviewGrid(1, 0);
            event.accepted = true;
        }
    }

    function syncOverviewScreen() {
        if (overviewScope.focusedScreen)
            panelWindow.screen = overviewScope.focusedScreen;
    }

    function currentWorkspaceId() {
        const monitor = Hyprland.focusedMonitor ?? Hyprland.monitors[0];
        if (!monitor)
            return HyprlandData.activeWorkspace?.id ?? 1;
        return HyprlandData.monitorActiveWorkspaceId(monitor) || HyprlandData.activeWorkspace?.id || 1;
    }

    function focusedMonitorName() {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (GlobalStates.overviewOpen)
                overviewScope.syncOverviewScreen();
        }
    }

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        screen: overviewScope.focusedScreen
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        visible: GlobalStates.overviewOpen && overviewScope.focusedScreen

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: overviewScope.overviewGrabbed
            ? WlrKeyboardFocus.Exclusive
            : (GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    overviewScope.overviewGrabbed = false;
                    GlobalStates.overviewFocusedWorkspaceId = -1;
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    searchWidget.cancelSearch();
                    overviewScope.syncOverviewScreen();
                    GlobalStates.overviewFocusedWorkspaceId = overviewScope.currentWorkspaceId();
                    if (!overviewScope.overviewGrabbed)
                        GlobalFocusGrab.addDismissable(panelWindow);
                    Qt.callLater(() => overviewScope.requestOverviewFocus());
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (!overviewScope.overviewGrabbed)
                    GlobalStates.overviewOpen = false;
            }
        }

        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Item {
            id: overviewKeyHandler
            anchors.fill: parent
            z: 999
            focus: overviewScope.overviewNavigationActive() || overviewScope.overviewGrabbed

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                    event.accepted = true;
                    return;
                }
                if (overviewScope.overviewGrabbed && event.key === Qt.Key_Tab) {
                    const backward = (event.modifiers & Qt.ShiftModifier) !== 0;
                    overviewScope.cycleOverviewWorkspace(backward ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                overviewScope.handleOverviewNavigationKey(event);
            }

            Keys.onReleased: event => {
                if (overviewScope.overviewGrabbed &&
                    (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta)) {
                    overviewScope.commitGrabbedMode();
                    event.accepted = true;
                }
            }

            Connections {
                target: GlobalStates
                function onSuperDownChanged() {
                    if (overviewScope.overviewGrabbed && !GlobalStates.superDown)
                        overviewScope.commitGrabbedMode();
                }
            }

            Connections {
                target: overviewScope
                function onRequestOverviewFocus() {
                    if (overviewScope.overviewNavigationActive() || overviewScope.overviewGrabbed)
                        overviewKeyHandler.forceActiveFocus();
                }
                function onOverviewGrabbedChanged() {
                    if (overviewScope.overviewGrabbed)
                        overviewKeyHandler.forceActiveFocus();
                }
            }

            Connections {
                target: panelWindow
                function onSearchingTextChanged() {
                    if (overviewScope.overviewNavigationActive())
                        Qt.callLater(() => overviewScope.requestOverviewFocus());
                }
            }
        }

        Column {
            id: columnLayout
            visible: GlobalStates.overviewOpen
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    GlobalStates.overviewOpen = false;
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                anchors.horizontalCenter: parent.horizontalCenter
                active: GlobalStates.overviewOpen && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                    visible: (panelWindow.searchingText == "")
                }
            }


        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
        function overviewNext() {
            overviewScope.openGrabbedMode(1);
        }
        function overviewPrev() {
            overviewScope.openGrabbedMode(-1);
        }
        function overviewCommit() {
            overviewScope.commitGrabbedMode();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewNext"
        description: "Workspace overview: cycle next (Win+Tab)"
        onPressed: overviewScope.openGrabbedMode(1)
    }
    GlobalShortcut {
        name: "overviewPrev"
        description: "Workspace overview: cycle prev (Win+Shift+Tab)"
        onPressed: overviewScope.openGrabbedMode(-1)
    }
    GlobalShortcut {
        name: "overviewCommit"
        description: "Workspace overview: commit on Win release"
        onPressed: overviewScope.commitGrabbedMode()
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
