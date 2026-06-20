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

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    signal requestAltTabFocus()
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
        Qt.callLater(overviewScope.syncOverviewScreen);
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

    function overviewNavigationActive() {
        return GlobalStates.overviewOpen
            && !GlobalStates.overviewAltTabMode
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

    // Alt+Tab: only cycle workspaces that exist on the focused monitor
    function workspaceCycleList() {
        const onMonitor = HyprlandData.workspaceIdsOnMonitor(overviewScope.focusedMonitorName());
        const ids = onMonitor.length > 0 ? onMonitor : (() => {
            const currentWs = overviewScope.currentWorkspaceId();
            return currentWs > 0 ? [currentWs] : [1];
        })();
        let maxId = 0;
        for (const id of ids) maxId = Math.max(maxId, id);
        if (maxId === 0) maxId = overviewScope.currentWorkspaceId();
        const trailingId = maxId + 1;
        return trailingId <= 100 ? [...ids, trailingId] : ids;
    }

    function altTabTrailingId() {
        const list = overviewScope.workspaceCycleList();
        if (list.length === 0) return -1;
        const last = list[list.length - 1];
        return HyprlandData.workspaceById[last] === undefined ? last : -1;
    }

    function focusWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewAltTabSelectedWorkspaceId = wsId;
        if (wsId === overviewScope.altTabTrailingId()) {
            Qt.callLater(overviewScope.syncOverviewScreen);
            return;
        }
        overviewScope.dispatchFocusWorkspace(wsId);
        Qt.callLater(overviewScope.syncOverviewScreen);
    }

    function cycleAltTabWorkspace(dir) {
        const list = overviewScope.workspaceCycleList();
        if (list.length === 0)
            return;

        let idx = list.indexOf(GlobalStates.overviewAltTabSelectedWorkspaceId);
        if (idx < 0)
            idx = list.indexOf(overviewScope.currentWorkspaceId());
        if (idx < 0)
            idx = 0;

        idx = (idx + dir + list.length) % list.length;
        overviewScope.focusWorkspace(list[idx]);
    }

    function openAltTabMode(initialDir) {
        const dir = initialDir === 0 ? 1 : initialDir;
        const currentWs = overviewScope.currentWorkspaceId();

        overviewScope.syncOverviewScreen();
        overviewScope.dontAutoCancelSearch = true;
        GlobalStates.overviewAltTabMode = true;
        GlobalStates.overviewAltTabOriginalWorkspaceId = currentWs;
        GlobalStates.overviewAltTabSelectedWorkspaceId = currentWs;

        if (!GlobalStates.overviewOpen) {
            GlobalStates.overviewOpen = true;
            if (dir < 0)
                Qt.callLater(() => overviewScope.cycleAltTabWorkspace(-1));
        } else {
            overviewScope.cycleAltTabWorkspace(dir);
        }

        overviewScope.requestAltTabFocus();
        Qt.callLater(() => overviewScope.requestAltTabFocus());
    }

    function commitAltTab() {
        if (!GlobalStates.overviewAltTabMode)
            return;
        const selected = GlobalStates.overviewAltTabSelectedWorkspaceId;
        const isTrailing = selected > 0 && HyprlandData.workspaceById[selected] === undefined;
        GlobalStates.overviewAltTabMode = false;
        GlobalStates.overviewAltTabOriginalWorkspaceId = -1;
        GlobalStates.overviewAltTabSelectedWorkspaceId = -1;
        GlobalStates.overviewOpen = false;
        if (isTrailing)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "empty" })`);
    }

    function cancelAltTab() {
        if (!GlobalStates.overviewAltTabMode) {
            GlobalStates.overviewOpen = false;
            return;
        }
        const originalWs = GlobalStates.overviewAltTabOriginalWorkspaceId;
        GlobalStates.overviewAltTabMode = false;
        GlobalStates.overviewAltTabOriginalWorkspaceId = -1;
        GlobalStates.overviewAltTabSelectedWorkspaceId = -1;
        GlobalStates.overviewOpen = false;
        if (originalWs > 0)
            overviewScope.dispatchFocusWorkspace(originalWs);
    }

    function handleAltTabKeyPressed(event) {
        if (!GlobalStates.overviewAltTabMode || !GlobalStates.overviewOpen)
            return;

        if (event.key === Qt.Key_Tab) {
            const backward = (event.modifiers & Qt.ShiftModifier) !== 0;
            overviewScope.cycleAltTabWorkspace(backward ? -1 : 1);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            overviewScope.cancelAltTab();
            event.accepted = true;
        }
    }

    function handleAltTabKeyReleased(event) {
        if (!GlobalStates.overviewAltTabMode || !GlobalStates.overviewOpen)
            return;

        if (event.key === Qt.Key_Alt || event.key === Qt.Key_Alt_L || event.key === Qt.Key_Alt_R) {
            overviewScope.commitAltTab();
            event.accepted = true;
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (GlobalStates.overviewOpen)
                overviewScope.syncOverviewScreen();
        }
    }

    Connections {
        target: HyprlandData
        function onActiveWorkspaceChanged() {
            if (!GlobalStates.overviewAltTabMode || !HyprlandData.activeWorkspace?.id)
                return;
            GlobalStates.overviewAltTabSelectedWorkspaceId = HyprlandData.activeWorkspace.id;
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
        WlrLayershell.keyboardFocus: GlobalStates.overviewAltTabMode
            ? WlrKeyboardFocus.Exclusive
            : (GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
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
                    GlobalStates.overviewAltTabMode = false;
                    GlobalStates.overviewAltTabOriginalWorkspaceId = -1;
                    GlobalStates.overviewAltTabSelectedWorkspaceId = -1;
                    GlobalStates.overviewFocusedWorkspaceId = -1;
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    searchWidget.cancelSearch();
                    overviewScope.syncOverviewScreen();
                    if (!GlobalStates.overviewAltTabMode) {
                        GlobalStates.overviewFocusedWorkspaceId = overviewScope.currentWorkspaceId();
                        GlobalFocusGrab.addDismissable(panelWindow);
                        Qt.callLater(() => overviewScope.requestOverviewFocus());
                    }
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (GlobalStates.overviewAltTabMode)
                    overviewScope.cancelAltTab();
                else
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
            id: altTabKeyHandler
            anchors.fill: parent
            z: 1000
            focus: GlobalStates.overviewAltTabMode && GlobalStates.overviewOpen
            visible: GlobalStates.overviewAltTabMode

            Keys.onPressed: event => overviewScope.handleAltTabKeyPressed(event)
            Keys.onReleased: event => overviewScope.handleAltTabKeyReleased(event)

            Connections {
                target: overviewScope
                function onRequestAltTabFocus() {
                    altTabKeyHandler.forceActiveFocus();
                }
            }
        }

        Item {
            id: overviewKeyHandler
            anchors.fill: parent
            z: 999
            focus: overviewScope.overviewNavigationActive()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                    event.accepted = true;
                    return;
                }
                overviewScope.handleOverviewNavigationKey(event);
            }

            Connections {
                target: overviewScope
                function onRequestOverviewFocus() {
                    if (overviewScope.overviewNavigationActive())
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
                if (event.key === Qt.Key_Escape) {
                    if (GlobalStates.overviewAltTabMode)
                        overviewScope.cancelAltTab();
                    else
                        GlobalStates.overviewOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !GlobalStates.overviewAltTabMode
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
                    visible: GlobalStates.overviewAltTabMode || (panelWindow.searchingText == "")
                    altTabCycler: (dir) => overviewScope.cycleAltTabWorkspace(dir)
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
        function altTabNext() {
            overviewScope.openAltTabMode(1);
        }
        function altTabPrev() {
            overviewScope.openAltTabMode(-1);
        }
        function altTabCommit() {
            overviewScope.commitAltTab();
        }
        function altTabCancel() {
            overviewScope.cancelAltTab();
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
        name: "overviewAltTabNext"
        description: "Alt+Tab workspace overview: show or cycle next"

        onPressed: {
            overviewScope.openAltTabMode(1);
        }
    }
    GlobalShortcut {
        name: "overviewAltTabPrev"
        description: "Alt+Shift+Tab workspace overview: show or cycle previous"

        onPressed: {
            overviewScope.openAltTabMode(-1);
        }
    }
    GlobalShortcut {
        name: "overviewAltTabCommit"
        description: "Alt+Tab workspace overview: commit on Alt release"

        onPressed: {
            overviewScope.commitAltTab();
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
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