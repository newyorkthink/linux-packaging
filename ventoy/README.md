# Ventoy

本目录将 Ventoy 官方最新稳定 Linux Release 重新封装为单文件 AppImage，保持官方 Linux 包的完整目录结构和原始功能，不对 Ventoy 本体做功能删减或授权相关修改。

## 用途与产物

- 上游项目：`ventoy/Ventoy`
- 上游输入：最新稳定 Release 的 `ventoy-<版本>-linux.tar.gz`
- 目标架构：x86_64
- 构建脚本：`ventoy/build_ventoy.sh`
- Release 稳定资产名：`ventoy.AppImage`

AppImage 内保留官方 Linux Release 的完整 `ventoy/` 目录，包括 `VentoyGUI.x86_64`、各 GUI 后端、worker、工具、WebUI、boot image 和 Ventoy 运行资源。这里不做无依据的“瘦身”，避免破坏安装、更新、Secure Boot、分区或其他上游功能所需文件。

## 技术栈

Ventoy Linux 包不是单一 GTK 程序。其 x86_64 图形入口为原生 `VentoyGUI.x86_64` launcher，launcher 会根据可用环境选择 GTK2、GTK3 或 Qt5 GUI 后端；同时整个发行包还包含 Shell worker、原生工具、WebUI、boot image 和多架构辅助文件。

当前 AppImage 以官方 x86_64 Linux tarball 为输入，并在 CI 中以 `Ventoy2Disk.gtk3` 作为可检查的 GTK3 后端验证动态库加载情况。

## 打包方式

本项目采用“官方完整 Linux Release + 顶层 AppRun + 官方 appimagetool 直接封装”的路线，不使用 linuxdeploy 或 quick-sharun 重排 Ventoy 官方目录。

构建流程：

1. 读取 `ventoy/Ventoy` 的 GitHub `releases/latest`，只接受非 draft、非 prerelease 的最新稳定版本。
2. 动态选择该版本的 `ventoy-<版本>-linux.tar.gz` 和 `sha256.txt`，同时校验 GitHub Release asset digest 与上游 `sha256.txt`。
3. 将 Release tag 解析到实际 Git commit，并从该不可变 commit 获取官方 Ventoy 图标。
4. 完整复制官方 Linux Release 到 `AppDir/ventoy/`。
5. 顶层 `AppRun` 只设置 Ventoy 运行需要的 `LD_LIBRARY_PATH`、`PATH` 和 `NO_AT_BRIDGE=1`，随后启动官方 `VentoyGUI.x86_64`。
6. 动态读取官方 `AppImage/appimagetool` 和 `AppImage/type2-runtime` Release，校验各自 SHA-256 digest 后，以明确的 x86_64 type2 runtime 生成 `ventoy.AppImage`。
7. 正式构建由仓库统一 `.github/workflows/build.yml` 中的独立 Ventoy Job 执行并上传到 `latest` Release。

应用版本没有写死；上游发布新的稳定版本后，后续构建会自动选择新的稳定 Release。

## 运行与权限

顶层 `AppRun` 本身不执行 `sudo`、`pkexec`、systemd、udev、网络配置或系统文件修改，只负责启动官方 `VentoyGUI.x86_64`。

当前 AppImage 在 Linux 实机上应直接以 root 权限启动。Ventoy 需要枚举、分区并写入 USB / 磁盘块设备；实际测试中普通用户直接运行还可能在进入 Ventoy GUI 前出现内部 `VentoyGUI.x86_64: Permission denied`，因此不要依赖非 root 启动后再由上游提权。

在 `ventoy.AppImage` 所在目录打开 Linux 终端执行：

```bash
# 以 root 权限启动 Ventoy AppImage
sudo ./ventoy.AppImage
```

命令示例统一以“当前目录”为基准，不假设 AppImage 位于 `Downloads` 或其他固定路径。

如果当前 Linux 图形会话本身已经使用中文 locale，则无需额外执行 `export LANG=...`、`export LC_ALL=...` 等环境变量命令，直接执行上面的 `sudo ./ventoy.AppImage` 即可。需要手动切换界面语言时，可在 Ventoy GUI 的 `Language` 菜单中选择 `Chinese Simplified (简体中文)`。

Ventoy 的核心功能是向用户选择的 USB / 磁盘设备安装或更新 Ventoy。实际安装 / 更新过程中，官方 worker 会进行分区和块设备写入。因此，执行安装、更新等磁盘操作前应确认 GUI 中选中的目标设备；这些操作可能重建分区或写入块设备。CI 只做非破坏性的静态、ELF、封装和提取验证，不执行任何实际磁盘安装 / 更新操作。

## 构建与验证

`build_ventoy.sh` 包含以下检查：

- 最新稳定 Release / tag / asset 名称与 URL 校验；
- GitHub Release SHA-256 digest 校验；
- 上游 `sha256.txt` 二次校验；
- Linux 包内部 `ventoy/version` 与 Release tag 一致性校验；
- `VentoyGUI.x86_64` 和 `Ventoy2Disk.gtk3` ELF 类型检查；
- GTK3 后端 `ldd` 缺失库检查；
- `desktop-file-validate`；
- appimagetool 与 type2 runtime Release digest 校验；
- 最终 AppImage 非空、ELF 类型、`--appimage-extract`、关键文件、版本和 AppRun / desktop 一致性检查；
- 最终 `ventoy.AppImage` SHA-256 输出。

由于 Ventoy 会操作真实块设备，自动验证刻意不触发安装 / 更新动作。

## 变更记录

### 2026-09-02：接入统一 AppImage 构建

- 现象：旧构建参考脚本固定到特定 Ventoy 版本，并依赖本地 `appimagetool.AppImage`；旧的 zsync 更新目标还指向其他仓库，无法作为本仓库持续构建方案。
- 根因：旧脚本是一次性本地打包逻辑，没有按本仓库的动态版本、供应链校验、统一 workflow 和稳定 Release 资产规则维护。
- 修改文件：`ventoy/build_ventoy.sh`、`ventoy/README.md`、`.github/workflows/build.yml`。
- 修复：改为官方 latest Release 动态解析，校验 Release digest 与 `sha256.txt`，完整保留官方 Ventoy Linux 包，并接入统一 `Build AppImages` workflow，发布稳定资产 `ventoy.AppImage`。
- 验证：构建脚本内加入 checksum、ELF、desktop、动态库、AppImage 提取和关键文件一致性检查；最终 CI 构建结果以对应 GitHub Actions run 为准。

### 2026-09-02：补充实际运行权限与语言说明

- 现象：普通用户直接启动 AppImage 时，可能在进入 GUI 前出现内部 `VentoyGUI.x86_64: Permission denied`；以 root 权限启动后 GUI 可以正常进入。中文图形会话无需额外导出 locale 环境变量。
- 根因：Ventoy 本身需要直接访问和写入块设备，当前 AppImage 的实际运行方式应以 root 启动为准；原 README 对非 root / `pkexec` 路径的说明与实机行为不一致。
- 修改文件：`ventoy/README.md`。
- 修复：明确统一使用当前目录下的 `sudo ./ventoy.AppImage` 启动，不再在示例中写死 `Downloads` 等目录；同时说明中文 locale 环境无需额外执行 `export LANG` / `LC_ALL`。
- 验证：Linux 实机中 `sudo ./ventoy.AppImage` 可进入 Ventoy GUI，并可在 `Language` 菜单中看到 `Chinese Simplified (简体中文)` 语言选项。
