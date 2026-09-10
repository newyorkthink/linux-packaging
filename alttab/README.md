# AltTab AppImage

## 用途与技术栈

本目录将 [sagb/alttab](https://github.com/sagb/alttab) 官方最新稳定 Release 源码编译并封装为 `alttab.AppImage`，用于 X11 窗口切换。

上游使用 C、Xlib、Xft、Xrender、Xrandr、libpng、libXpm 和 uthash；图标补丁额外使用 GLib 解析 desktop 文件。构建架构取当前 runner 的 `uname -m`，不交叉编译。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `build_alttab.sh` | 获取稳定版源码、安装构建依赖、调用补丁脚本、编译和打包 |
| `apply-icon-patch.sh` | 接收源码目录，应用同目录下的图标补丁 |
| `patches/desktop-icons.patch` | 对上游 `src/icon.c` 的图标修复 |

以后修改图标逻辑时维护 `.patch` 文件；补丁路径和应用方式由 `apply-icon-patch.sh` 管理，不再把大段补丁放进构建脚本。

## 打包流程

正式构建使用 `.github/workflows/build.yml` 的 AltTab Job，并复用 `.github/actions/build-anylinux`，在 Arch Linux / AnyLinux 构建环境中执行。手动构建入口选择 `alttab/build_alttab.sh`。

1. 从官方 `releases/latest` 获取非草稿、非预发布版本，将 tag 解析为具体 commit SHA，下载该 commit 的源码归档并记录 SHA-256。
2. 调用 `apply-icon-patch.sh`，向本次解压的源码应用 `patches/desktop-icons.patch`。补丁不匹配时停止构建，不静默跳过，也不回退到旧版。
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

- 按 XDG 数据目录查找 desktop 文件，通过文件 ID、`StartupWMClass` 与 `Icon` 映射图标；只读取元数据，不执行 `Exec`。
- 查找用户及系统图标目录，并补充 `hicolor` 回退；避免直接修改进程的 `XDG_DATA_DIRS` 环境字符串。
- 支持映射到已有 PNG / XPM 图标，以及 PNG / XPM 绝对路径。PNG 使用文件头中的真实尺寸创建画布，并修正透明背景颜色转换。

窗口图标仍依赖宿主可读取的 desktop 文件和图标资源。当前补丁未增加 SVG 窗口图标解码，也不是完整的图标主题继承实现。应用自身使用 SVG 作为 AppImage 图标，不代表窗口图标读取支持 SVG。

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
