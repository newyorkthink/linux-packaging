# Falkon AppImage

Falkon 是基于 Qt 6 和 Qt WebEngine 的 KDE 浏览器。此目录用于准备 Linux x86_64 的 `falkon.AppImage`。程序来源为 [Arch Linux Extra 的 Falkon 软件包](https://archlinux.org/packages/extra/x86_64/falkon/)。

## 打包方式

- 按[从系统真实入口收集](../docs/packaging-classification.md#从系统真实入口收集)的路线，以 [Qt 6 系统入口模板](../templates/quick-sharun/qt-installed.sh) 为底稿维护 [build_falkon.sh](./build_falkon.sh)。脚本通过公共入口安装官方包和依赖，动态读取实际安装版本。
- [Build AppImages](../.github/workflows/build.yml) 的标准 Arch 矩阵构建 `falkon.AppImage`，构建成功后发布到 [latest Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest)。
- quick-sharun 从 `/usr/bin/falkon` 收集程序、Qt 6 与 Qt WebEngine 运行资源，使用官方包自带的桌面入口和图标。
- 相对标准模板的改动包括：移除固定中文 locale、补入 `breeze-dark` 图标、内置深色主题以及写入运行时启动 hook。详细差异与依据见 [模板差异](./docs/template-deviations.md) 和 [固定配置](./docs/hardcoded.md)。

## 当前状态

[build_falkon.sh](./build_falkon.sh) 保留了标准构建结构与公共入口，已补入默认 `qt6ct`、内置深色主题、跟随系统语言以及远程桌面自动兜底处理。

## 语言与外观说明

### 为什么不固定中文环境

- 本包故意移除了模板里固定的 `zh_CN.UTF-8` locale 生成和 `AppDir/.env` 语言设置，改为完全跟随当前宿主机系统语言（英文系统默认英文，中文系统跟随中文），同时保留 `fcitx5-qt` 中文输入法模块。
- 原因：在浏览器中固定写入 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`，会让底层 QtWebEngine / Chromium 的 `Accept-Language`、`navigator.language` 和 `Intl` 区域信息持续暴露为中文环境。在英文或海外环境下注册账号、访问对地区和风控敏感的站点时，这种与网络环境不一致的固定语言特征可能触发区域误判或风控。
- 后续维护或对齐模板时，不要为了套用 `qt-installed.sh` 重新加回固定中文 locale。

### 深色主题与外框

- 启动 hook 在外部未设置 `QT_QPA_PLATFORMTHEME` 时默认启用包内 `qt6ct`，已配置深色 `qt6ct.conf` 的桌面环境直接启动即可呈现深色外框。
- 打包时补入了 `breeze-dark` 图标，并在 `AppDir/share/falkon/themes/` 内置了基于官方 `linux` 主题扩展的两套深色主题：`Dark Slate`（深灰）和 `OLED Black`（纯黑）。未配置 `qt6ct` 的机器可在“首选项 → 外观”中手动切换，不修改用户主目录外的系统配置。

## 运行

下载成品后，在图形会话中执行：

```bash
chmod +x falkon.AppImage
./falkon.AppImage
```

### VPS 远程桌面启动（RDP、VNC 等）

启动 hook（`AppDir/bin/90-falkon-runtime.hook`）会按当前环境自动处理常见远程桌面启动报错，普通桌面用户和带可用显卡的机器不会触发：

- 仅当以 `root` 身份运行且外部未定义 `QTWEBENGINE_DISABLE_SANDBOX` 时，自动设置 `QTWEBENGINE_DISABLE_SANDBOX=1`。
- 仅当缺少可读可写的 `/dev/dri/renderD*` 渲染节点且外部未定义 `QTWEBENGINE_CHROMIUM_FLAGS` 时，自动设置 `QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --use-gl=disabled'` 走软件渲染。

在存在实体渲染节点但走虚拟桌面、或需要覆盖默认参数的场景下，仍可手动传参启动：

```bash
QTWEBENGINE_DISABLE_SANDBOX=1 \
QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --use-gl=disabled' \
./falkon.AppImage
```

普通用户遇到相同图形错误时，只设置 `QTWEBENGINE_CHROMIUM_FLAGS` 即可保留默认沙箱。

#### 低配无 GPU 远程桌面使用建议

在 1 核 2 GiB 且无独立显卡的 VPS 远程桌面上，网页渲染、JavaScript 执行与 VNC 画面编码都共用同一颗 CPU，属于现代 Chromium / QtWebEngine 内核的硬件资源上限。为保持稳定，不建议在启动参数里强加 `--single-process` 等易崩溃选项，日常使用建议保持以下三点：

- 打开 Falkon 内置的 AdBlock，减少第三方脚本执行，降低单核 CPU 与内存占用。
- 同时只开 1～2 个必要标签页，用完即关。
- 适当调低 VNC / 远程桌面分辨率，减轻软件渲染和画面编码开销。

## 实机验证

### 2026-11-24：用户实机验证通过

用户已确认 Falkon AppImage 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 启动 | 浏览器在 Linux 图形会话中正常启动。 |
| 中文界面和输入法 | 中文界面正常显示，地址栏可输入中文并显示输入法候选词。 |
| 网页和图片 | 百度首页、DuckDuckGo 搜索结果和图片搜索均能正常加载和显示。 |
| 快速访问页 | 四张网站预览缩略图均正常显示。 |
