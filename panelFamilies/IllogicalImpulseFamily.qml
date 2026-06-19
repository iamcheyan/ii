import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.appLauncher
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.schedulePopup
import qs.modules.ii.screenCorners
import qs.modules.ii.screenTranslator
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarRight
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector

Scope {
    id: family

    readonly property bool staggerPanels: Config.options?.startup?.staggerPanelLoading ?? true
    property bool tier1Ready: !family.staggerPanels
    property bool tier2Ready: !family.staggerPanels

    Timer {
        interval: Config.options?.startup?.tier1DelayMs ?? 1500
        running: Config.ready && family.staggerPanels
        repeat: false
        onTriggered: family.tier1Ready = true
    }

    Timer {
        interval: Config.options?.startup?.tier2DelayMs ?? 6000
        running: Config.ready && family.staggerPanels
        repeat: false
        onTriggered: family.tier2Ready = true
    }

    // Tier 0 — 立即可见的核心 UI
    PanelLoader { extraCondition: !Config.options.bar.vertical; component: Bar {} }
    PanelLoader { extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
    PanelLoader { component: Background {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: SchedulePopup {} }
    PanelLoader { component: Lock {} }

    // Tier 1 — 含全局快捷键，略延迟以让出 CPU
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Overview {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: AppLauncher {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: RegionSelector {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: SessionScreen {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Cheatsheet {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: OnScreenKeyboard {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Polkit {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: SidebarRight {}
    }

    // Tier 2 — 低频或重型模块
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        extraCondition: Config.options.dock.enable
        component: Dock {}
    }
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: MediaControls {}
    }
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Overlay {}
    }
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: ScreenTranslator {}
    }
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: WallpaperSelector {}
    }
}
