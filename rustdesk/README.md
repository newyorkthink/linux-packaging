# RustDesk AppImage

## 来源和构建

`build_rustdesk.sh` 从 [RustDesk 官方正式 Release](https://github.com/rustdesk/rustdesk/releases)动态取得 x86_64 AppImage。公共入口校验 GitHub 发布的 SHA-256，并返回该资产对应的版本。构建在 Arch CI 容器运行，解包后保留官方运行目录和 ELF `AppRun`，在 `AppRun.env` 中设置 X11 会话类型。

构建按[直接 appimagetool](../Docs/packaging-classification.md#直接-appimagetool)流程封装为 `dist/rustdesk.AppImage`，成功后写入 `dist/version.txt`。工作区、工具准备和最终封装复用公共入口。解包、版本来源和 X11 设置见[专属差异](./docs/template-deviations.md)。

X11 的固定配置见[固定配置](./docs/hardcoded.md)。pkgforge-dev 从系统包收集并重新打包，本项目沿用 RustDesk 官方 AppImage 及其启动入口。源码核对和取舍见[上游打包差异](./docs/pkgforge-differences.md)。

## 2026-09-23：tty 显示服务器误判

用户提供的 1.4.9 官方 AppImage 截图显示 GUI 提示“当前显示服务器 tty 不支持，请切换到 X11”，终端日志没有明确缺库错误。RustDesk 对应版本源码的 `hbb_common` 支持 `RUSTDESK_FORCED_DISPLAY_SERVER`。新 `AppRun` 只在 `DISPLAY` 存在、`XDG_SESSION_TYPE=tty` 且没有 `WAYLAND_DISPLAY` 时指定 `x11`，然后执行未经修改的官方启动器；其他会话按官方原样运行。该修复不能给纯 tty 创建 X11 桌面。

用户现有 `runimage/setup_general_env.sh` 没有改动。

上述“新 `AppRun`”方案已被后续 Linux 实机结果否定，见下文记录。

## 2026-09-23：首次 CI 构建失败

首次 CI 在解包步骤报 `Permission denied`：公共下载入口保存官方 AppImage 时没有执行权限。公共解包脚本在调用官方 `--appimage-extract` 前为下载文件设置可执行位。

## 2026-09-23：恢复官方 ELF AppRun

Linux 实机运行重封装产物报 `APPRUN ERROR: Unable to open file: (null)`。先前把官方 ELF `AppRun` 移到 `AppRun.official` 并以 shell 脚本转发的方案已被实机否定；ELF 也不能像 shell 脚本一样直接插入环境变量语句。`build_rustdesk.sh` 现原样保留官方 `AppRun`，只重封装官方目录。

## 2026-09-23 自根目录原样迁入

以下记录来自当时根目录 `README.md` 的「当前待处理」。

- `rustdesk` / `wemeet`：2026-09-23 实机分别报告 `APPRUN ERROR: Unable to open file: (null)` 和缺少 `libwemeet.so`。启动入口已按实际打包方式调整，详见 [RustDesk](../rustdesk/README.md) 和 [腾讯会议](../wemeet/README.md)。

## 2026-09-23：在官方 AppRun.env 中设置 X11 会话

新截图仍显示“当前显示服务器 tty 不支持，请切换到 x11”；此前记录的 `export XDG_SESSION_TYPE=x11` 是该 X11 桌面会话的处理方式。上游 AppImage 的 ELF `AppRun` 读取 `AppRun.env` 并启动程序；因此 `build_rustdesk.sh` 保留 ELF 文件及其原有环境配置，仅替换 `AppRun.env` 中的 `XDG_SESSION_TYPE` 条目为 `x11`，不再移动或包装 ELF 入口，也不修改宿主会话。这个封装产物面向 X11；Wayland 会话不应使用该强制设置。

## 2026-09-23：X11 主机端实机确认

用户使用当前 RustDesk AppImage 后确认：启动时不再出现“当前显示服务器 tty 不支持，请切换到 x11”，手机可以连接电脑。此前 `AppRun.env` 设置 X11 会话类型的修改据此作为当前 X11 主机端稳定基线，打包问题结束；此前失败方案保留为当时的历史状态。

电脑主动连接另一设备时另见公共服务器要求登录，以及 `Failed to secure tcp: deadline has elapsed` 连接超时；这不影响上述手机连接电脑的已确认结果，也不据此修改打包代码。终端的 `org.freedesktop.ScreenSaver` D-Bus 警告尚无证据表明与连接超时有关。

## 2026-10-30：补齐 appimagetool 要求的权限

- 故障依据：[Actions run 41010671616](https://github.com/newyorkthink/linux-packaging/actions/runs/41010671616) 的 Build RustDesk。appimagetool continuous build 333（git `b082d2e`，2026-10-29）报 513 处权限错误，`var/lib/systemd` 和 `var/lib/dbus` 为 `0700`，没有生成 AppImage。
- 处理：`Common/linuxdeploy/package_appimage.sh` 在原封装命令前调用 `Common/appimage/prepare_appdir_for_appimagetool.sh`。`build_rustdesk.sh` 的调用参数和官方 ELF AppRun 未改。
- 验证范围：公共脚本做过语法检查和临时目录检查。没有重打 RustDesk，没有重跑 Actions。

## 2026-11-28：统一直接 appimagetool 封装流程

- 将构建分区、工作区和工具准备调用对齐直接封装规范。`--appimagetool` 只准备 appimagetool 和 Type 2 runtime。
- 沿用已确认的官方 ELF `AppRun`、`AppRun.env` X11 设置，以及正式 Release 返回的版本。
- 本次核对范围为脚本差异、公共调用、文档引用和 Git 文件模式。

## 实机验证

### 2026-11-28：用户实机验证通过

用户已确认 RustDesk `1.5.3` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 更新 | 强制重新下载 `rustdesk.AppImage`，更新工具的 SHA-256 校验通过并显示更新完成。 |
| 启动与版本 | 在 Linux 实机启动后可打开主界面和「关于 RustDesk」，页面显示版本 `1.5.3`。 |
| 网络状态 | 主界面状态显示「就绪」。 |
| Microsoft 授权入口 | 选择 Microsoft 登录后，程序进入等待授权状态并显示浏览器授权链接。 |

#### 运行观察

- 关闭窗口时终端输出 `Attempted to set message handler on an FlBinaryMessenger without an engine`，随后返回命令提示符。
