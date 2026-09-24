# TradingView AppImage

## 用途与产物

本目录把 TradingView 官方 Snap 的当前 `latest/stable` amd64 版本重新封装为 `tradingview.AppImage`，由 `.github/workflows/build.yml` 的标准 Arch Linux matrix 构建。AUR 的 [tradingview 配方](https://aur.archlinux.org/packages/tradingview)用作上游目录布局和依赖参考；正式构建直接获取官方 Snap，不依赖 AUR 维护者更新版本。

## 打包方式

- `common/snap/download_stable_snap.sh` 从 Snap Store 读取当前稳定版，核对发布者、架构和官方 SHA3-384，再下载 Snap。
- `common/archive/extract_archive.sh` 解包 Snap。构建脚本保留 TradingView 自带的 Electron/Chromium 程序、相邻库和资源，去掉 Snap 专用宿主运行时目录。
- Arch Linux 容器中的 quick-sharun 收集主程序及 `keytar.node` 所需的 `libsecret`，生成默认入口。构建脚本把需要保持相邻关系的官方 Snap 程序、库和 Electron 资源解包到自己创建的 `AppDir/shared/bin/`，因此通过 `AppDir/.env` 把该目录设为额外库目录和工作目录；这不是所有 Snap 的固定路径。`90-tradingview-arguments.hook` 通过 quick-sharun 通用 hook 机制保留官方 Snap 使用的 `--no-sandbox` 参数。桌面图标与 desktop 文件来自同一 Snap。
- 将 ICU、PAK、`locales` 和 `resources` 以包内链接接到启动包装器旁，保持 Electron 按可执行文件目录查找资源的行为。
- 官方 Snap 自带 Electron/Chromium 运行时，本脚本保留其程序文件和资源，没有另外下载或打包独立的 Chromium 浏览器。构建环境安装 IBus 与 Fcitx5 的 GTK3 输入模块；CI 日志确认 `DEPLOY_GTK=1` 收集了 `im-ibus.so` 和 `im-fcitx5.so`。启动入口不覆盖宿主输入法变量；2026-09-24 Linux 实机已确认观点编辑和商品代码搜索等输入框能够显示中文候选并正常上屏。官方说明 Snap 版在原生 Wayland 下可能不稳定，当前入口使用 X11。

## 运行

在 Linux 终端中，下载 Release 资产并赋予执行权限后运行：

```bash
# 启动已赋予执行权限的 TradingView AppImage
./tradingview.AppImage
```

## 版本元数据

成功生成 AppImage 后，把本次 Snap Store 稳定版的实际版本写入 `tradingview/dist/version.txt`，供正式工作流更新软件版本清单。

## 维护说明

TradingView 为专有软件，使用和再分发应遵守其许可条款。构建脚本不固定应用或打包工具版本。迁移后的 quick-sharun 默认入口、GUI 启动、图表加载和中文输入已有 Linux 实机截图及运行日志确认；登录、交易和观点实际发布仍需分别核对。

## 2026-09-23：中文输入修复待实机验证

Linux 实机反馈观点编辑框只能输入英文。检查此前 AppImage 的 GTK3 输入模块目录，未找到 `im-ibus.so` 和 `im-fcitx5.so`。本次仅在 `build_tradingview.sh` 的应用级依赖加入 `ibus` 与 `fcitx5-gtk`，保留已能启动并加载图表的 Electron 入口；新产物中文输入尚待实机验证。

## 2026-09-23：入口迁移至 quick-sharun 官方机制

构建脚本不再预先创建自写 `AppRun.sh`，改由 quick-sharun 生成默认入口；相邻库目录和工作目录写入 `AppDir/.env`，固定启动参数写入 `AppDir/bin/90-tradingview-arguments.hook`。自定义 hook 放入 `AppDir/bin/` 并由生成入口加载、运行时环境写入 `.env`，均沿用 quick-sharun 上游机制；`90-` 是本仓库用于在当前上游内置 hook 之后处理应用固定参数的顺序约定，不冒充上游保留编号。主程序、资源、依赖及 `--no-sandbox` 参数均未改变；此前 GUI 启动和图表加载基线继续保留，迁移后的新产物尚未构建和实机确认，中文输入仍待确认。

## 2026-09-23：同名 Release 资产上传失败

Build TradingView（run `35844883809`）已生成 AppImage，日志也显示两个 GTK3 输入模块进入 AppDir；发布时 `gh release upload --clobber` 对已有 `tradingview.AppImage` 连续返回 HTTP 422 `ReleaseAsset.name already exists`。共享 `.github/actions/build-anylinux/action.yml` 改为分页查找并只删除该同名旧资产，再上传新资产；提交后的构建、发布和中文输入尚未验证。

## 2026-09-24：quick-sharun 新入口实机确认

Linux 实机运行入口迁移后的 `tradingview.AppImage`，程序能够启动并进入 `cn.tradingview.com/chart/`，图表、自选列表和指标正常加载；观点编辑框与商品代码搜索框能够显示 IBus/Fcitx5 中文候选并正常上屏，视频观点预览界面也能够打开。运行日志显示 Electron 从挂载目录的 `bin/resources` 加载应用资源并成功恢复图表布局，证明 quick-sharun 生成入口、`.env` 运行环境和包内资源链接能够共同保持官方 Snap 的相对资源布局。本次确认未覆盖账号重新登录、真实交易或观点实际发布，不把这些功能写成已验证。


## 2026-09-24：注册 tradingview:// 登录回调

登录会打开系统默认网页浏览器。官方 desktop 使用 `tradingview://`，`Exec` 必须带 `%U` 才能把回调交回程序。直接运行 AppImage 时，包内 desktop 不会进入宿主的 `applications` 目录。构建脚本现将入口规范为 `Exec=tradingview %U`，并用 `common/desktop/write_scheme_hook.sh` 在启动时把当前 AppImage 注册为 `x-scheme-handler/tradingview` 的处理程序。登录回调是否回到程序尚待实机确认。


## 2026-09-24：tradingview:// 登录回调实机确认

Linux 实机重新登录。浏览器打开 `tradingview://browser-auth/?token=...`，并提示使用 TradingView 打开该链接。确认后程序进入已登录界面，图表加载到 `cn.tradingview.com/chart/`。中间仍会先到系统默认浏览器再点一次打开，这不表示回调失败。本次确认登录回调可以回到程序；交易和观点发布仍未在本次范围内验证。

另一台虚拟机同样完成登录并加载图表。交易和观点发布仍未验证。
