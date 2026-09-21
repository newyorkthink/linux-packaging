# CC Switch AppImage

本目录用于把 CC Switch 打包为仓库统一发布的 `cc-switch.AppImage`。

## 用途与产物

- 上游项目：`farion1231/cc-switch`。
- 构建输入：Arch Linux / AUR 的 `cc-switch-bin` 当前版本。
- 发布资产：`cc-switch.AppImage`。
- 版本元数据：构建时从 `pacman -Q cc-switch-bin` 读取实际安装版本，最终写入 `dist/version.txt`。

## 技术栈

CC Switch 上游为 Tauri 2 / Rust 桌面应用。Linux 端使用 GTK3、WebKitGTK 4.1，并通过 AppIndicator / Ayatana AppIndicator 提供系统托盘支持。

## 打包方式

当前路线保持为 Arch Linux AnyLinux + `quick-sharun`，不改用其他打包工具。

构建脚本安装 `cc-switch-bin` 及现有 GTK、WebKitGTK、输入法和托盘依赖，然后由 `quick-sharun` 收集：

- `/usr/bin/cc-switch`
- `/usr/lib/libayatana-appindicator3.so.1`
- `/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so`

正式构建由 `.github/workflows/build.yml` 的标准 AppImage matrix 执行，对应清单项位于 `.github/appimage-apps.json`。

## 运行

在 AppImage 所在目录执行：

```bash
chmod +x cc-switch.AppImage
./cc-switch.AppImage
```

## 运行与兼容说明

- AppIndicator 属于 CC Switch Linux 托盘运行时依赖，不应依赖宿主系统临时补库。
- `libayatana-appindicator3.so.1` 由 Arch Linux `libayatana-appindicator` 包提供；其依赖继续由 `quick-sharun` 按现有机制收集。
- 当前脚本保留既有 GTK3 IBus module、desktop、icon、版本解析和发布逻辑，不因本次托盘修复改写其他已存在命令。

## 修复记录

### 2026-09-21：修复启动时缺少 AppIndicator 动态库导致的崩溃

- **故障现象：** CC Switch 3.20.3 AppImage 启动后 panic，错误为 `Failed to load ayatana-appindicator3 or appindicator3 dynamic library`，并报告 `libayatana-appindicator3.so.1`、`libappindicator3.so.1` 等无法打开。
- **根因：** 构建环境已经安装 `libayatana-appindicator`，但原 `quick-sharun` 输入只有 CC Switch 主程序和 GTK3 IBus module。CC Switch 的托盘库通过运行时动态加载，不能保证仅靠主程序 ELF 依赖自动进入 AppImage。
- **依据：** CC Switch 上游 Linux 构建明确依赖 Ayatana AppIndicator；上游 Flatpak 配置也打包 `libayatana-appindicator`。Arch Linux 当前 `libayatana-appindicator` 包提供 `/usr/lib/libayatana-appindicator3.so.1`。
- **修改文件：** `cc-switch/build_cc-switch.sh`、本 README。
- **修复内容：** 仅在现有 `quick-sharun` 输入中显式加入 `/usr/lib/libayatana-appindicator3.so.1`；未改变主程序、IBus module、依赖安装顺序、版本解析或发布逻辑。
- **提交：** 本条记录与修复代码位于同一提交。
- **验证状态：** 已完成脚本语法检查和依赖路径核对；提交后按仓库规则不主动监控 Actions，因此新产物构建及真实 Linux 运行效果仍待实际结果确认。
