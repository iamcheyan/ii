# Win+Tab 工作区切换器 — grabbed 模式松开 Win 不关闭问题

> 记录时间：2026-06-20
> 状态：**已解决**

---

## 预期行为

按住 Win+Tab 打开工作区切换器，按 Tab 循环，松开 Win 键后 overview 自动关闭。

## 问题现象

松开 Win 键后 overview 不关闭，一直停留在屏幕上。

## 根因

Win+Tab grabbed 模式下用 `WlrKeyboardFocus.Exclusive` 抢键盘焦点。松开 Win 时两条 commit 路径都失效：

### 路径 1：`Keys.onReleased` 检测 Super release（失效）

Exclusive 焦点下，modifier key 的 release 事件被 Hyprland 自己消费（用于 `bindr` 匹配），不传递给 wayland client 的 `Keys.onReleased`。

实测日志：`Keys.onPressed key=16777216`（Meta press）能收到，但对应的 release 事件从未到达 `Keys.onReleased`。

### 路径 2：`bindr SUPER+SUPER_L → overviewCommit` GlobalShortcut（失效）

Hyprland 的 `bindr = SUPER, Super_L` 语义：仅在 `Super_L` release **且 SUPER 修饰键仍处于按下状态**时触发。但 SUPER 修饰键本身就是 `Super_L`，松开 `Super_L` 时没有其他 SUPER 键同时按住，所以 `bindr` 不触发。

参考实现（`dotfiles/TWM/qs`）的 `bindr = $mod, Super_L` 也有同样问题，但它主要靠 `Keys.onReleased` 检测，`bindr` 只是 fallback。在 ii 配置里 `Keys.onReleased` 也失效了，所以两条路都断。

## 修复方案

利用 `GlobalStates.qml` 里已有的 `workspaceNumber` GlobalShortcut，它用 `bind SUPER_L release`（**不带 SUPER modifier**，`ignore_mods=true`），能可靠地在 Win 松开时设 `superDown=false`。

在 `Overview.qml` 的 `overviewKeyHandler` 里加 `Connections` 监听 `GlobalStates.onSuperDownChanged`，当 `overviewGrabbed=true` 且 `superDown` 变 `false` 时调用 `commitGrabbedMode()`。

```qml
// modules/ii/overview/Overview.qml — overviewKeyHandler 内
Connections {
    target: GlobalStates
    function onSuperDownChanged() {
        if (overviewScope.overviewGrabbed && !GlobalStates.superDown)
            overviewScope.commitGrabbedMode();
    }
}
```

```qml
// GlobalStates.qml — 已有的可靠 Win 释放检测
GlobalShortcut {
    name: "workspaceNumber"
    onPressed: { root.superDown = true }
    onReleased: { root.superDown = false }
}
```

```lua
-- keybinds.lua — 不带 SUPER modifier，用 ignore_mods
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"),
    { ignore_mods = true, transparent = true, release = true })
```

## 为什么这个方案可靠

- `bind SUPER_L release`（无 SUPER modifier）不要求 SUPER 修饰键同时按住，只要 `Super_L` 本身松开就触发
- `ignore_mods=true` 让它在任何修饰键组合下都触发（包括 Tab 还按着的情况）
- `superDown` 是全局状态，不受 Exclusive 键盘焦点影响
- 不依赖被 Hyprland 吃掉的 `Keys.onReleased` 事件

## 相关代码位置

| 文件 | 关键位置 |
|------|---------|
| `modules/ii/overview/Overview.qml` | `openGrabbedMode`、`commitGrabbedMode`、`overviewKeyHandler` 内 `onSuperDownChanged` Connections |
| `GlobalStates.qml` | `superDown` property、`workspaceNumber` GlobalShortcut |
| `~/.config/hypr/hyprland/keybinds.lua` | `SUPER_L release → workspaceNumber` bind |

## 参考

- 参考实现：`dotfiles/TWM/qs/shell.qml` + `WorkspaceOverview.qml`（用 `Keys.onReleased` 检测，ii 配置需用 `superDown` 绕过 Exclusive 焦点问题）
- Hyprland `bindr` 语义：`bindr MOD, KEY` 要求 KEY release 时 MOD 仍按下
