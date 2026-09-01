# Hermes Desktop AppImage

本目录用于把 `NousResearch/hermes-agent` 最新稳定 Release 对应的官方 Desktop 源码构建为 x86_64 Linux AppImage。

迁移基线来自 `newyorkthink/hermes-agent` 中已经实际发布过 `hermes-desktop.AppImage` 的 Desktop AppImage 方案；正式迁入本仓库后，构建和发布统一接入 `.github/workflows/build.yml`，不保留独立长期 workflow。

## 当前构建来源

- 上游源码：`NousResearch/hermes-agent` 最新稳定 Release tag，构建时动态读取，不写死版本。
- Desktop 构建链：上游 `apps/desktop` 自带的 npm / electron-builder 流程。
- Node.js：26。
- npm：12。
- 架构：x86_64。
- 发布文件：`latest` Release 中的 `hermes-desktop.AppImage`。

当前不使用第三方 Hermes Desktop 二进制，也不从旧 Release 重新打包；每次都从上游稳定 tag 的 Desktop 源码重新构建。

## Linux AppImage 兼容处理

迁移保留源方案中已经实际用于发布成品的 Linux 兼容逻辑：

- 直接启动 standalone AppImage 时自动探测 KeePassXC Secret Service、GNOME Keyring 或 KWallet，并为 Electron `safeStorage` 选择 password-store。
- AppImage 内置 `libsecret-1.so.0`，并给 Electron 主程序加入 `$ORIGIN/resources/linux-libs` RUNPATH，避免宿主机缺少 Chromium 动态加载所需客户端库。
- 中文 Linux locale 映射为 Chromium `zh-CN`；Hermes 没有明确设置 `display.language` 时，初始界面跟随系统语言。
- standalone AppImage 禁用源码 checkout 方式的 Desktop 自更新入口，避免 AppImage 自己修改或替换源码目录。
- 构建后检查 `zh-CN.pak`、内置 `libsecret-1.so.0` 和 Electron RUNPATH。
- 最终 AppImage 在 Xvfb + D-Bus + GNOME Keyring 环境中实际执行，检查 `gnome_libsecret`、`safeStorage` 加密/解密往返以及中文 locale。
- GitHub Actions smoke test 会临时隐藏 Runner 的系统 `libsecret-1.so.0`，确保最终 AppImage 确实能够使用自身内置副本；trap 会在退出时恢复 Runner 文件。本机手动构建不会执行这一步系统库移动。

## 构建文件

```text
hermes-desktop/
├── build_hermes-desktop.sh
├── patch_hermes_desktop.py
└── README.md
```

`build_hermes-desktop.sh` 负责动态获取上游稳定 tag、安装构建依赖、构建、静态验证和最终 AppImage runtime smoke test。

`patch_hermes_desktop.py` 只处理 standalone Linux AppImage 所需的 Desktop 源码兼容点；所有补丁均使用明确锚点，上游结构变化导致锚点无法唯一定位时直接停止构建，不盲目继续修改。

## 发布

正式 CI 使用：

```text
.github/workflows/build.yml
```

手动构建项：

```text
hermes-desktop/build_hermes-desktop.sh
```

最终资产：

```text
https://github.com/newyorkthink/linux-packaging/releases/download/latest/hermes-desktop.AppImage
```

## 运行配置

Hermes Desktop 的 Gateway URL、Session Token、API Key、IP 和端口属于实际部署环境配置，不写入 AppImage，也不固化在本仓库打包脚本中。

需要连接 Hermes Dashboard 时，在 Desktop 中按实际环境填写：

```text
Gateway URL: http://<IP地址>:<Dashboard端口>
Session token: <Dashboard Session Token>
```

OpenAI-compatible API 同样使用实际部署参数：

```text
Base URL: http://<IP地址>:<API端口>/v1
API Key: <API_SERVER_KEY>
Model: <实际模型ID>
```

## 源迁移记录

源仓库 Desktop AppImage 迁移范围：

| 源文件 | 源 Git blob SHA | 用途 |
| --- | --- | --- |
| `.github/workflows/desktop-appimage.yml` | `818c0b3c586d77c5a6ebac7c791cd855c9a7c529` | 已发布方案的构建、补丁、验证和 Release 基线 |
| `README_AppImage.md` | `a21343376d673a8f1219c4da8d2ecef9677e9900` | 已发布方案的使用和兼容性说明基线 |

源 `desktop-latest` Release 已存在由 `github-actions[bot]` 上传的 `hermes-desktop.AppImage`；迁入本仓库时将源 workflow 的实际构建逻辑拆分为当前目录脚本，并按照本仓库规则接入统一 `build.yml`。
