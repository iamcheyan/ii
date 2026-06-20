# Win+Tab 切换器 — 窗口拖拽失效问题记录

> 记录时间：2026-06-20
> 状态：**未解决**

---

## 预期行为

在 Win+Tab 工作区切换器（`overviewAltTabMode = true`）里：
- 鼠标移上窗口缩略图 → 高亮 + 显示窗口标题 tooltip ✅（已修复）
- 鼠标拖拽窗口缩略图 → 移动到另一个工作区 ❌（仍然失效）
- 点击窗口缩略图 → 切换到该窗口 ❌（仍然失效）

普通工作区 Overview（非 alt-tab 模式）的拖拽点击均正常。

---

## 根本区别：普通 Overview vs Win+Tab

| | 普通 Overview | Win+Tab |
|---|---|---|
| `overviewAltTabMode` | `false` | `true` |
| `WlrKeyboardFocus` | `OnDemand` | `Exclusive` |
| Hyprland submap | 默认 | `overview-alt-tab` |
| mask item | `columnLayout` | `columnLayout`（已改） |

---

## 已尝试的修复（均无效）

### 1. mask 改为 columnLayout（commit 9703ccf）
原来 alt-tab 模式 mask 用 `altTabKeyHandler`（全屏 Item，z:1000），改为 `columnLayout`。
- 结果：hover 恢复，但拖拽仍不行。

### 2. 禁用 altTabKeyHandler MouseArea hoverEnabled（commit 834b786）
- 结果：hover/tooltip 恢复，拖拽仍不行。

### 3. 把 altTabKeyHandler MouseArea 换成 WheelHandler（commit cf3fc3c）
MouseArea 即使 `Qt.NoButton` 也参与 hit-test，换成 WheelHandler 不参与。
- 结果：拖拽仍不行。

### 4. 删除 submap 里的 SUPER+mouse 绑定
原来 submap 里有 `SUPER + mouse:272/273/274 → exec_cmd("true")`，会吃掉事件。删掉后 reload。
- 结果：拖拽仍不行。

---

## 当前怀疑点（未验证）

### 怀疑 A：WlrKeyboardFocus.Exclusive 影响鼠标事件
Alt-tab 模式下用 `WlrKeyboardFocus.Exclusive`。Quickshell/wlr-layer-shell 的 Exclusive 键盘焦点是否同时影响了鼠标事件的路由？需要查 Quickshell 文档。

**测试方法**：临时把 alt-tab 模式的 keyboardFocus 改为 `OnDemand`，看拖拽是否恢复。

### 怀疑 B：Hyprland submap 里缺少 catchall，鼠标事件被默认行为处理
在 `overview-alt-tab` submap 中，未绑定的按键是否会被 Hyprland 拦截而不传递给 wayland client？

**测试方法**：在 submap 里加 `hl.bind("mouse:272", hl.dsp.exec_cmd("true"), { mouse = true, transparent = true })` 看是否不同。

### 怀疑 C：dragArea 的 `drag.target` 在 alt-tab 模式下有额外条件阻止
OverviewWidget 里 `dragArea` 的 MouseArea 是否有 `enabled` 或其他条件在 alt-tab 模式下为 false？
上次发现背景 MouseArea 有 `enabled: root.overviewNavigationActive || GlobalStates.overviewAltTabMode`，但 dragArea 是否也有类似条件未查完。

**测试方法**：检查 OverviewWidget.qml 里 `dragArea` MouseArea 的完整定义，确认无 enabled 条件。

### 怀疑 D：altTabKeyHandler Item z:1000 本身（不含 MouseArea）阻止了事件
即使去掉 MouseArea，Item 本身的 z:1000 在 Qt Quick 里是否仍然影响事件路由？

**测试方法**：临时把 `altTabKeyHandler` 的 `z` 改为 0 或 -1。

---

## 相关代码位置

| 文件 | 关键位置 |
|------|---------|
| `modules/ii/overview/Overview.qml` | `PanelWindow` mask、`WlrKeyboardFocus`、`altTabKeyHandler` |
| `modules/ii/overview/OverviewWidget.qml` | 窗口 Repeater delegate、`dragArea` MouseArea（约第 352 行） |
| `~/.config/hypr/hyprland/keybinds.lua` | `overview-alt-tab` submap 定义 |

---

## 下一步建议

按怀疑 A → D 顺序逐一验证，最快的是先改 `keyboardFocus` 测试。
