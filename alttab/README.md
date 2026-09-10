# AltTab AppImage

## 用途与技术栈

本目录将 [sagb/alttab](https://github.com/sagb/alttab) 官方最新稳定 Release 源码编译并封装为 `alttab.AppImage`，用于 X11 窗口切换。

上游使用 C、Xlib、Xft、Xrender、Xrandr、libpng、libXpm 和 uthash；图标补丁额外使用 GLib 解析 desktop 文件。构建架构取当前 runner 的 `uname -m`，不交叉编译。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `build_alttab.sh` | 获取稳定版源码、安装构建依赖、调用补丁脚本、编译和打包 |
| `apply-icon-patch.sh` | 接收源码目录，依次应用同目录下的图标补丁 |
| `patches/desktop-icons.patch` | 对上游 `src/icon.c` 的宿主 desktop / 图标查找与 PNG 处理修复 |
| `patches/appimage-icons.patch` | 对上游 `src/win.c` 的运行中 AppImage 内嵌图标回退 |

以后修改图标逻辑时维护对应 `.patch` 文件；补丁路径和应用顺序由 `apply-icon-patch.sh` 管理，不再把大段补丁放进构建脚本。

## 打包流程

正式构建使用 `.github/workflows/build.yml` 的 AltTab Job，并复用 `.github/actions/build-anylinux`，在 Arch Linux / AnyLinux 构建环境中执行。手动构建入口选择 `alttab/build_alttab.sh`。

1. 从官方 `releases/latest` 获取非草稿、非预发布版本，将 tag 解析为具体 commit SHA，下载该 commit 的源码归档并记录 SHA-256。
2. 调用 `apply-icon-patch.sh`，依次向本次解压的源码应用 `patches/desktop-icons.patch` 和 `patches/appimage-icons.patch`。任一补丁不匹配时停止构建，不静默跳过，也不回退到旧版。
3. 使用现有 `configure --prefix=/usr` 和 `make` 编译，传入 GLib 的头文件及链接参数。
4. 生成 desktop 文件，使用上游 `doc/alttab.svg` 作为应用自身图标，将主程序与动态依赖交给 quick-sharun，并保留上游 GPL-3.0 许可证。
5. 生成 `dist/alttab.AppImage`；公共构建 Action 将其上传至仓库 `latest` Release，资产名固定为 `alttab.AppImage`。

构建脚本、补丁脚本和补丁文件需要一起保留。构建流程由现有 Action 在应用目录内执行；无需在真实主机上运行依赖安装或打包命令。

## 运行与图标兼容

需要可访问的 X11 会话。下载产物后，在文件所在目录的 Linux 终端执行；文件需已有执行权限：

```bash
# 启动 AltTab 窗口切换器。
./alttab.AppImage
```

图标补丁保留上游窗口图标来源选项和界面行为，补充以下处理：

- 按 XDG 数据目录查找 desktop 文件，通过文件 ID、`StartupWMClass` 与 `Icon` 映射宿主图标；只读取元数据，不执行 `Exec`。
- 查找用户及系统图标目录，并补充 `hicolor` 回退；避免直接修改进程的 `XDG_DATA_DIRS` 环境字符串。
- 支持映射到已有 PNG / XPM 图标，以及 PNG / XPM 绝对路径。PNG 使用文件头中的真实尺寸创建画布，并修正透明背景颜色转换。
- 宿主图标查找没有命中时，根据目标窗口的 `_NET_WM_PID` 读取该进程的 `APPDIR`，优先使用运行中 AppImage 根目录的 `.DirIcon`；支持 `.DirIcon` 为普通文件或符号链接，并通过文件内容识别无扩展名 PNG / XPM；再回退读取根目录 desktop 的 `Icon` 对应 PNG / XPM 文件，不按应用名称写死路径。

普通程序仍依赖宿主可读取的 desktop 文件和图标资源；直接运行的 AppImage 可额外从其运行时 `APPDIR` 读取内嵌图标。当前补丁未增加 SVG 窗口图标解码，也不是完整的图标主题继承实现。应用自身使用 SVG 作为 AppImage 图标，不代表窗口图标读取支持 SVG。

## 稳定基线

当前图标兼容行为已经 Linux 实机验证有效，作为本目录当前稳定基线。后续修改必须保留现有查找顺序和已验证行为，不得仅为整理、重构或风格统一改写。

- 宿主应用继续按 XDG desktop、`StartupWMClass`、`Icon`、主题目录和 `pixmaps` 规则查找图标。
- AppImage 仅在宿主图标查找未命中时，通过目标窗口 `_NET_WM_PID` 获取所属进程的 `APPDIR`，再读取 `.DirIcon` 或根目录 desktop 的 `Icon`。
- `.DirIcon` 同时兼容普通文件和符号链接；没有扩展名时按文件内容识别 PNG / XPM，不依赖固定文件名。
- 运行时不匹配具体被切换应用名称，不写死用户路径、临时挂载目录或某个 AppImage 文件名。AltTab 自身的上游仓库、`StartupWMClass=AltTab` 等项目固有元数据不属于被切换应用的硬编码。

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
