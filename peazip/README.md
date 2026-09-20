# PeaZip AppImage

## 用途与产物

本目录把 PeaZip 官方最新稳定版 Qt6 Linux x86_64 DEB 重新封装为 AnyLinux AppImage。

- 上游项目：<https://github.com/peazip/PeaZip>
- 上游来源：官方 GitHub Release 中的 `peazip_<版本>.LINUX.Qt6-1_amd64.deb`
- 稳定产物名：`peazip.AppImage`
- 构建入口：`peazip/build_peazip.sh`
- 正式 workflow：`.github/workflows/build.yml` 的标准 matrix Job

## 技术栈

PeaZip 使用 Free Pascal / Lazarus 构建。本目录选择官方 Qt6 版本，主程序和 `pea` helper 通过上游随包的 `libQt6Pas.so.6` 使用 Qt6 Widgets，并保留官方归档后端、语言文件、主题、帮助文档、desktop 和图标资源。

目标架构为 x86_64。官方包内仍包含少量上游保留的 32 位旧格式后端；构建脚本不修改或删除这些文件，也不把它们作为 64 位依赖收集入口。

## 打包方式

当前采用 Arch Linux + quick-sharun：

1. 通过 GitHub `releases/latest` API 动态读取 PeaZip 最新稳定版，不锁定 `11.2.0` 等具体版本。
2. 只接受与 Release tag 对应的官方 Qt6 amd64 DEB，并校验 GitHub Release 提供的 SHA-256 digest。
3. 核对 DEB 的包名、版本、架构、主程序、helper、资源、desktop、图标和版权说明。
4. 完整保留官方 `/usr/lib/peazip` 与 `/usr/share/peazip` 内容；仅把系统安装所用的绝对资源链接改为 AppImage 内等价相对链接。
5. 使用 quick-sharun 收集 PeaZip、`pea`、Qt6、Fcitx5 Qt6 输入上下文和 64 位归档后端的动态依赖，再生成 `dist/peazip.AppImage`。
6. AppImage 成功生成后，把本次实际使用的上游版本写入 `dist/version.txt`，供当前 Build 立即更新 `software_versions.json` 中的 `peazip` 条目。

本方案不复制旧 AppImage，也不使用 PeaZip portable tar 中会把配置保存在程序目录的 portable 标记。

## 运行与兼容说明

- AppImage 启动链不使用 `sudo`、`pkexec`、systemd、cron 或自动安装逻辑。
- 不强制覆盖宿主的 Qt 平台、主题、字体 DPI、缩放或输入法环境；平台后端和外观选择继续由宿主会话与 Qt 决定。
- 上游包自带的桌面环境右键菜单安装脚本只作为官方资源保留，启动 AppImage 时不会自动执行。
- Fcitx5 Qt6 输入上下文随包收集，但 Fcitx5 守护进程仍由宿主系统提供。
- 官方包内 32 位旧格式后端的实际可用性仍取决于宿主是否具备对应 32 位兼容运行库；这不影响 PeaZip 主程序和主要 64 位归档后端。

## 运行

在 Linux 终端进入 AppImage 所在目录后执行：

```bash
# 启动 PeaZip
./peazip.AppImage
```

## 检查记录

### 2026-09-20：旧 AppImage 与官方 11.2.0 适用性检查

- **仓库基线：** `f5d7df39db1ee4273db5df1bdaa7eb54fd803d3b`
- **检查对象：** 用户提供的旧 `peazip.AppImage`，SHA-256 为 `5137a3d3f5ab541a52ddccdfa0ac47b057de09f52598980a2fd47e84b9fee6b7`；PeaZip 官方 11.2.0 Release、Qt6 portable tar 和 Qt6 amd64 DEB。
- **检查范围：** AppImage 类型与提取内容、PeaZip 版本、Qt 主版本、AppRun / desktop、动态依赖、资源布局、提权和持久化入口、上游许可证、Release 资产与 digest。
- **证据来源：** 旧 AppImage 仓库外静态提取结果；PeaZip 官方 GitHub Release API 和 Release 资产；上游仓库许可证与说明。
- **已确认结论：** 旧包是 x86_64 Type 2 AppImage，内含 PeaZip 11.0.0 Qt6，由 linuxdeploy 生成；启动脚本强制 XCB、Adwaita Dark、固定缩放与字体 DPI，并把多个不匹配目录加入运行库和 Qt 搜索路径。其启动链未发现 `sudo`、`pkexec`、systemd、cron 或额外下载执行。官方 11.2.0 为当前稳定版并提供带 GitHub SHA-256 digest 的 Qt6 amd64 DEB；上游仓库标示 LGPL-3.0，官方 DEB 同时附带 GPL-3+ 版权说明，均允许按许可证再分发。
- **未确认事项：** 本次新增脚本生成的 AppImage 尚未经过 GitHub Actions 构建和 Linux 实机运行；官方包内少量 32 位旧格式后端未做实机功能确认。
- **修改建议：** 建议加入，但不直接迁移旧二进制。改用官方最新 Qt6 DEB 动态构建，保留旧包已经明确采用的 Qt6 技术路线，同时移除无依据的主题、缩放和平台强制设置。

## 变更记录

### 2026-09-20：接入官方最新 Qt6 AppImage 构建

- **原因：** 旧 AppImage 停留在 PeaZip 11.0.0，且缺少可维护的动态更新和供应链校验入口。
- **修改文件：** `peazip/build_peazip.sh`、`peazip/README.md`、`.github/appimage-apps.json`、`.github/workflows/build.yml`。
- **变更内容：** 新增官方 Release 动态解析、资产 URL 和 SHA-256 校验、DEB 元数据核对、官方程序与资源保留、Qt6 / Fcitx5 依赖收集、稳定产物名和版本清单接入。
- **已知结果：** 已完成旧产物、官方 11.2.0 资产和仓库外静态检查；提交后由正式 workflow 构建并发布，当前不把尚未执行的 Actions 或实机运行描述为已验证。
