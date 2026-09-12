# AltTab AppImage

## 用途与技术栈

本目录将 [sagb/alttab](https://github.com/sagb/alttab) 官方最新稳定 Release 源码编译并封装为 `alttab.AppImage`，用于 X11 窗口切换。

上游使用 C、Xlib、Xft、Xrender、Xrandr、libpng、libXpm 和 uthash；图标补丁额外使用 GLib 解析 desktop 文件。构建架构取当前 runner 的 `uname -m`，不交叉编译。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `build_alttab.sh` | 获取稳定版源码、安装构建依赖、调用补丁脚本、编译和打包 |
| `apply-icon-patch.sh` | 接收源码目录，依次应用本目录维护的源码补丁 |
| `patches/desktop-icons.patch` | 对上游 `src/icon.c` 的宿主 desktop / 图标查找与 PNG 处理修复 |
| `patches/appimage-icons.patch` | 对上游 `src/win.c` 的运行中 AppImage 内嵌图标回退 |
| `patches/font-fallback.patch` | 对上游 Xft 文本绘制增加逐字符缺字回退，中文与常用符号分别使用可用备用字体 |
| `patches/glyph-layout.patch` | 固定备用字体仍缺字时交给 Fontconfig 按字符自动匹配宿主字体，并增大多行标题行距 |

以后修改对应逻辑时维护各自 `.patch` 文件；补丁路径和应用顺序由 `apply-icon-patch.sh` 管理，不再把大段补丁放进构建脚本。

## 打包流程

正式构建使用 `.github/workflows/build.yml` 的 AltTab Job，并复用 `.github/actions/build-anylinux`，在 Arch Linux / AnyLinux 构建环境中执行。手动构建入口选择 `alttab/build_alttab.sh`。

1. 从官方 `releases/latest` 获取非草稿、非预发布版本，将 tag 解析为具体 commit SHA，下载该 commit 的源码归档并记录 SHA-256。
2. 调用 `apply-icon-patch.sh`，依次向本次解压的源码应用 `patches/desktop-icons.patch`、`patches/appimage-icons.patch`、`patches/font-fallback.patch` 和 `patches/glyph-layout.patch`。任一补丁不匹配时停止构建，不静默跳过，也不回退到旧版。
3. 使用现有 `configure --prefix=/usr` 和 `make` 编译，传入 GLib 的头文件及链接参数。
4. 生成 desktop 文件，使用上游 `doc/alttab.svg` 作为应用自身图标，将主程序与动态依赖交给 quick-sharun，并保留上游 GPL-3.0 许可证。
5. 生成 `dist/alttab.AppImage`；公共构建 Action 将其上传至仓库 `latest` Release，资产名固定为 `alttab.AppImage`。

sharun 下载来源与 SHA-256 由当前 quick-sharun 配套管理；`build_alttab.sh` 不再覆盖 `SHARUN_LINK`，避免自定义下载地址与 quick-sharun 内置校验和不匹配。

构建脚本、补丁脚本和补丁文件需要一起保留。构建流程由现有 Action 在应用目录内执行；无需在真实主机上运行依赖安装或打包命令。

## 运行、字体与图标兼容

需要可访问的 X11 会话。下载产物后，在文件所在目录的 Linux 终端执行；文件需已有执行权限：

```bash
# 启动 AltTab 窗口切换器。
./alttab.AppImage
```

字体兼容：`-font` 仍只指定主字体。主字体存在字形时保持使用主字体；缺字时先按 `WenQuanYi Zen Hei Mono` → `DejaVu Sans` → `Symbols Nerd Font Mono` → `Symbols Nerd Font` 的顺序逐字符查找备用字体；这些固定备用字体仍缺字时，再让 Fontconfig 根据该 Unicode 字符从宿主已安装字体中自动匹配实际包含字形的字体。备用字号跟随主字体。这样可继续使用 `xft:MonoLisa-12` 显示英文和数字，同时覆盖中文、常用 Unicode 符号和宿主已安装字体提供的私有区图标，不需要改变启动参数格式。多行窗口标题的行距由上游原值 `0.3` 调整为 `0.5`，避免第二行与第一行过于贴近。

保留上游 `icon.source` 的 0～5 全部模式及默认策略，不额外修改窗口自身图标与文件图标之间的上游优先级。文件图标兼容逻辑补充以下处理：

- 按 XDG 数据目录查找 desktop 文件，通过文件 ID、`StartupWMClass` 与 `Icon` 映射宿主图标；只读取元数据，不执行 `Exec`。
- 查找用户及系统图标目录，并补充 `hicolor` 回退；避免直接修改进程的 `XDG_DATA_DIRS` 环境字符串。
- 支持映射到已有 PNG / XPM 图标，以及 PNG / XPM 绝对路径。PNG 使用文件头中的真实尺寸创建画布，并修正透明背景颜色转换。
- 宿主图标查找没有命中时，根据目标窗口的 `_NET_WM_PID` 读取该进程的 `APPDIR`，优先使用运行中 AppImage 根目录的 `.DirIcon`；支持 `.DirIcon` 为普通文件或符号链接，并通过文件内容识别无扩展名 PNG / XPM；再回退读取根目录 desktop 的 `Icon` 对应 PNG / XPM 文件，不按应用名称写死路径。

普通程序仍依赖宿主可读取的 desktop 文件和图标资源；直接运行的 AppImage 可额外从其运行时 `APPDIR` 读取内嵌图标。当前补丁未增加 SVG 窗口图标解码，也不是完整的图标主题继承实现。应用自身使用 SVG 作为 AppImage 图标，不代表窗口图标读取支持 SVG。

不同窗口切换器可能因为图标来源、主题匹配和尺寸选择策略不同而显示同一应用的不同图标样式；只要图标能够正常显示，这类样式差异不作为本项目的缺陷处理。

## 稳定基线

当前版本作为最终稳定基线：保留已经实机确认有效的宿主 XDG 图标映射、AppImage `APPDIR` 回退和无扩展名 `.DirIcon` 识别，同时保持上游 `icon.source` 默认策略不变。

- 文件图标继续按 XDG desktop、`StartupWMClass`、`Icon`、主题目录和 `pixmaps` 规则查找。
- AppImage 仅在宿主文件图标查找未命中时，通过目标窗口 `_NET_WM_PID` 获取所属进程的 `APPDIR`，再读取 `.DirIcon` 或根目录 desktop 的 `Icon`。
- `.DirIcon` 同时兼容普通文件和符号链接；没有扩展名时按文件内容识别 PNG / XPM，不依赖固定文件名。
- 运行时不匹配具体被切换应用名称，不写死用户路径、临时挂载目录、固定 AppImage 文件名或 sharun 版本号。
- AltTab 自身名称、`StartupWMClass=AltTab`、上游仓库地址、标准 `/usr` 安装前缀、Release 资产名等属于项目固有元数据或构建接口，不属于环境相关硬编码。

## 修复记录

### 2026-09-10：补充桌面图标映射，修复 PNG 画布尺寸

- 现象：部分应用在其他窗口切换器中能显示图标，在 alttab 中缺失。
- 根因：源码缺少 desktop 图标映射；legacy pixmaps 的尺寸可能被猜测为 `1×1`，并用于 PNG 画布分配。截图不能单独确定每个缺失图标具体命中了哪条路径。
- 修改文件：`build_alttab.sh`，对应提交 [0dcee72](https://github.com/newyorkthink/linux-packaging/commit/0dcee72e36a76a8edc46ae2dbcfff879d631e700)。
- 修复内容：补充 GLib desktop 映射、XDG 目录查找、PNG 真实尺寸及透明背景处理，同时移除构建脚本中的帮助命令冒烟执行。
- 已知结果：Shell 静态检查和当时稳定版源码的补丁应用检查通过；未编译验证，未确认新产物的实机图标显示效果。

### 2026-09-10：拆分补丁文件并补齐说明

- 维护问题：补丁内嵌在构建脚本中，且目录缺少 README，不利于后续独立维护。
- 修改文件：`build_alttab.sh`、`apply-icon-patch.sh`、`patches/desktop-icons.patch`、`README.md`。
- 调整内容：原补丁逐字迁出，由独立脚本应用；构建脚本通过自身目录定位辅助文件。补齐技术栈、打包流程、兼容范围和修复记录。
- 已知结果：补丁内容与拆分前一致；本次只调整组织方式和文档，不改变图标算法，不新增测试代码或 workflow，不触发 Actions。

### 2026-09-10：补充 AltTab 自身 StartupWMClass

- 现象：quick-sharun 构建日志提示生成的 `alttab.desktop` 缺少 `StartupWMClass`。
- 根因：构建脚本生成 desktop 文件时只写入了 `StartupNotify=false`，没有写入上游实际使用的 X11 class。
- 修改文件：`build_alttab.sh`，对应提交 [5dfbc4c](https://github.com/newyorkthink/linux-packaging/commit/5dfbc4c7b7e2c5dca3c3185d7630ea4247e80ab0)。
- 修复内容：新增 `StartupWMClass=AltTab`，与上游 `XCLASS` 保持一致。
- 已知结果：desktop 字段已补齐；该修改只处理 AltTab 自身 desktop 关联，不负责其他被切换窗口的图标来源。

### 2026-09-10：补充运行中 AppImage 内嵌图标回退

- 现象：宿主应用图标能够显示，但部分直接运行的 AppImage 在 AltTab 中仍显示空白图标。
- 根因：现有补丁只扫描宿主 XDG desktop 和图标目录；直接运行的 AppImage 可以只把 desktop 与图标保存在运行时挂载的 `APPDIR` 中，因此宿主索引没有可匹配资源。
- 修改文件：`apply-icon-patch.sh`、`patches/appimage-icons.patch`、`README.md`。
- 修复内容：保留原 `desktop-icons.patch` 不变，新增独立 `src/win.c` 补丁；宿主图标查找失败时，通过 `_NET_WM_PID` 读取目标进程环境中的 `APPDIR`，优先解析 `.DirIcon`，再读取 AppImage 根目录 desktop 的 `Icon`，仅加载现有 PNG / XPM，不写死具体应用名称。
- 已知结果：新补丁的格式、目标函数和当前上游稳定版相关源码上下文已完成静态核对；未新增测试代码或 workflow。新产物的实际窗口图标效果需重新构建后确认。

### 2026-09-10：兼容 quick-sharun 无扩展名 `.DirIcon`

- 现象：前述 AppImage 内嵌图标回退已经对部分应用生效，但 VS Code 窗口仍没有图标。
- 根因：VS Code 构建脚本把 `ICON` 设置为远程 `code.png`；quick-sharun 下载图标后使用 `cp` 生成 AppImage 根目录 `.DirIcon`，因此 `.DirIcon` 是没有扩展名的普通文件。首版 AppImage 回退主要按扩展名和符号链接识别图标，无法识别这种布局。
- 修改文件：`patches/appimage-icons.patch`、`README.md`。
- 修复内容：读取 `.DirIcon` 时先识别其实际文件内容；PNG 使用标准 8 字节签名，XPM 使用文件头识别。保留原有扩展名、符号链接和 desktop `Icon` 回退，不写死 VS Code 或其他应用名称。
- 已知结果：已核对 VS Code 当前构建脚本和 quick-sharun 的 `.DirIcon` 生成逻辑，并完成补丁 hunk 与当前上游稳定版相关源码上下文的静态检查；未新增测试代码或 workflow。新产物实际显示效果需重新构建后确认。

### 2026-09-10：实机确认图标修复并设为稳定基线

- 结果：宿主应用、直接运行的 AppImage、quick-sharun 无扩展名 `.DirIcon` 场景均已在 Linux 实机确认窗口图标显示正常。
- 核查：运行逻辑没有写死具体被切换应用名称、用户路径或固定 AppImage 挂载目录；具体应用名称仅保留在历史故障记录中，不参与运行时匹配。
- 基线：保留“宿主 XDG 图标查找 → AppImage `APPDIR` 回退 → `.DirIcon` / desktop `Icon` → PNG / XPM 内容识别”的现有逻辑和执行顺序。
- 修改文件：`README.md`、`apply-icon-patch.sh`；本次只整理文档与注释，不改变已验证的运行逻辑、补丁内容或应用顺序。

### 2026-09-10：尝试调整默认图标来源优先级

- 现象：所有窗口已经能够显示图标后，个别应用在 AltTab 中显示的图标仍与其他窗口切换器不同。
- 判断：上游默认 `icon.source=2`（`ISRC_SIZE`）会综合窗口自身图标和文件图标进行尺寸选择，因此曾尝试把默认值改为 `ISRC_FALLBACK`。
- 修改文件：`apply-icon-patch.sh`、`patches/icon-source-priority.patch`、`README.md`。
- 已知结果：构建和 Linux 实机运行后，目标图标样式差异仍然存在，说明该默认优先级调整没有带来已确认收益；最终稳定基线不保留这一改动。

### 2026-09-10：修复 quick-sharun 下载 sharun 失败

- 现象：图标补丁已成功应用且 AltTab 已编译完成，但 quick-sharun 在部署阶段连续下载 `pkgforge-dev/sharun` 2.3.0 失败，构建退出。
- 根因：当前 quick-sharun 默认 `SHARUN_LINK` 仍指向已迁移的 `pkgforge-dev/sharun` 旧地址；当前维护的 AnyLinux sharun Release 位于 `pkgforge-dev/Anylinux-sharun`。
- 修改文件：`build_alttab.sh`、`README.md`。
- 修复内容：使用 quick-sharun 已有的 `SHARUN_LINK` 覆盖接口，将来源改为 `pkgforge-dev/Anylinux-sharun` 的 `releases/latest/download/sharun-${ARCH}`，动态跟随最新 Release，不写死版本号；未修改已验证图标补丁、编译命令或 workflow。
- 已知结果：对应 GitHub Actions 构建已成功完成，确认新的 sharun 下载来源和现有打包流程可正常工作。

### 2026-09-10：整理最终稳定基线

- 结果：当前图标缺失问题已在 Linux 实机确认解决；个别应用与其他窗口切换器之间仅存在图标样式差异，不影响窗口识别和切换功能。
- 修改文件：`apply-icon-patch.sh`、`README.md`，并移除未带来已确认收益的 `patches/icon-source-priority.patch`。
- 基线：保留宿主 XDG 图标映射、AppImage `APPDIR` 回退、无扩展名 `.DirIcon` 内容识别和动态 sharun 下载来源；恢复并保持上游 `icon.source` 默认策略。
- 核查：最终运行逻辑不按具体被切换应用名称匹配，不写死用户环境路径、临时挂载目录、固定 AppImage 文件名或 sharun 版本号；未新增测试代码、workflow 或分支。

### 2026-09-12：补充 Xft 中文字体回退

- 现象：使用 `-font "xft:MonoLisa-12"` 时英文正常，但 MonoLisa 本身缺少中文字形，中文窗口标题显示为方框。
- 根因：上游只打开一个 `XftFont`，绘制 UTF-8 文本时不会自动进行逐字字体回退。
- 修改文件：`apply-icon-patch.sh`、`patches/font-fallback.patch`、`README.md`。
- 修复内容：保留 `-font` 指定的主字体；逐个 UTF-8 字符判断主字体是否存在字形，仅在缺字时使用 `WenQuanYi Zen Hei Mono`，并按连续字体段绘制，备用字号跟随主字体。
- 核查：未改动现有图标补丁及其应用顺序；已按上游当前稳定版 v1.8.0 的 `gui.c`、`util.c`、`util.h` 上下文核对补丁，并以 `patch --fuzz=0 --dry-run` 和 C99 `-Wall -Wextra -Werror` 语法检查确认新增逻辑可通过静态检查。实际界面效果由新构建产物实机确认。

### 2026-09-12：适配 quick-sharun 当前 sharun 校验机制

- 现象：中文字体回退补丁已经成功应用并完成 AltTab 编译，但 AppImage 部署阶段报 `sha256 check failed for /tmp/sharun+helper-libs-x86_64.tar`。
- 根因：当前 quick-sharun 使用配套版本的 `sharun+helper-libs` tar 包并校验固定 SHA-256，而旧的 `SHARUN_LINK` 覆盖仍指向 `latest/download/sharun-${ARCH}`，下载内容与 quick-sharun 内置校验和不对应。
- 修改文件：`build_alttab.sh`、`README.md`。
- 修复内容：移除已过时的 `SHARUN_LINK` 覆盖，恢复使用当前 quick-sharun 自带的 sharun 下载地址与匹配校验和；字体补丁、图标补丁、编译命令和 workflow 均保持不变。
- 核查：失败日志已确认字体补丁可正常应用并编译；本次仅修复随后发生的 quick-sharun 打包兼容问题，由提交后的现有 GitHub Actions 完成正式构建验证。

### 2026-09-12：补充符号字体回退，修复方框叉号

- 现象：中文标题已经能够显示，但部分终端窗口标题中的符号仍显示为方框叉号。
- 根因：上一版字体补丁只有 MonoLisa 主字体和 `WenQuanYi Zen Hei Mono` 中文备用字体；后者并不覆盖全部通用符号和 Nerd Font 私有区字形。
- 修改文件：`patches/font-fallback.patch`、`README.md`。
- 修复内容：保留现有 MonoLisa 主字体和中文回退逻辑，在其后增加 `DejaVu Sans`、`Symbols Nerd Font Mono`、`Symbols Nerd Font` 三层备用字体；每个 UTF-8 字符按顺序选择第一个实际包含该字形的字体，不改 `-font` 参数、图标补丁、构建脚本或 workflow。
- 核查：已按上游 v1.8.0 的相关源码上下文完成 `patch --fuzz=0 --dry-run` 静态核对；最终符号显示效果由新构建产物实机确认。

### 2026-09-12：动态补齐剩余字形并调整多行标题行距

- 现象：中文已经恢复，但终端窗口标题仍有少量方框；较长窗口标题换行后，第二行与第一行过于贴近。
- 根因：固定备用字体名称无法覆盖宿主实际安装的全部私有区或符号字体；上游多行标题默认行距系数 `0.3` 在当前字号下偏紧。
- 修改文件：`apply-icon-patch.sh`、`patches/glyph-layout.patch`、`README.md`。
- 修复内容：保留既有 MonoLisa 与固定备用字体顺序；仅在这些字体都缺少目标字符时，按 `charset=<Unicode>` 让 Fontconfig 自动匹配宿主已安装且实际包含该字形的字体，并缓存本次界面使用的动态备用字体；同时将多行标题行距系数从 `0.3` 调整为 `0.5`。图标逻辑、`-font` 参数和已有构建流程不变。
- 核查：Fontconfig 官方定义 `charset` 为字体 Unicode 覆盖属性，现有匹配语法支持按 `charset` 限定候选字体；本次未新增测试代码或 workflow。最终界面效果由新构建产物实机确认。

### 2026-09-12：修复 glyph-layout 补丁格式错误

- 现象：正式 `Build AltTab` 在现有字体补丁成功应用后，应用 `glyph-layout.patch` 时 `src/gui.c` hunk 失败，随后报 `malformed patch at line 68` 并退出。
- 根因：`glyph-layout.patch` 中部分 unified diff hunk 的旧/新行数声明与实际内容不一致，导致 `patch` 解析错位；失败日志已明确定位到该补丁，而前置 `font-fallback.patch` 已全部成功应用。
- 修改文件：`patches/glyph-layout.patch`、`README.md`。
- 修复内容：仅校正 hunk header 的旧/新行数，不改变动态字形回退、`0.5` 行距、图标逻辑、补丁应用顺序或 workflow。
- 核查：已重新逐个统计所有 hunk 的旧/新行数，并用 `patch --fuzz=0 --dry-run` 对修正后的补丁格式完成静态检查；正式构建由本次 push 继续确认。
