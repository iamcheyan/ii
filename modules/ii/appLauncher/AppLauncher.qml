import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: launcher
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.appLauncherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; left: true; right: true; bottom: true }

    visible: GlobalStates.appLauncherOpen

    readonly property string fontStack: (Appearance?.font?.family?.main ?? "sans-serif") + ", Noto Sans CJK SC, Noto Sans CJK TC, Noto Sans CJK JP, WenQuanYi Micro Hei, Source Han Sans SC, Source Han Sans TC, MesloLGS Nerd Font Mono, Cantarell, Inter, Open Sans, MesloLGS NF, Ubuntu Nerd Font, Ubuntu, Noto Sans Mono, sans-serif"
    readonly property string stateDir: Quickshell.shellDir + "/.state"
    readonly property string stateFile: stateDir + "/pinned-apps"

    function run(command) { Quickshell.execDetached(["sh", "-c", command]); }

    function quote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function iconSource(icon) {
        if (!icon) return "";
        if (icon.startsWith("/")) return "file://" + icon;
        const resolved = Quickshell.iconPath(icon, true);
        if (resolved.startsWith("/")) return "file://" + resolved;
        if (resolved) return resolved;
        return "";
    }

    property var pinnedIds: ({})
    property var allApps: []
    property var filteredApps: []

    // Set of currently running window classes (mapped, not hidden).
    property var runningSet: ({})

    function updateRunningSet() {
        const set = {};
        const wl = HyprlandData.windowList || [];
        for (let i = 0; i < wl.length; i++) {
            const w = wl[i];
            if (!w || !w.mapped || w.hidden) continue;
            const cls = (w.class || "").toLowerCase();
            const initial = (w.initialClass || "").toLowerCase();
            if (cls) set[cls] = true;
            if (initial) set[initial] = true;
        }
        launcher.runningSet = set;
    }

    // Returns true if a desktop entry appears to have at least one running window.
    function isAppRunning(app) {
        const set = launcher.runningSet;
        if (!set) return false;
        let any = false;
        for (const _ in set) { any = true; break; }
        if (!any) return false;

        const id = (app.id || "").split("/").pop().split(".").pop().toLowerCase();
        let exec = (app.execString || "").split(" ")[0].split("/").pop().toLowerCase();
        // Strip common suffixes like "-stable", "-bin"
        const stripped = exec.replace(/-stable$/, "").replace(/-bin$/, "").replace(/^env-/, "");
        const candidates = [id, exec, stripped];
        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i];
            if (!c) continue;
            if (set[c]) return true;
        }
        // Fuzzy: does any running class contain the app id, or vice versa?
        for (const k in set) {
            if (!k) continue;
            if (k === id || k === exec || k === stripped) return true;
            if (id && (k.indexOf(id) >= 0 || id.indexOf(k) >= 0)) return true;
            if (exec && (k.indexOf(exec) >= 0 || exec.indexOf(k) >= 0)) return true;
        }
        return false;
    }

    function loadPinnedIds() {
        pinnedLoadProcess.running = false;
        pinnedLoadProcess.running = true;
    }

    function loadApps() {
        const entries = DesktopEntries.applications.values;
        const apps = [];
        for (let i = 0; i < entries.length; i++) {
            const app = entries[i];
            if (!app || app.noDisplay || !app.name) continue;
            apps.push(app);
        }
        allApps = apps;
    }

    function savePinnedIds() {
        const ids = [];
        for (const id in pinnedIds) {
            if (pinnedIds[id]) ids.push(id);
        }
        ids.sort();
        const payload = ids.join("\n") + (ids.length > 0 ? "\n" : "");
        launcher.run("mkdir -p " + quote(stateDir) + " && printf %s " + quote(payload) + " > " + quote(stateFile));
    }

    function togglePinned(id) {
        const copy = Object.assign({}, pinnedIds);
        if (copy[id]) delete copy[id];
        else copy[id] = true;
        pinnedIds = copy;
        savePinnedIds();
    }

    function buildFilteredList() {
        const q = searchField.text.toLowerCase().trim();
        const pinned = [];
        const unpinned = [];
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            const haystack = [
                app.name,
                app.id,
                app.execString,
                app.genericName,
                app.comment,
                (app.keywords || []).join(" ")
            ].join(" ").toLowerCase();
            if (q !== "" && haystack.indexOf(q) < 0) continue;
            if (pinnedIds[app.id]) pinned.push(app);
            else unpinned.push(app);
        }
        function byName(a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0; }
        pinned.sort(byName);
        unpinned.sort(byName);
        filteredApps = pinned.concat(unpinned);
    }

    onAllAppsChanged: buildFilteredList()
    onPinnedIdsChanged: buildFilteredList()

    Process {
        id: pinnedLoadProcess
        command: ["sh", "-c", "cat " + launcher.quote(launcher.stateFile) + " 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const id = lines[i].trim();
                    if (id !== "") ids[id] = true;
                }
                launcher.pinnedIds = ids;
            }
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            if (launcher.visible) launcher.loadApps();
        }
    }

    Connections {
        target: HyprlandData

        function onWindowListChanged() {
            launcher.updateRunningSet();
        }
    }

    onVisibleChanged: {
        if (visible) {
            updateRunningSet();
            loadPinnedIds();
            loadApps();
            searchField.text = "";
            Qt.callLater(function() {
                searchField.forceActiveFocus();
                if (Qt.inputMethod) Qt.inputMethod.show();
            });
        } else {
            if (Qt.inputMethod) Qt.inputMethod.hide();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: GlobalStates.appLauncherOpen = false
    }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width:  Math.min(parent.width  * 0.72, 960)
            height: Math.min(parent.height * 0.80, 720)
            color: "#0d0d0f"
            radius: 16
            border.color: "#22ffffff"
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: "#18ffffff"
                    border.color: searchField.activeFocus ? "#3b82f6" : "#22ffffff"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: 16
                            color: "#70ffffff"
                        }

                        Item {
                            width: parent.width - 40
                            height: parent.height

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 0
                                verticalAlignment: Text.AlignVCenter
                                visible: searchField.text === ""
                                text: "Type to search apps\u2026"
                                color: "#44ffffff"
                                font.family: launcher.fontStack
                                font.pixelSize: 14
                            }

                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                color: "#f0f0f5"
                                selectionColor: "#3b82f6"
                                font.family: launcher.fontStack
                                font.pixelSize: 14
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: launcher.buildFilteredList()
                                Keys.onEscapePressed: GlobalStates.appLauncherOpen = false
                                Keys.onReturnPressed: {
                                    if (launcher.filteredApps.length > 0) {
                                        launcher.filteredApps[0].execute();
                                        GlobalStates.appLauncherOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: {
                        for (const k in launcher.pinnedIds) { if (launcher.pinnedIds[k]) return true; }
                        return false;
                    }
                    text: "  Pinned"
                    color: "#60ffffff"
                    font.family: launcher.fontStack
                    font.pixelSize: 11
                    Layout.leftMargin: 6
                    Layout.rightMargin: 22
                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 22

                        cellWidth:  110
                        cellHeight: 120
                        model: launcher.filteredApps
                        clip: true

                        boundsBehavior: Flickable.StopAtBounds
                        boundsMovement: Flickable.StopAtBounds
                        flickDeceleration: 2800
                        maximumFlickVelocity: 5200
                        reuseItems: true

                        delegate: Item {
                            id: appItem
                            width:  grid.cellWidth
                            height: grid.cellHeight

                            required property var modelData
                            required property int index

                            property bool isPinned: !!launcher.pinnedIds[modelData.id]
                            property bool isRunning: launcher.isAppRunning(modelData)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: 12
                                color: ma.containsMouse ? "#16ffffff" : "transparent"
                                border.color: ma.containsMouse ? "#10ffffff" : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }

                            Rectangle {
                                id: pinBadge
                                visible: ma.containsMouse || appItem.isPinned
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 6
                                anchors.rightMargin: 6
                                width: 24; height: 24
                                radius: 12
                                color: appItem.isPinned ? "#3b82f6" : "#40000000"
                                border.color: "#60ffffff"
                                border.width: 1
                                z: 2

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on visible { NumberAnimation { property: "opacity"; duration: 80 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    fill: appItem.isPinned ? 1 : 0
                                    text: "keep"
                                    iconSize: 13
                                    color: "#ffffff"
                                }
                            }

                            Item {
                                id: iconWrapper
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                width: 54; height: 54

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: launcher.iconSource(appItem.modelData.icon)
                                    implicitSize: 54
                                    asynchronous: true
                                    mipmap: true
                                }

                                Rectangle {
                                    visible: appIcon.status !== Image.Ready
                                    anchors.fill: parent
                                    radius: 13
                                    color: "#1e3a5f"
                                    Text {
                                        anchors.centerIn: parent
                                        text: appItem.modelData.name.charAt(0).toUpperCase()
                                        font.family: launcher.fontStack
                                        font.pixelSize: 22
                                        font.weight: Font.Bold
                                        color: "#93c5fd"
                                    }
                                }
                            }

                            // Running indicator: small yellow dot centered under the icon.
                            Rectangle {
                                visible: appItem.isRunning
                                anchors.top: iconWrapper.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 8; height: 8
                                radius: 4
                                color: "#ffc23a"
                                border.color: "#803a2400"
                                border.width: 1
                                z: 1
                            }

                            Text {
                                id: appLabel
                                anchors.top: iconWrapper.bottom
                                anchors.topMargin: 18
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: appItem.modelData.name
                                font.family: launcher.fontStack
                                font.pixelSize: 11
                                color: ma.containsMouse ? "#ffffff" : "#dde0ec"
                                lineHeight: 1.2
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            // Single MouseArea for the entire cell. Badge click is detected by
                            // mapping the click position into the badge's coordinate system, so the
                            // badge never steals hover and ma.containsMouse stays stable.
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                z: 1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    const localPinPos = mapToItem(pinBadge, mouse.x, mouse.y);
                                    if (localPinPos.x >= 0 && localPinPos.x <= pinBadge.width &&
                                        localPinPos.y >= 0 && localPinPos.y <= pinBadge.height) {
                                        launcher.togglePinned(appItem.modelData.id);
                                        return;
                                    }
                                    appItem.modelData.execute();
                                    GlobalStates.appLauncherOpen = false;
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: scrollTrack
                        readonly property int columnCount: Math.max(1, Math.floor(grid.width / grid.cellWidth))
                        readonly property int rowCount: Math.ceil(launcher.filteredApps.length / columnCount)
                        readonly property real calculatedContentHeight: Math.max(grid.height, rowCount * grid.cellHeight)
                        readonly property real scrollableHeight: Math.max(0, calculatedContentHeight - grid.height)
                        readonly property real thumbRange: Math.max(0, height - scrollThumb.height)
                        readonly property real thumbHeight: Math.min(height, Math.max(36, height * grid.height / calculatedContentHeight))

                        visible: scrollableHeight > 1
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        width: 8
                        radius: 4
                        color: "#16ffffff"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                const target = Math.max(0, mouse.y - scrollThumb.height / 2);
                                grid.contentY = Math.max(0, Math.min(1, target / Math.max(1, scrollTrack.thumbRange))) * scrollTrack.scrollableHeight;
                            }
                        }

                        Rectangle {
                            id: scrollThumb
                            width: 6
                            x: 1
                            height: scrollTrack.thumbHeight
                            radius: 3
                            color: thumbDrag.containsMouse || thumbDrag.pressed ? "#a8c7ff" : "#80ffffff"

                            property bool dragging: false

                            Binding {
                                target: scrollThumb
                                property: "y"
                                when: !scrollThumb.dragging
                                value: scrollTrack.scrollableHeight > 0
                                    ? Math.max(0, Math.min(1, grid.contentY / scrollTrack.scrollableHeight)) * scrollTrack.thumbRange
                                    : 0
                            }

                            MouseArea {
                                id: thumbDrag
                                anchors.fill: parent
                                hoverEnabled: true
                                drag.target: scrollThumb
                                drag.axis: Drag.YAxis
                                drag.minimumY: 0
                                drag.maximumY: scrollTrack.thumbRange

                                onPressed: scrollThumb.dragging = true
                                onReleased: scrollThumb.dragging = false
                                onCanceled: scrollThumb.dragging = false
                                onPositionChanged: {
                                    if (!pressed) return;
                                    grid.contentY = Math.max(0, Math.min(1, scrollThumb.y / Math.max(1, scrollTrack.thumbRange))) * scrollTrack.scrollableHeight;
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: launcher.filteredApps.length + " apps"
                    color: "#38ffffff"
                    font.family: launcher.fontStack
                    font.pixelSize: 10
                }
            }
        }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }

        function close(): void {
            GlobalStates.appLauncherOpen = false;
        }

        function open(): void {
            GlobalStates.appLauncherOpen = true;
        }
    }
}