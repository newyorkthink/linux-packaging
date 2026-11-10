# BlueMail AppImage

## 用途与产物

本目录把 AUR [bluemail 软件包](https://aur.archlinux.org/packages/bluemail)配方引用的官方 x86_64 Snap 重新封装为 `bluemail.AppImage`，由 `.github/workflows/build.yml` 的标准 Arch Linux matrix 构建。公共安装入口保留本次 AUR 安装时下载的原始 Snap，重新核对同次来源摘要后导出；最终程序、图标和桌面入口均取自这份完整归档，版本跟随 AUR 配方，不再单独查询 Snap Store 的当前稳定版。

## 打包方式

- `common/arch/install_packages.sh --base` 安装统一基础包；公共工作区准备完成后，同一入口通过显式 `--aur-source` 模式安装 `bluemail` 及已确认的运行库和 GTK3 输入模块，并保留同次下载来源。
- 安装入口从同次 AUR 构建目录的 `.SRCINFO` 唯一匹配 `bluemail-{version}.snap`，按原配方摘要重新校验缓存，再导出 `work/bluemail.snap` 和 `work/source-version.txt`。当前配方使用 SHA-512，摘要由 AUR 配方提供；makepkg 校验照常执行，导出过程不再下载 Snap。
- `common/archive/extract_archive.sh` 解包 Snap。构建脚本保留 BlueMail 自带的 Electron/Chromium 程序、相邻库和资源，去掉 Snap 专用宿主运行时目录。
- Arch Linux 容器中的 quick-sharun 收集主程序依赖并生成默认入口。构建脚本把需要保持相邻关系的官方 Snap 程序、库和 Electron 资源解包到自己创建的 `AppDir/shared/bin/`，因此通过 `AppDir/.env` 把该目录设为额外库目录和工作目录；这不是所有 Snap 的固定路径。`90-bluemail-arguments.hook` 通过 quick-sharun 通用 hook 机制保留官方 Snap 使用的 `--ozone-platform=x11 --no-sandbox` 参数。桌面图标与 desktop 文件来自同一 Snap。
- `20-bluemail-protocol.hook` 在每次启动时，把本次实际的 AppImage 路径写成 `~/.local/share/applications/bluemail.desktop`（`Exec` 使用 `%U`），并在 `~/.config/mimeapps.list` 的 `[Default Applications]` 中把 `x-scheme-handler/me.blueone.linux` 指到该文件。不修改 `mailto` 的现有默认程序。quick-sharun 使用的 DWARFS AppImage 不能靠 appimagelauncher 完成这项注册。
- 将 ICU、PAK、`locales` 和 `resources` 以包内链接接到启动包装器旁，保持 Electron 按可执行文件目录查找资源的行为。
- 官方 Snap 自带 Electron/Chromium 运行时，本脚本保留其程序文件和资源，没有另外下载或打包独立的 Chromium 浏览器。构建环境安装 IBus 与 Fcitx5 的 GTK3 输入模块；本次 CI 日志确认 `DEPLOY_GTK=1` 收集了 `im-ibus.so` 和 `im-fcitx5.so`。启动入口不覆盖宿主输入法变量；2026-09-23 Linux 实机已确认邮件编辑框能够正常显示 IBus/Fcitx5 候选框并输入中文。

- 第一次依赖收集后生成包内 `zh_CN.UTF-8` locale，并把 `LANG`、`LANGUAGE`、`LC_MESSAGES` 和 `LOCPATH` 追加到现有 `.env`；输入法模块与语言数据分别处理，不覆盖宿主输入法变量。

本目录采用 Snap 专用流程，共用标准初始化、基础安装、打包元数据、locale、版本读取和最终保存步骤；Snap 解包布局、资源链接及 OAuth 处理留在应用脚本。入口、差异和依据见 [模板差异](./docs/template-deviations.md)、[固定配置](./docs/hardcoded.md)及[打包分类](../docs/packaging-classification.md#专用打包流程)。

## 运行

在 Linux 终端中，下载 Release 资产并赋予执行权限后运行：

```bash
# 启动已赋予执行权限的 BlueMail AppImage
./bluemail.AppImage
```

## 版本元数据

公共安装入口读取实际安装的上游版本，与同次 `.SRCINFO` 的 `pkgver` 核对一致后写入 `work/source-version.txt`；打包前由 `common/build/read_app_version.sh text` 读取，并通过 `VERSION` 传给 quick-sharun。最终 AppImage 成功生成后，`common/build/save_appimage_version.sh` 检查产物、统一执行权限并写入 `bluemail/dist/version.txt`，供正式工作流更新软件版本清单。

## 维护说明

上游 BlueMail 为专有软件，使用和再分发应遵守其许可条款。构建脚本不固定应用或打包工具版本。quick-sharun 默认入口、GUI 启动、邮件列表与编辑界面、中文输入、Gmail 登录和浏览器授权回调已有 Linux 实机记录确认；Outlook 发往 Gmail 的邮件已确认送达。

## 2026-09-23：中文输入修复

Linux 实机反馈邮件编辑框只能输入英文。检查此前 AppImage 的 GTK3 输入模块目录，未找到 `im-ibus.so` 和 `im-fcitx5.so`。本次仅在 `build_bluemail.sh` 的应用级依赖加入 `ibus` 与 `fcitx5-gtk`，保留已能启动的 Electron 入口。

## 2026-09-23：中文输入实机确认

用户在 Linux 实机运行当时的 `bluemail.AppImage`，BlueMail 邮件编辑框能够正常唤起中文输入法候选框，并将中文候选词上屏。该次确认对应自写 `AppRun.sh` 的旧入口，证明相邻库目录、工作目录、宿主输入法环境、`DEPLOY_GTK=1` 收集的 IBus/Fcitx5 GTK3 输入模块及 `--ozone-platform=x11 --no-sandbox` 参数组合有效；后续迁移必须完整保留这些行为。

## 2026-09-23：入口迁移至 quick-sharun 官方机制

构建脚本不再预先创建自写 `AppRun.sh`，改由 quick-sharun 生成默认入口；相邻库目录和工作目录写入 `AppDir/.env`，固定启动参数写入 `AppDir/bin/90-bluemail-arguments.hook`。自定义 hook 放入 `AppDir/bin/` 并由生成入口加载、运行时环境写入 `.env`，均沿用 quick-sharun 上游机制；`90-` 是本仓库用于在当前上游内置 hook 之后处理应用固定参数的顺序约定，不冒充上游保留编号。主程序、资源、依赖、输入法模块及 `--ozone-platform=x11 --no-sandbox` 参数均未改变。

## 2026-09-23：同名 Release 资产上传失败

Build BlueMail（run `35844883809`）已生成 AppImage，日志也显示两个 GTK3 输入模块进入 AppDir；发布时 `gh release upload --clobber` 对已有 `bluemail.AppImage` 连续返回 HTTP 422 `ReleaseAsset.name already exists`。共享 `.github/actions/build-anylinux/action.yml` 改为分页查找并只删除该同名旧资产，再上传新资产。

## 2026-09-24：quick-sharun 新入口实机确认

Linux 实机运行入口迁移后的 `bluemail.AppImage`，程序能够启动并加载邮件列表和编辑界面；编辑框能够显示 IBus/Fcitx5 中文候选并正常上屏。启动日志明确显示实际参数包含 `--ozone-platform=x11 --no-sandbox`，证明 `90-bluemail-arguments.hook` 已通过 quick-sharun 生成入口生效；挂载路径中的 `shared/bin/resources` 也被正常加载，证明 `.env` 中的相邻库目录和工作目录配置保持了官方 Snap 的 Electron 资源布局。日志中的 `latest-linux.yml` HTTP 404 来自 BlueMail 自身的自动更新检查地址，出现时主界面和已确认功能仍正常；本仓库继续通过官方 Snap 稳定通道构建更新，不为该上游更新地址改动当前打包入口。

## 2026-09-24：修正 Google OAuth 浏览器回调

Linux 实机添加 Gmail 账户时，BlueMail 正常调用外部浏览器完成 Google 授权；使用外部浏览器是 Google OAuth 的正常流程，不应改为 Electron 内嵌登录。授权完成后，浏览器取得 `me.blueone.linux://linux/google/oauth2redirect?...` 回调，但没有返回 BlueMail，应用一直停留在登录等待界面。核对上游 desktop 及 Flathub `net.blix.BlueMail` 的同类问题后确认，`Exec=bluemail %F` 中的 `%F` 只接收本地文件，无法把自定义协议 URI 交给程序；应使用能够接收 URI 的 `%U`。

构建脚本现将官方 desktop 的入口规范为 `Exec=bluemail %U`，并把协议声明规范为 `MimeType=x-scheme-handler/me.blueone.linux;x-scheme-handler/mailto;`，使完成桌面集成后的 AppImage 能接收浏览器 OAuth 回调。此前 Outlook 账户从 BlueMail 发往 Gmail 的邮件已在 Outlook 网页版“已发送邮件”和 Gmail 垃圾邮件中确认实际送达，证明 AppImage 的基础发信链路正常；Gmail 账户此前仍报 `unresponsive-server`。

## 2026-09-24：OAuth 回调仍被浏览器当成搜索

上一节只改了打进 AppImage 的 desktop。直接运行 AppImage 时，这个文件不会出现在宿主的 `applications` 目录里，系统仍然没有 `me.blueone.linux` 的处理程序。实机现象是授权页弹出“要打开 xdg-open 吗？”——Chromium 在查不到协议处理程序时就用这个名字——随后地址栏把 `me.blueone.linux:/linux/google/oauth2redirect?...` 当成搜索。这不是 BlueMail 自己打开了浏览器搜索，而是回调协议没有注册。XFCE 会话中，`xdg-mime default` 还会报 `default-url-scheme-handler not implemented for xfce`，所以不能只靠那条命令。

构建脚本现在另外写入 `20-bluemail-protocol.hook`。AppRun 在 `set -e` 下 source 它，因此 hook 在子 shell 里 `set +e`，失败不阻止启动，也不改 `"$@"`。它只在 `APPIMAGE` 指向真实文件时，把该绝对路径写入用户级 `bluemail.desktop`，并只强制 `x-scheme-handler/me.blueone.linux` 的默认程序；`mailto` 保持用户原来的客户端。同时导出 `CHROME_DESKTOP=bluemail.desktop`，让 Electron 的 `setAsDefaultProtocolClient` 指向同一文件，而不是挂载目录里的临时路径。已有授权码不能重复使用。

## 2026-09-24：OAuth 回调已送达但参数为 null

实机日志已有 `Received platform-specific URL` 和 `Handling platform-specific deep link`，说明协议注册生效、BlueMail 收到了回调。紧接着是 `Decoded URL param: null`，登录界面不结束。浏览器地址栏里的回调是 `me.blueone.linux://linux/google/oauth2redirect?...`，程序实际收到的是少一个斜杠的 `me.blueone.linux:/linux/...`。两种写法用 URL 解析结果不同：双斜杠的 host 是 `linux`、path 是 `/google/oauth2redirect`；单斜杠的 host 为空、path 变成 `/linux/google/oauth2redirect`。BlueMail 按前者取参数，所以解出来是 null。

`90-bluemail-arguments.hook` 现在在原有 `--ozone-platform=x11 --no-sandbox` 之前，把仅有一个斜杠的 `me.blueone.linux:/` 补成 `me.blueone.linux://`，已经是双斜杠的不动。这一步只改传给程序的参数，不改授权码本身。


## 2026-09-24：Gmail 登录已完成，协议注册改用公共入口

Linux 实机使用当时的 `bluemail.AppImage` 添加 Gmail 账户。日志仍出现 `Decoded URL param: null`，账户随后出现并进入完成设置，该行不代表登录失败。打开登录页用的是系统默认网页浏览器。协议注册改由 `common/desktop/write_scheme_hook.sh` 生成 `20-bluemail-protocol.hook`，注册的仍是 `me.blueone.linux`，不改 `mailto` 的现有默认程序。单斜杠补齐仍留在 `90-bluemail-arguments.hook`。

随后删掉全部邮箱并重新添加，登录回调仍能回到程序，账户可以再次加回。

## 2026-11-10：统一构建步骤和公共注释

正式入口为 `build_bluemail.sh`。脚本保留 Snap 稳定通道、完整 Electron 资源布局、GTK3 输入模块、固定启动参数、OAuth 协议注册与 URI 修正，统一采用公共工作区、版本读取和版本保存入口，并按标准步骤生成包内 locale。公共注释逐字使用固定注释表，专属处理在对应阶段单独注明；详细依据见本目录的配置与差异文档。

本次依据完整脚本、公共接口和既有实测记录完成静态核对。现有 Arch matrix 继续调用同一路径并发布 `bluemail.AppImage`。

## 2026-11-10：复用 AUR 安装来源

公共 Arch 安装入口新增显式 `--aur-source` 模式，BlueMail 在安装阶段保留完整原始 Snap，按同次 AUR 元数据重新校验后用于打包。当前 AUR 配方会删除安装目录中的部分 Chromium 库和桌面资源，因此本目录继续解包原始归档，不直接复制 `/opt/bluemail`。来源和版本随 AUR 配方动态更新，不固定应用版本或 Snap 修订号。

本次仅调整来源准备及其说明，解包后的资源布局、依赖收集、中文输入、locale、启动参数和 OAuth hook 均保留原样。
