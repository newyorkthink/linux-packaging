# Grok App

## 用途与产物

本目录把 [RongleCat/grok-app](https://github.com/RongleCat/grok-app) 官方 Linux amd64 DEB 重新封装为 AnyLinux AppImage，最终发布资产固定为 `grok-app.AppImage`。

这不是 `grok-bot`。Grok Bot 是另一个 Electron 桌面端，仍由 `grok-bot/` 单独打包。

上游来源：

- 仓库：`https://github.com/RongleCat/grok-app`
- Linux 安装说明：仓库 `README_ZH.md` 的 AppImage / deb 一节
- 官方资产：最新正式 semver Release 中的 `Grok_<版本>_amd64.deb`

构建不固定应用版本。`build_grok-app.sh` 通过 `common/github/download_latest_stable_release_asset.sh` 选择版本号最高的正式 Release，只接受唯一匹配的 `Grok_{version}_amd64.deb`，并校验 GitHub SHA-256 与 DEB 包名 `grok`、架构 `amd64`。

## 技术栈

Grok App Linux 桌面端是 Tauri 2 / wry 程序，链接 GTK 3 与 WebKitGTK 4.1。官方 `v0.2.38` DEB 只包含：

- `usr/bin/grok-app`
- `usr/share/applications/Grok.desktop`
- hicolor 图标，最大的普通尺寸是 `128x128`

官方 DEB 依赖宿主的 `libwebkit2gtk-4.1-0`、`libgtk-3-0` 和 `libayatana-appindicator3-1`。ELF NEEDED 包含 `libwebkit2gtk-4.1.so.0`、`libgtk-3.so.0` 和 `libjavascriptcoregtk-4.1.so.0`。托盘库不在 NEEDED 中，由程序运行时加载。

官方 AppImage 会在发现宿主 WebKitGTK 4.1 时改用宿主库，以避免内置 WebKit 在部分 Wayland 主机上黑屏，以及卸载 AppImage 时 WebKit 子进程 SIGBUS。该逻辑在上游 `src-tauri/src/linux_webkit.rs`。本目录不修改官方二进制。

## 打包方式

当前采用 Arch Linux + quick-sharun，与仓库里另一套 Tauri / WebKitGTK 基线一致：

1. `common/build/prepare_x86_64_workspace.sh` 只清理本目录的 `source`、`AppDir` 和 `dist`。
2. `common/arch/install_packages.sh --base` 安装统一基础包，再追加 `dpkg`、`gtk3`、`webkit2gtk-4.1`、`ibus`、`fcitx5-gtk` 和 `libayatana-appindicator`。
3. 公共下载入口取得官方 DEB，公共归档入口按原始布局解包。
4. 沿用官方 desktop，把 `Exec` 改为 `grok-app %U`，补上 `Categories=Development;`。图标使用官方 `128x128` 的 `grok-app.png`。
5. quick-sharun 收集主程序、`libayatana-appindicator3.so.1`、GTK 3 的 `im-ibus.so` 与 `im-fcitx5.so`。`DEPLOY_GTK`、`DEPLOY_OPENGL` 和 `DEPLOY_WEBKIT2GTK` 打开，`WEBKIT2GTK_DIR` 指向 `/usr/lib/webkit2gtk-4.1`。
6. 在 quick-sharun 生成的 `.env` 末尾写入包内 `zh_CN.UTF-8`。不写 `LC_ALL`，不写 `GTK_IM_MODULE`，不覆盖 `AppRun`。`.env` 追加内容从 `LANG=` 开始，前面不留空行。
7. `AppDir/bin/15-grok-host-bwrap.hook` 在宿主存在 `/usr/bin/bwrap` 时，把 `/usr/bin` 和 `/bin` 放到 PATH 最前，包内 bin 留在最后。不删除包内 `bwrap`，也不覆盖 `AppRun`。
8. 公共协议 hook 注册 `grok://` 和官方 `application/vnd.grok.skin`。
9. `quick-sharun --make-appimage` 生成 `dist/grok-app.AppImage`，成功后由 `common/build/save_appimage_version.sh` 写入 `dist/version.txt`。

统一 workflow 中按标准 matrix 项构建，本项目不使用独立 Job。

## 中文环境与输入

官方 Linux DEB 和 AppImage 都没有包内 `zh_CN.UTF-8`，也没有 GTK 3 输入模块。界面语言文件可以是中文，但输入法客户端模块不在包里。

本目录补上：

- `AppDir/lib/locale/zh_CN.utf8`，以及 `LANG`、`LANGUAGE`、`LC_MESSAGES`、`LOCPATH`
- `/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so`
- `/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so`

两套模块都放进包。宿主已经配置 IBus 或 Fcitx5 时，沿用宿主的选择，不在包内强制其中一套。

宿主已安装 WebKitGTK 4.1 时，官方程序会把库搜索路径改到宿主目录。此时文本框使用的是宿主 GTK 的输入模块，包内模块只在没有宿主 WebKit、程序继续使用包内 GTK 时生效。中文 locale 写在启动环境里，这次重执行不会清掉。输入法守护进程仍由宿主会话提供，AppImage 不启动 `ibus-daemon` 或 `fcitx5`。

## 运行

发布资产下载后，在该文件所在目录执行：

```bash
./grok-app.AppImage
```

构建目录中的对应文件是 `dist/grok-app.AppImage`。程序仍需要本机的 Grok Build CLI，以及发行版安装的 `bubblewrap`（`/usr/bin/bwrap`）。沙箱策略仍由 Grok CLI 决定，本目录不把沙箱关掉。`bwrap: unknown cap: --proc` 已由 `15-grok-host-bwrap.hook` 修好，2026-10-07 实机确认 CLI 使用 `/usr/bin/bwrap`。包内 `bin/bwrap` 留给 WebKit，不删除。用户命名空间和 WebKit 显示问题沿用官方说明。

## 托盘图标

Linux 托盘图标由上游编译进 `grok-app`，本目录不替换。深色状态栏上可能看不见，托盘菜单仍可用。不是缺 `libayatana-appindicator`，也不需要 `librsvg`。

## 2026-09-29：新增重打包并补上中文输入环境

- **现象：** 官方 Linux 包没有中文 locale，也没有与 GTK 3 匹配的 IBus / Fcitx5 输入模块。
- **核查：** `v0.2.38` 的 `Grok_0.2.38_amd64.deb` 只含主程序、desktop 和图标；依赖声明为 WebKitGTK 4.1、GTK 3 和 Ayatana。`readelf` 未见 ayatana 与输入模块。上游 `linux_webkit.rs` 只处理宿主 WebKit 切换、黑屏和 SIGBUS。
- **处理：** 新增 `grok-app/build_grok-app.sh`，从官方 DEB 动态重打包；打入 WebKitGTK 4.1、OpenGL、GTK 3、两套输入模块、托盘库和包内 `zh_CN.UTF-8`。
- **接入：** 标准 matrix 清单项和手动构建下拉项，资产名为 `grok-app.AppImage`，版本键为 `grok-app`。
- **验证状态：** 已做脚本语法、清单 JSON、下拉选项和 export 登记的静态核对。未运行构建，未做实机中文输入验收。

## 2026-09-30：深色状态栏上看不到托盘图标

- **现象：** 中文可以输入，托盘菜单可以打开，深色状态栏上几乎看不到图标。
- **核查：** 上游 `src-tauri/src/tray.rs` 在 Linux 使用 `include_bytes!("../icons/tray-32.png")`。该图为 32×32，不透明像素全是纯黑。macOS 把图标当模板反色，Windows 有浅色和深色两套，Linux 没有。官方 DEB 没有单独的托盘图文件。`libayatana-appindicator` 已打进包；弃用警告和菜单快捷键警告与图标颜色无关。
- **处理：** 不改 `build_grok-app.sh`，不补图标库，也不改成自行编译。编译期内嵌的纯黑图标无法在重打包时换掉。
- **验证状态：** 图标内容和上游分支为静态核对。中文输入和托盘菜单可用来自运行反馈。这次没有改包，也没有新的构建。

## 2026-10-07：Agent 进程结束，`bwrap: unknown cap: --proc`

- **现象：** 界面能打开，发消息后显示「Agent 进程已结束」。日志为 `SANDBOX_BLOCKED`，stderr 是 `bwrap: unknown cap: --proc`。
- **核查：** 与 `chatgpt/` 2026-08-31 的 Codex 沙盒故障相同。quick-sharun 把包内 bin 放在 PATH 最前，Grok CLI 用到打包工具带入的 `bwrap`，而不是宿主 `/usr/bin/bwrap`。不是登录 401，也不是把沙箱关掉。
- **处理：** 增加 `AppDir/bin/15-grok-host-bwrap.hook`。宿主有 `/usr/bin/bwrap` 时，PATH 为 `/usr/bin`、`/bin`、原宿主 PATH、包内 bin。不覆盖 AppRun。同时删掉 `.env` 里 `LANG=` 前面的空行。
- **验证状态：** 对照 ChatGPT 同一错误字符串和 hook 机制做了静态核对。未重打 AppImage，未做实机沙盒验收。

## 2026-10-07：实机确认宿主 bwrap 已生效

- **现象：** 上一节写「未做实机沙盒验收」，只表示当时还没跑。随后新包已经打出，并在本机跑过沙箱命令。
- **核查：** 解出的 AppImage 含 `AppDir/bin/15-grok-host-bwrap.hook`。宿主有 `/usr/bin/bwrap` 时，PATH 把 `/usr/bin` 和 `/bin` 放在包内 bin 前面。`AppDir/bin/bwrap` 仍在，是 WebKit 用的 sharun 包装，不删除。
- **实机：** 沙箱内执行命令，输出 `sandbox-ok` 和 `/usr/bin/bwrap`。没有 `bwrap: unknown cap: --proc`，没有 `SANDBOX_BLOCKED`。回合以 `stop=end_turn` 正常结束。
- **不是本问题：** 同一条命令末尾再执行一层 `bwrap`，得到 `exit:1`，stderr 是 `No permissions to create a new namespace`。外层沙箱已经在跑，里面不能再新建 user namespace。不要据此重开 PATH 问题。
- **结论：** `unknown cap: --proc` 这条已修好。以后没有新的 `unknown cap: --proc` 或 `SANDBOX_BLOCKED`，不要再怀疑 `15-grok-host-bwrap.hook`。

