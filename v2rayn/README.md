# v2rayN AppImage

## 用途与产物

本目录从 v2rayN 官方 GitHub 最新稳定 Release 下载 Linux x64 自包含包，并重新封装为 `v2rayn.AppImage`。

## 技术栈与打包方式

v2rayN Linux 客户端使用 .NET/Avalonia。构建脚本校验官方 Release SHA-256，保留自包含运行目录，通过 quick-sharun 处理 ELF 和桌面集成。

## 版本元数据

构建脚本复用官方稳定 Release tag 解析出的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=v2rayn` 接入统一版本清单。

## 运行

```bash
./v2rayn.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有官方包校验、Avalonia 自包含目录或启动环境。

### 2026-09-17：修复 GitHub Actions 下载官方 Release 资产 403

- 故障现象：全量 Actions Run `35159519188` 的 `Build v2rayN` 在读取官方最新 Release 信息成功后，下载 `v2rayN-linux-64.zip` 时收到 HTTP 403，构建在正式打包前退出。
- 根因范围：失败发生在 GitHub Release 的 `browser_download_url` 直链下载阶段；现有 Release API、版本解析和 SHA-256 digest 读取均已成功，因此不修改 v2rayN 打包、Avalonia runtime 或版本元数据逻辑。
- 修改文件：`v2rayn/build_v2rayn.sh`、本 README。
- 修复：继续优先使用官方 `browser_download_url`；如果该直链下载失败，则使用同一 Release asset 的 GitHub API asset ID，并通过 workflow 已提供的 `GH_TOKEN` 以 `application/octet-stream` 方式下载。两条路径最终仍使用 GitHub Release 返回的同一个 SHA-256 digest 校验。
- 已知结果：本次仅修复下载入口；完整构建结果以对应 Actions Job 为准。

### 2026-09-23：恢复既有打包环境并延后安装统一基础包

- 故障现象：AppImage 已生成，但在现有 Xvfb 启动检查中出现 `free(): invalid pointer` 并提前退出。
- 根因范围：最近新增的统一 Arch 基础包调用位于构建脚本开头，改变了此前稳定的依赖收集与启动检查环境。
- 修改文件：`v2rayn/build_v2rayn.sh`、本 README。
- 修复内容：将统一基础包调用移动到 AppImage 完成现有检查之后，使打包阶段继续使用原有应用依赖集合，同时在脚本返回前补齐后续发布需要的基础命令。
- 已知结果：脚本执行顺序已恢复原有打包环境；实际构建和运行结果以下一次 Actions 为准。

### 2026-09-24：整理构建脚本与可选图形检查

- 构建脚本的流程注释改为中文，移除最终 AppImage 再解包、逐项核对 AppRun、desktop、图标和程序目录的重复检查；仍保留官方资产 SHA-256、架构与入口判断、desktop 校验和最终产物非空判断。
- 只有本应用显式调用 `common/gui/check_appimage_gui.sh`；保留原有 20 秒上限、`timeout → dbus-run-session → xvfb-run` 顺序、退出码 `124` 及既有致命日志特征，不检查窗口标题。通过后仍先安装统一基础包，再由 `common/build/finish_appimage_build.sh` 写入 `dist/version.txt` 并输出原成功提示。
- 官方 Release 直链失败时使用同一资产 ID 与 `GH_TOKEN` 回退的逻辑，以及官方 SHA-256 校验均未改变。本次只完成静态检查，构建、图形启动及实机结果尚未验证。
