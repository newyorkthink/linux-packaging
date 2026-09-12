# AltTab AppImage

## 用途与产物

本目录将 [sagb/alttab](https://github.com/sagb/alttab) 官方最新稳定 Release 源码编译并封装为 `alttab.AppImage`，用于 X11 窗口切换。

最终产物固定为 `alttab.AppImage`，由 `.github/workflows/build.yml` 中的 `Build AltTab` Job 构建并发布到 `latest` Release。上游主要使用 C、Xlib、Xft、Xrender、Xrandr、libpng、libXpm 和 uthash；本项目额外使用 GLib 解析 desktop 元数据。

## 最终状态

截至 2026-09-12，图标、字体、标题排版和横向导航相关修改已完成收口：

- 宿主 XDG desktop / 图标主题映射正常，PNG / XPM 图标能够正确读取。
- 直接运行的 AppImage 可以从目标进程 `APPDIR`、`.DirIcon` 和 desktop `Icon` 回退读取内嵌图标，并兼容目标进程挂载命名空间。
- 共享 RunImage 中的子程序可以按目标进程实际可执行文件位置读取自身 PNG 图标；Firefox、Zen Browser 等此前缺失的窗口图标已由 Linux 实机确认恢复。
- `-font "xft:MonoLisa-12"` 继续使用 MonoLisa 作为主字体；中文、常用 Unicode 符号和可用私有区字形按备用字体链自动回退。
- 多行标题行距已调整，标题换行按主字体和备用字体实际像素宽度计算；Typora、Zen Browser 等中英混排长标题已由 Linux 实机确认能够正常换行，不再从卡片右侧被裁掉。
- 横向导航增加 `Left` / `h` 上一个、`Right` / `l` 下一个；上游默认 `k` kill key 已取消，显式 `-dk <keysym>` 仍可重新指定。
- 图标、字体和标题排版已完成 Linux 实机确认；包含横向导航与禁用默认 `k` 的最终源码树已由正式 `Build AltTab`（run `34674835800`，attempt 2）成功构建。

以后新增兼容修复必须继续遵循“一类问题一个独立 patch”的结构；已经确认有效的 patch 不回写、不合并、不重写。若后续出现新的键盘行为问题，只新增对应独立 patch，不触碰现有图标、字体和标题排版基线。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `build_alttab.sh` | 获取上游最新稳定 Release、安装依赖、应用补丁、编译并调用 quick-sharun 打包 |
| `apply-icon-patch.sh` | 历史文件名；当前实际按固定顺序应用全部独立兼容 patch |
| `patches/desktop-icons.patch` | 宿主 XDG desktop / 图标主题映射、PNG 尺寸及透明背景处理 |
| `patches/appimage-icons.patch` | 直接运行 AppImage 的 `APPDIR`、`.DirIcon`、desktop `Icon` 回退 |
| `patches/appimage-mount-namespace.patch` | 通过 `/proc/<pid>/root` 访问目标 AppImage 自身挂载视图 |
| `patches/runimage-program-icons.patch` | 共享 RunImage 子程序按目标进程实际可执行文件目录读取内置 PNG 图标 |
| `patches/font-fallback.patch` | MonoLisa 主字体缺字时按固定备用字体链逐字符回退 |
| `patches/glyph-layout.patch` | 固定备用字体仍缺字时由 Fontconfig 动态匹配，并将多行标题行距调整为 `0.5` |
| `patches/title-wrap.patch` | 按实际参与绘制的字体像素宽度计算标题断行 |
| `patches/navigation-keys.patch` | 增加横向辅助导航：`Left` / `h` 上一个，`Right` / `l` 下一个 |
| `patches/disable-default-kill-key.patch` | 禁用上游默认 `k` kill key；显式 `-dk` 仍可重新指定关闭窗口按键 |

## 打包方式

正式构建使用 `.github/workflows/build.yml` 的 `Build AltTab` Job，并复用 `.github/actions/build-anylinux`。quick-sharun / sharun 的实际依赖收集与 AppDir 构建阶段运行在 Arch Linux 环境中。

构建流程：

1. 从 `sagb/alttab` 的 `releases/latest` 获取最新稳定 Release，拒绝 draft / prerelease。
2. 将 Release tag 解析到具体 commit SHA，再按该 commit 下载官方源码归档并输出 SHA-256。
3. 调用 `apply-icon-patch.sh`，依次应用所有独立补丁；任一补丁不匹配时立即停止，不静默跳过。
4. 使用上游 `configure --prefix=/usr` 与 `make` 编译，并加入 GLib 编译 / 链接参数。
5. 生成 `alttab.desktop`，使用上游 `doc/alttab.svg` 作为 AltTab 自身图标。
6. 由 quick-sharun 收集程序与动态依赖，生成 `dist/alttab.AppImage` 并发布到 `latest` Release。

`build_alttab.sh` 不自行锁定 AltTab、quick-sharun 或 sharun 的旧版本；当前供应链下载与校验继续使用现有动态稳定入口和配套校验机制。

## 运行

需要可访问的 X11 会话。下载 Release 产物后，在文件所在目录的 Linux 终端执行：

```bash
# 启动 AltTab 窗口切换器。
./alttab.AppImage
```

现有常用启动参数可继续保持不变，例如：

```bash
# 使用 MonoLisa 12 作为主字体启动 AltTab。
./alttab -d 2 -mk Control_L -b 1 -i 256x64 -t 256x256 -p center -bg "#07001D" -fg "#ec47ff" -frame "#52EFFF" -font "xft:MonoLisa-12"
```

横向窗口切换额外支持 `Left` / `h` 选择上一个窗口、`Right` / `l` 选择下一个窗口；仍需按住主修饰键。原有 `Tab` / `Shift+Tab` 以及 `-pk` / `-nk` 自定义键保持不变。`j` 不额外占用；上游原本默认把 `k` 作为 kill key，本项目现已取消该默认绑定，因此按住主修饰键时 `k` 不再关闭当前选中窗口。如确实需要 kill key，可继续显式使用 `-dk <keysym>` 指定。

## 图标兼容

图标逻辑保持上游 `icon.source` 的 0～5 模式及默认优先级，不按具体应用名称写死规则。

宿主程序首先通过 XDG 数据目录扫描 desktop 文件，并根据文件 ID、`StartupWMClass` 与 `Icon` 映射图标；图标目录同时覆盖当前主题、`hicolor` 和 `pixmaps`。PNG 会先读取真实尺寸再创建画布，避免 legacy pixmaps 被错误按 `1×1` 处理。

宿主图标查找未命中时，AppImage 兼容层读取目标窗口 `_NET_WM_PID` 对应进程环境中的 `APPDIR`。路径优先通过 `/proc/<pid>/root${APPDIR}` 从目标进程自身挂载视图访问，失败时再回退到原始 `${APPDIR}`；随后按 `.DirIcon` → desktop `Icon` 的顺序读取 PNG / XPM，并支持无扩展名 `.DirIcon` 的文件头识别。

共享 RunImage 中的 GUI 子程序可能继承启动器的 `APPDIR` / `APPIMAGE`，因此不能把这些变量直接当作当前窗口程序目录。`runimage-program-icons.patch` 仅在目标进程明确存在 `RUNIMAGE` 时，按 `/proc/<pid>/root` 与实际可执行文件目录寻找程序自带的标准 PNG 图标；该逻辑不修改已经稳定的宿主 XDG / AppImage 图标补丁。

## 字体与标题排版

`-font` 仍只负责指定主字体。以 `xft:MonoLisa-12` 为例，MonoLisa 已有的英文、数字和符号继续由 MonoLisa 绘制；主字体缺字时依次尝试：

`WenQuanYi Zen Hei Mono` → `DejaVu Sans` → `Symbols Nerd Font Mono` → `Symbols Nerd Font`

如果固定备用字体仍不包含目标 Unicode 字符，则由 Fontconfig 按 `charset` 从宿主已安装字体中动态匹配实际包含该字形的字体，并缓存本次进程使用的匹配结果。备用字号跟随主字体，不需要改变启动参数格式。

多行标题行距由上游原值 `0.3` 调整为 `0.5`。标题断行不再只用 MonoLisa 估算整行宽度，而是复用实际字体选择结果，按每个连续字体段的真实 `xOff` 计算像素宽度，因此中文、英文和备用字体混排时也能在卡片边界前正确换行。

## 稳定基线与维护规则

以下内容已经过正式构建和 / 或 Linux 实机确认，后续视为稳定基线：

- `desktop-icons.patch`：宿主 XDG desktop / 图标主题映射。
- `appimage-icons.patch`：AppImage `APPDIR`、`.DirIcon` 与 desktop `Icon` 回退。
- `appimage-mount-namespace.patch`：目标 AppImage 挂载命名空间兼容。
- `runimage-program-icons.patch`：共享 RunImage 子程序图标恢复。
- `font-fallback.patch`：MonoLisa 主字体与固定备用字体链。
- `glyph-layout.patch`：Fontconfig 动态字形回退与 `0.5` 行距。
- `title-wrap.patch`：按实际字体像素宽度计算标题换行。
- `navigation-keys.patch`：横向 `Left` / `h`、`Right` / `l` 导航。
- `disable-default-kill-key.patch`：取消默认 `k` kill key，保留显式 `-dk` 自定义能力。

其中图标、字体和标题排版相关 patch 已完成 Linux 实机确认；键盘导航与默认 kill key 调整已完成正式构建。维护时只允许为新的独立问题新增对应 patch，禁止为了“整理”或“优化”重新改写已验证 patch。补丁路径和应用顺序统一由 `apply-icon-patch.sh` 管理；不得把兼容逻辑重新塞回 `build_alttab.sh`，也不得为验证加入 test workflow、smoke Job 或运行时测试代码。

## 修复记录

### 2026-09-10：宿主与 AppImage 图标兼容

- 现象：部分窗口没有图标，直接运行的 AppImage 尤其容易出现空白图标。
- 根因：上游缺少完整 desktop 图标映射，且宿主图标索引无法覆盖只存在于 AppImage 运行时挂载目录中的资源。
- 修改文件：`patches/desktop-icons.patch`、`patches/appimage-icons.patch`、`apply-icon-patch.sh`、`build_alttab.sh`、`README.md`。
- 修复内容：增加 XDG desktop / `StartupWMClass` / `Icon` 映射、PNG 真实尺寸处理、`.DirIcon` / desktop `Icon` 回退和无扩展名 PNG / XPM 内容识别。
- 已知结果：Linux 实机确认宿主应用和普通 AppImage 图标能够正常显示，该逻辑设为稳定基线。

### 2026-09-12：中文、符号与多行标题排版

- 现象：使用 MonoLisa 时中文缺字，部分符号显示方框；长标题第二行间距偏紧，中英混排标题可能从右侧被裁掉。
- 根因：MonoLisa 不包含中文字形；固定单一备用字体无法覆盖全部字符；原 `drawMultiLine()` 只按主字体估算换行宽度。
- 修改文件：`patches/font-fallback.patch`、`patches/glyph-layout.patch`、`patches/title-wrap.patch`、`apply-icon-patch.sh`、`README.md`。
- 修复内容：增加固定备用字体链和 Fontconfig 动态回退，将行距调整为 `0.5`，并按实际参与绘制的字体宽度计算断行。
- 已知结果：Linux 实机确认中文正常显示，多行标题间距正常，Typora、Zen Browser 等长标题能够正确换行。

### 2026-09-12：AppImage 挂载命名空间与共享 RunImage 子程序图标

- 现象：宿主图标正常时，部分 AppImage / 共享 RunImage 浏览器子程序仍可能出现空白图标。
- 根因：目标进程的挂载视图可能与 AltTab 不一致；共享 RunImage 子程序还可能继承启动器的 `APPDIR` / `APPIMAGE`，无法据此定位自身程序资源。
- 修改文件：`patches/appimage-mount-namespace.patch`、`patches/runimage-program-icons.patch`、`apply-icon-patch.sh`、`README.md`。
- 修复内容：通过 `/proc/<pid>/root` 访问目标进程可见路径，并在明确存在 `RUNIMAGE` 时按目标进程实际可执行文件目录补充 PNG 图标回退。
- 已知结果：Linux 实机确认 Firefox、Zen Browser 等此前缺失的共享 RunImage 子程序图标恢复，其他已正常图标保持正常。

### 2026-09-12：最终验收

- 现象：前述图标、字体和标题排版问题已全部进入最终核对阶段。
- 根因：无新增故障，本次只做最终状态确认和文档收口。
- 修改文件：`README.md`。
- 修复内容：整理最终技术说明、独立 patch 对应关系、稳定基线和已确认结果，不改任何已验证源码补丁、构建脚本或 workflow。
- 已知结果：正式 `Build AltTab` 构建成功；Linux 实机最终截图确认宿主 / AppImage / 共享 RunImage 图标正常，MonoLisa + 中文字体回退正常，中英混排长标题换行正常。本轮图标与字体兼容工作结束。

### 2026-09-12：补充横向键盘导航

- 现象：横向 AltTab 需要同时支持方向键和 Vim 风格 `h` / `l` 左右移动；上游 `-pk` / `-nk` 每个方向只能配置一个 keysym，无法仅靠启动参数同时绑定两组键。
- 根因：辅助上一个 / 下一个窗口逻辑只识别各一个可配置 KeyCode，UI 显示期间也只抓取这两个辅助键。
- 修改文件：新增 `patches/navigation-keys.patch`，并修改 `apply-icon-patch.sh`、`README.md`；既有图标、字体、字形和标题换行 patch 均保持不变。
- 修复内容：保留原 `-pk` / `-nk` 行为，额外将 `Left` / `h` 映射为上一个窗口、`Right` / `l` 映射为下一个窗口；抓键时跳过重复 KeyCode，避免与用户自定义辅助键重复。
- 已知结果：最终源码树已由正式 `Build AltTab`（run `34674835800`，attempt 2）成功构建；运行时键位行为继续以实际使用反馈为准。

### 2026-09-12：禁用默认 `k` 关闭窗口

- 现象：按住主修饰键时按 `k` 会导致当前选中窗口被关闭，随后可出现 `BadValue` / `BadWindow` 等 X11 错误；这与预期的“`j` / `k` 不参与导航”不一致。
- 根因：上游默认定义 `DEFKILLKS` 为 `XK_k`，主事件循环在按住主修饰键时会把该键交给 `uiKillWindow()`，因此 `k` 并非未占用，而是默认 kill key。
- 修改文件：新增 `patches/disable-default-kill-key.patch`，并修改 `apply-icon-patch.sh`、`README.md`；既有图标、字体、字形、标题换行与横向导航 patch 均保持不变。
- 修复内容：仅将默认 kill keysym 从 `XK_k` 改为 `XK_VoidSymbol`，使默认 `k` 不再关闭选中窗口；原有 `-dk <keysym>` 参数保留，需要 kill key 时仍可显式指定。
- 已知结果：根因已由上游源码和真实运行反馈确认；包含该补丁的最终源码树已由正式 `Build AltTab`（run `34674835800`，attempt 2）成功构建。新补丁只改变默认 kill key，不改变图标、字体、换行或 `h` / `l`、Left / Right 导航逻辑。