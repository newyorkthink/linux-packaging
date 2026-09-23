# OBS Studio AppImage

## 用途与产物

本目录把 Arch Linux 仓库中的 OBS Studio 与 Browser Source 等运行组件封装为 x86_64 AppImage，稳定产物名为 `obs-studio.AppImage`。上游应用版本由构建时实际安装的 `obs-studio` 软件包动态取得。

## 技术栈与打包方式

OBS Studio 为 Qt 6 / C++ 桌面应用。当前脚本使用 Arch Linux 构建环境与 quick-sharun 收集 OBS、Browser Source、PipeWire、Qt 6、Fcitx5 及相关运行依赖，并生成最终 AppImage；不启用 AnyLinux self-updater hook。

构建脚本同时保留简体中文 locale、Qt 6 Fcitx5 输入模块和 OBS 官方 Yami 深色主题默认值。最终图形驱动仍按现有脚本规则处理，本次不引入额外兼容逻辑。

## 版本元数据

`build_obs-studio.sh` 从 `pacman -Q obs-studio` 读取实际软件包版本，去除 Arch package release 后写入：

```text
dist/version.txt
```

统一 workflow 在成功构建后上传 `software-version-obs-studio`，当前 Build 再使用 `obs-studio.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`，构建脚本为：

```text
obs-studio/build_obs-studio.sh
```

最终产物发布到 `latest` Release。运行时直接执行：

```bash
./obs-studio.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 复用既有 `dist/version.txt`，不修改 OBS Studio 构建脚本、运行时逻辑和 Release 资产名。
- 成功构建后由统一汇总流程增量更新 `software_versions.json`；提交后不主动监控 Actions，实际新记录以下一次成功构建为准。

### 2026-09-23：补齐 OBS 独立 Job 的 yay 引导

- 故障现象：OBS Studio 独立 Job 进入构建脚本后报告 Arch 构建环境缺少 `yay`，统一基础包入口无法执行。
- 根因：该独立 Job 使用 AnyLinux v2 准备容器，但没有像同类特例 Job 一样先为 root 构建流程安装 `yay`。
- 修改文件：`.github/workflows/build.yml`、本 README。
- 修复内容：在 OBS Studio 构建步骤之前复用现有的 `yay-bin` 引导步骤；不额外安装 `jq`、`github-cli` 或其他基础包，后续仍由构建脚本调用统一 Arch 基础包入口。
- 已知结果：workflow 结构与同类 Arch 特例 Job 对齐；实际构建结果以下一次 Actions 为准。
