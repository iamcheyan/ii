import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool overviewGrabbed: false

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null

    signal requestOverviewFocus()

    function overviewModel() {
        return HyprlandData.overviewWorkspaceEntriesGlobal();
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
        const ws = HyprlandData.workspaceDataForId(wsId);
        if (ws?.monitor)
            Hyprland.dispatch(`hl.dsp.focus({monitor="${ws.monitor}"})`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
    }

    function selectOverviewWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewFocusedWorkspaceId = wsId;
    }

    function navigateOverviewByIndex(delta) {
        const model = overviewScope.overviewModel();
        if (model.length === 0)
            return;

        const ws = overviewScope.overviewFocusedWorkspaceId();
        let idx = overviewScope.overviewIndexForWorkspace(model, ws);
        idx = (idx + delta + model.length) % model.length;
        overviewScope.selectOverviewWorkspace(model[idx].id);
    }

    function focusedEntryIsTrailingEmpty() {
        const wsId = overviewScope.overviewFocusedWorkspaceId();
        if (wsId < 1)
            return false;
        const model = overviewScope.overviewModel();
        for (let i = 0; i < model.length; i++) {
            if (model[i].id === wsId)
                return !!model[i].isTrailingEmpty;
        }
        return false;
    }

    function navigateOverviewGrid(deltaRow, deltaCol) {
        const model = overviewScope.overviewModel();
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
        if (overviewScope.focusedEntryIsTrailingEmpty()) {
            // Focus a fresh empty workspace (numbers can be irregular across monitors)
            // and automatically open the app launcher so the user can pick what to run.
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "empty" })`);
            overviewScope.overviewGrabbed = false;
            GlobalStates.overviewOpen = false;
            GlobalStates.appLauncherOpen = true;
            return;
        }
        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            overviewScope.dispatchFocusWorkspace(GlobalStates.overviewFocusedWorkspaceId);
        overviewScope.overviewGrabbed = false;
        GlobalStates.overviewOpen = false;
    }

    function overviewNavigationActive() {
        return GlobalStates.overviewOpen;
    }

    function handleOverviewNavigationKey(event) {
        if (!overviewScope.overviewNavigationActive())
            return;

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

    function isFocusedScreen(screen) {
        return screen?.name === overviewScope.focusedScreen?.name;
    }

    function currentWorkspaceId() {
        const monitor = Hyprland.focusedMonitor ?? Hyprland.monitors[0];
        if (!monitor)
            return HyprlandData.activeWorkspace?.id ?? 1;
        return HyprlandData.monitorActiveWorkspaceId(monitor) || HyprlandData.activeWorkspace?.id || 1;
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (GlobalStates.overviewOpen)
                Qt.callLater(() => overviewScope.requestOverviewFocus());
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: overviewPanelLoader
            required property ShellScreen modelData
            active: true

            component: PanelWindow {
            id: panelWindow
            screen: overviewPanelLoader.modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            readonly property bool isFocusedOverviewWindow: overviewScope.isFocusedScreen(panelWindow.screen)
            visible: GlobalStates.overviewOpen

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: panelWindow.isFocusedOverviewWindow
                ? (overviewScope.overviewGrabbed
                    ? WlrKeyboardFocus.Exclusive
                    : (GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None))
                : WlrKeyboardFocus.None
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
                        GlobalStates.overviewDraggingFromWorkspace = -1;
                        GlobalStates.overviewDraggingTargetWorkspace = -1;
                        GlobalStates.overviewDraggingTargetIsTrailing = false;
                        GlobalFocusGrab.dismiss();
                    } else {
                        GlobalStates.overviewFocusedWorkspaceId = overviewScope.currentWorkspaceId();
                        if (panelWindow.isFocusedOverviewWindow && !overviewScope.overviewGrabbed)
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

            Item {
                id: overviewKeyHandler
                anchors.fill: parent
                z: 999
                focus: panelWindow.isFocusedOverviewWindow
                    && (overviewScope.overviewNavigationActive() || overviewScope.overviewGrabbed)

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
                        if (panelWindow.isFocusedOverviewWindow
                            && (overviewScope.overviewNavigationActive() || overviewScope.overviewGrabbed))
                            overviewKeyHandler.forceActiveFocus();
                    }
                    function onOverviewGrabbedChanged() {
                        if (panelWindow.isFocusedOverviewWindow && overviewScope.overviewGrabbed)
                            overviewKeyHandler.forceActiveFocus();
                    }
                }
            }

            StyledFlickable {
                id: columnLayout
                visible: GlobalStates.overviewOpen
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                clip: true
                readonly property real availableHeight: panelWindow.height * 0.85
                implicitWidth: overviewLoader.implicitWidth
                implicitHeight: visible
                    ? Math.min(overviewLoader.implicitHeight, Math.max(0, availableHeight))
                    : 0
                width: implicitWidth
                height: implicitHeight
                contentWidth: width
                contentHeight: overviewLoader.implicitHeight

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        GlobalStates.overviewOpen = false;
                }

                Loader {
                    id: overviewLoader
                    active: GlobalStates.overviewOpen && (Config?.options.overview.enable ?? true)
                    sourceComponent: OverviewWidget {
                        screen: panelWindow.screen
                        visible: GlobalStates.overviewOpen
                    }
                }
            }
        }
        }
    }

    IpcHandler {
        target: "overview"

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
}
