# BlueMail AppImage

## 用途与产物

本目录把 BlueMail 官方 Snap 的当前 `latest/stable` amd64 版本重新封装为 `bluemail.AppImage`，由 `.github/workflows/build.yml` 的标准 Arch Linux matrix 构建。AUR 的 [bluemail 配方](https://aur.archlinux.org/packages/bluemail)用作原始目录布局和依赖参考；正式构建直接获取官方 Snap，不依赖 AUR 维护者更新版本。

## 打包方式

- `common/snap/download_stable_snap.sh` 从 Snap Store 读取当前稳定版，核对发布者、架构和官方 SHA3-384，再下载 Snap。
- `common/archive/extract_archive.sh` 解包 Snap。构建脚本保留 BlueMail 自带的 Electron/Chromium 程序、相邻库和资源，去掉 Snap 专用宿主运行时目录。
- Arch Linux 容器中的 quick-sharun 收集主程序依赖并生成默认入口。构建脚本把需要保持相邻关系的官方 Snap 程序、库和 Electron 资源解包到自己创建的 `AppDir/shared/bin/`，因此通过 `AppDir/.env` 把该目录设为额外库目录和工作目录；这不是所有 Snap 的固定路径。`90-bluemail-arguments.hook` 通过 quick-sharun 通用 hook 机制保留官方 Snap 使用的 `--ozone-platform=x11 --no-sandbox` 参数。桌面图标与 desktop 文件来自同一 Snap。
- 将 ICU、PAK、`locales` 和 `resources` 以包内链接接到启动包装器旁，保持 Electron 按可执行文件目录查找资源的行为。
- 官方 Snap 自带 Electron/Chromium 运行时，本脚本保留其程序文件和资源，没有另外下载或打包独立的 Chromium 浏览器。构建环境安装 IBus 与 Fcitx5 的 GTK3 输入模块；本次 CI 日志确认 `DEPLOY_GTK=1` 收集了 `im-ibus.so` 和 `im-fcitx5.so`。启动入口不覆盖宿主输入法变量；2026-09-23 Linux 实机已确认邮件编辑框能够正常显示 IBus/Fcitx5 候选框并输入中文。

## 运行

在 Linux 终端中，下载 Release 资产并赋予执行权限后运行：

```bash
# 启动已赋予执行权限的 BlueMail AppImage
./bluemail.AppImage
```

## 版本元数据

成功生成 AppImage 后，把本次 Snap Store 稳定版的实际版本写入 `bluemail/dist/version.txt`，供正式工作流更新软件版本清单。

## 维护说明

上游 BlueMail 为专有软件，使用和再分发应遵守其许可条款。构建脚本不固定应用或打包工具版本。迁移后的 quick-sharun 默认入口、GUI 启动、邮件列表与编辑界面和中文输入已有 Linux 实机截图及启动日志确认；邮件发送仍需单独核对。

## 2026-09-23：中文输入修复待实机验证

Linux 实机反馈邮件编辑框只能输入英文。检查此前 AppImage 的 GTK3 输入模块目录，未找到 `im-ibus.so` 和 `im-fcitx5.so`。本次仅在 `build_bluemail.sh` 的应用级依赖加入 `ibus` 与 `fcitx5-gtk`，保留已能启动的 Electron 入口；新产物中文输入尚待实机验证。

## 2026-09-23：中文输入实机确认

用户在 Linux 实机运行当时的 `bluemail.AppImage`，BlueMail 邮件编辑框能够正常唤起中文输入法候选框，并将中文候选词上屏。该次确认对应自写 `AppRun.sh` 的旧入口，证明相邻库目录、工作目录、宿主输入法环境、`DEPLOY_GTK=1` 收集的 IBus/Fcitx5 GTK3 输入模块及 `--ozone-platform=x11 --no-sandbox` 参数组合有效；后续迁移必须完整保留这些行为。

## 2026-09-23：入口迁移至 quick-sharun 官方机制

构建脚本不再预先创建自写 `AppRun.sh`，改由 quick-sharun 生成默认入口；相邻库目录和工作目录写入 `AppDir/.env`，固定启动参数写入 `AppDir/bin/90-bluemail-arguments.hook`。自定义 hook 放入 `AppDir/bin/` 并由生成入口加载、运行时环境写入 `.env`，均沿用 quick-sharun 上游机制；`90-` 是本仓库用于在当前上游内置 hook 之后处理应用固定参数的顺序约定，不冒充上游保留编号。主程序、资源、依赖、输入法模块及 `--ozone-platform=x11 --no-sandbox` 参数均未改变；迁移后的新产物尚未重新构建和实机确认。

## 2026-09-23：同名 Release 资产上传失败

Build BlueMail（run `35844883809`）已生成 AppImage，日志也显示两个 GTK3 输入模块进入 AppDir；发布时 `gh release upload --clobber` 对已有 `bluemail.AppImage` 连续返回 HTTP 422 `ReleaseAsset.name already exists`。共享 `.github/actions/build-anylinux/action.yml` 改为分页查找并只删除该同名旧资产，再上传新资产；提交后的构建、发布和中文输入尚未验证。

## 2026-09-24：quick-sharun 新入口实机确认

Linux 实机运行入口迁移后的 `bluemail.AppImage`，程序能够启动并加载邮件列表和编辑界面；编辑框能够显示 IBus/Fcitx5 中文候选并正常上屏。启动日志明确显示实际参数包含 `--ozone-platform=x11 --no-sandbox`，证明 `90-bluemail-arguments.hook` 已通过 quick-sharun 生成入口生效；挂载路径中的 `shared/bin/resources` 也被正常加载，证明 `.env` 中的相邻库目录和工作目录配置保持了官方 Snap 的 Electron 资源布局。日志中的 `latest-linux.yml` HTTP 404 来自 BlueMail 自身的自动更新检查地址，出现时主界面和已确认功能仍正常；本仓库继续通过官方 Snap 稳定通道构建更新，不为该上游更新地址改动当前打包入口。邮件发送未在本次截图范围内验证。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `README.md` 的「当前待处理」，未改写。

- `bluemail` / `tradingview`：2026-09-23 实机反馈中文无法输入；旧产物缺 IBus/Fcitx5 GTK3 模块，构建脚本已补模块包。新产物中文输入仍待实机确认，详见 [BlueMail](../bluemail/README.md) 和 [TradingView](../tradingview/README.md)。
