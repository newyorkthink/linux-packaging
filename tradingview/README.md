# TradingView AppImage

## 用途与产物

本目录把 TradingView 官方稳定渠道 APT 仓库中的当前 amd64 DEB 重新封装为 `tradingview.AppImage`，沿用 `.github/workflows/build.yml` 的标准 Arch Linux matrix。构建先安装 AUR 的 [tradingview-bin-latest](https://aur.archlinux.org/packages/tradingview-bin-latest) 准备应用、依赖和桌面资源，再独立下载经过官方签名索引和 SHA-256 校验的 DEB；最终程序来自这份独立下载的安装包。

## 打包方式

- `common/arch/install_packages.sh` 分别安装公共基础工具和应用包、GTK3、Fcitx5、libsecret、libnotify 及 DEB 工具。原有 IBus、NSS、OpenSSL、SquashFS 工具继续由公共基础包提供。
- `common/download/download_apt_repository_deb.sh` 读取官方 `stable / jammy / multiverse` 仓库，验证官方密钥签名、Packages 和 DEB 的 SHA-256 与大小，并核对包名、amd64 架构和实际版本。版本按 Debian 规则动态选择，不使用 AUR 的静态版本字段。
- 公共归档入口解包 DEB，完整的 `opt/TradingView/` 原样复制到 `AppDir/bin/`，保留 Electron/Chromium、自带库、ICU、PAK、`locales`、`resources` 和 `chrome-sandbox`。不另装独立 Chromium，不再整理 Snap 宿主目录或追加资源链接。
- quick-sharun 对完整程序目录、`keytar.node` 和 `libnotify.so.4` 收集依赖。临时 `LD_LIBRARY_PATH` 让构建期间从当前程序目录解析私有库；运行时的额外库路径由 quick-sharun 的 Electron 部署机制写入，工作目录通过 `.env` 指向 `bin`。
- `DEPLOY_GTK=1` 保留 GTK3 和输入模块部署；第一次 quick-sharun 后按标准生成包内中文 locale，并追加语言环境。输入法继续使用宿主已有设置，不额外强制 IBus 或 Fcitx5。
- 原有 `--no-sandbox` 参数 hook 与 `tradingview://` 登录回调登记继续保留，用户参数原样传递。启动入口仍由 quick-sharun 生成，不自写 AppRun。

## 当前状态

| 范围 | 状态 |
| --- | --- |
| 原 Snap 路线的启动、图表、自选列表、中文输入、浏览器登录回调 | 2026-09-24 已有用户实机与虚拟机确认，完整记录保留在下方。 |
| 本次 DEB 来源、签名与摘要、包内目录、资源组装及构建入口 | 检查结果见本页末尾的 2026-11-02 记录。 |
| 新 DEB 路线的完整 AppImage 构建与实机运行 | 待验证。旧路线的实测结果保留，不直接代替新来源的验收。 |
| 真实交易、观点实际发布 | 尚无本项目的实测确认。 |

## 运行

在 Linux 终端中，下载 Release 资产并赋予执行权限后运行：

```bash
# 启动已赋予执行权限的 TradingView AppImage
./tradingview.AppImage
```

## 版本元数据

下载入口把同一份已校验 DEB 的完整 `Version` 写入 `tradingview-source-version.txt`。构建在依赖收集前通过 `read_app_version.sh text` 读取，保留 Debian 修订号，并继续向打包工具导出 `VERSION`。最终 AppImage 生成成功后，公共保存入口才写入 `tradingview/dist/version.txt`；正式工作流继续发布原来的资产名及软件版本清单。

## 维护说明

TradingView 为专有软件，使用和再分发应遵守其许可条款。构建脚本不固定应用或打包工具版本。2026-11-02 已针对 `tradingview`、`trading-view` 查找 pkgforge-dev，未查到专属打包仓库；本次按本仓库的 Electron 直接下载标准实现，不编造官方专属处理。

- [模板差异](docs/template-deviations.md)：两阶段来源、依赖覆盖、程序布局、中文环境、额外库和协议 hook。
- [固定参数与来源依据](docs/hardcoded.md)：实际 APT、AUR、目录、版本、运行参数及原始下载故障。
- [公共 APT 下载接口](../common/README.md#签名-apt-仓库中的官方-deb)：签名、摘要、版本选择和失败保护。

## 既有修复与实测历史

以下记录保留当时的实现及验证范围；其中 Snap 来源和 `shared/bin` 布局已由本次 DEB 标准流程替代。

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


## 2026-11-02：接入官方 DEB 并对齐直接下载标准

- 原始故障：[run 41420975694 的 TradingView Job](https://github.com/newyorkthink/linux-packaging/actions/runs/41420975694/job/125196247712) 在依赖安装后发生 HTTP 429、连接重置及超时，最终退出码为 28；没有运行到 quick-sharun 收集和封装。
- 修改：保留 quick-sharun 路线，先安装 AUR 的官方 DEB 配方，再通过已提交的公共 APT 入口独立下载并校验当前安装包；完整 `opt/TradingView` 放入 `AppDir/bin`，桌面资源读取系统安装结果。移除旧 Snap 平台清理和资源链接，版本读取、保存、下载与解包均复用公共入口。
- 保留：原 `NO_STRIP=1`、`STRACE_MODE=0`、临时私有库路径、`keytar.node` 与通知库收集、固定 `--no-sandbox` 命令及协议登记参数；输入法继续使用宿主配置。新增包内中文 locale，生成入口和额外库路径仍交给 quick-sharun。
- 文档：新增模板差异和固定参数说明，登记 Electron 直接下载分类、相关环境变量和上游核对结果；规范里的旧 Snap 示例不再列入 TradingView。原有 2026-09 修复和实机记录逐字保留。
- 验证：57 项隔离检查通过。复用已真实下载并校验的官方 `3.5.0-1` DEB 和签名索引，在同一公共入口重新验证签名、摘要及包身份，完成真实解包和 77 个官方程序 / 资源文件的逐项组装对比；实际生成并读取中文 locale；验证两阶段顺序、参数原样传递、移动路径后的协议 desktop、失败退出及最终版本保护，现有 Plan 仅选择 TradingView。Bash、标准注释顺序和原参数对照通过。
- 验证边界：包管理器安装和 quick-sharun 收集 / 封装在本次调度检查中使用替身，未执行完整 Arch AppImage 构建、GUI、图表或新包登录实测。临时检查不进入仓库，现有 workflow 与发布流程保持原样，提交后不等待或监控 Actions。
