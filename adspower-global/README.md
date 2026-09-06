# AdsPower Global AppImage

用于将 AdsPower Global 官方 Linux x64 版本重新封装为 AppImage。

## 用途与产物

- 打包对象：AdsPower Global，多账号管理与指纹浏览器桌面应用。
- 最终产物：`adspower-global.AppImage`，由统一 `build.yml` 中的 `build_adspower_global` Job 构建并发布到仓库 `latest` Release。
- 上游来源：AdsPower 官方下载页及官方 `version.adspower.net` Linux x64 DEB。
- AUR `adspower-global` 仅用于核对 Linux 依赖、`/opt/AdsPower Global/` 程序布局、desktop / icon 名称和启动入口，不作为程序二进制来源。

## 技术栈

AdsPower Global 为专有桌面应用，Linux 包包含 Chromium / Electron 体系相关运行文件，主程序入口为 `adspower_global`。官方 Linux x64 DEB 将完整应用安装在 `/opt/AdsPower Global/`，同时提供 GTK3、NSS、X11、音频等系统运行依赖。

当前仅构建 x86_64 AppImage。AdsPower 官方下载页标明 Linux 版本面向 Ubuntu Desktop 22.04 或更高版本；本目录只负责在不修改应用授权逻辑的前提下进行便携化重打包与依赖收集。

## 打包方式

- 路线：Arch Linux AnyLinux 构建环境 + quick-sharun。
- 版本：不锁版本。脚本每次从 AdsPower 官方下载页解析当前 Linux x64 稳定版 DEB 地址，并从官方文件名取得实际版本号。
- 程序来源：直接下载 `version.adspower.net` 官方 DEB，不重新编译、不修改应用业务代码。
- 依赖来源：运行依赖名称参考当前 AUR `adspower-global` 配方，在构建容器内通过 Arch 软件包安装；AUR 本身不提供本项目的应用二进制。
- 程序布局：解包官方 DEB 后完整保留 `/opt/AdsPower Global/` 内部文件结构，复制到 `AppDir/shared/bin/`，避免破坏 Chromium / Electron 资源之间的相对路径。
- desktop / 图标：从官方 DEB 提取 `adspower_global.desktop` 和 hicolor 官方 PNG 图标，只把 `Exec` / `Icon` 调整为 AppImage 内入口，并写入动态版本元数据。
- 依赖部署：由 quick-sharun 针对真实主程序 `AppDir/shared/bin/adspower_global` 收集当前正式构建所需依赖；不预先复制其他应用的 Qt、输入法、沙盒或其他兼容 workaround。
- workflow：通过 `.github/workflows/build.yml` 的独立 `build_adspower_global` Job 构建，沿用仓库统一 AnyLinux 构建与 `latest` Release 发布流程。

## 运行与兼容说明

- 仅支持 x86_64。
- 默认保持 AdsPower 官方程序和授权机制，不破解、不绕过订阅、许可证、账号或其他访问控制。
- 不修改宿主系统的内核参数、浏览器 sandbox 策略或其他全局配置。
- 当前首次接入只采用最小正式打包链路；如果后续 GitHub Actions 或真实 Linux 运行反馈出现明确缺库、输入法、图形后端或 Chromium runtime 问题，再依据实际日志做最小补充。
- AdsPower 为专有软件，使用、账号、订阅及其他权利义务仍受 AdsPower 官方许可协议与服务条款约束。

### 直接运行

```bash
./adspower-global.AppImage
```

## 变更记录

### 2026-09-06：首次接入 AdsPower Global AppImage 构建

- 目标：新增 AdsPower Global Linux x64 AppImage 构建，不改变官方程序功能和授权状态。
- 上游：使用 AdsPower 官方下载页动态解析当前 Linux x64 DEB；AUR `adspower-global` 仅作为依赖和文件布局参考。
- 修改文件：`adspower-global/build_adspower-global.sh`、`adspower-global/README.md`、`.github/workflows/build.yml`。
- 实现：保留官方 `/opt/AdsPower Global/` 应用目录和官方资源，通过 quick-sharun 收集主程序运行依赖，并接入仓库统一 AnyLinux Job / latest Release 流程。
- 已知结果：本条记录的是首次构建接入；GitHub Actions 构建结果和最终 AppImage 的真实 Linux 运行结果以后续实际输出为准，不预先视为稳定基准。
