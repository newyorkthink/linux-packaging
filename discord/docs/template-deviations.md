# Discord 模板差异说明

## 当前标准与生成来源

[build_discord.sh](../build_discord.sh) 由固定模板 [linuxdeploy-gtk-deb.sh](../../templates/appimage/linuxdeploy-gtk-deb.sh) 完整生成，只填写允许变化的参数，正文、注释、顺序及空行原样保留。当前流程登记在[打包分类](../../docs/packaging-classification.md#linuxdeploy)，不再作为 quick-sharun 专用流程。

生成器运行 [42782651674](https://github.com/newyorkthink/linux-packaging/actions/runs/42782651674) 使用提交 `06715f116aab3ad54e4616b284a837ee38835545` 的模板与请求。输出 SHA-256 为 `da70e6600df9188533c16e1b6ec5b8864cdb9c5410011f9f60d413685325b043`；正式脚本直接采用该输出，覆盖时同步清空请求。

## 应用参数

| 参数 | 取值与依据 |
| --- | --- |
| 模板与构建环境 | `appimage/linuxdeploy-gtk-deb.sh`；Ubuntu 22.04 runner，直接运行，不使用容器。 |
| `APP_NAME` | `discord`，对应构建目录、发布资产与版本登记。 |
| `DEB_URL` | `https://discord.com/api/download?platform=linux&format=deb`，Discord 官方稳定版 Linux DEB。 |
| `DEB_FILENAME` | `discord.deb`，本次下载包的存放名称。 |
| `DEB_PACKAGE` / `DEB_ARCH` | `discord` / `amd64`，在安装前核对包身份。 |
| `APP_BIN_DIR` / `APP_LIB_DIR` | `usr/share/discord`，保留官方应用及相邻库布局。 |
| `MAIN_EXECUTABLE` | `usr/share/discord/Discord`，AppRun 直接执行官方入口并保留参数。 |
| `GIO_MODULE_DIR` | `usr/lib/x86_64-linux-gnu/gio/modules`，与 Ubuntu amd64 的 GTK3 模块布局对应。 |
| `APT_PACKAGES` | 标准 GTK3 开发、资源和 IBus 依赖；DEB 自身依赖由公共安装入口解析。 |

本次未提供官方 SHA-256，公共入口仍记录实际下载文件的 SHA-256；该记录不作为官方摘要校验的证明。后续来源提供官方摘要时，可通过同一模板的 `DEB_SHA256` 参数传入，无需应用自行实现下载或校验。

## 公共阶段

按标准顺序复用工作区准备、APT 安装、linuxdeploy 工具准备、空 AppDir 初始化、官方 DEB 下载与安装解包、完整 AppRun、GTK3 依赖部署和最终 appimagetool 封装。版本从所安装并解包的同一份 DEB 读取，由最终封装入口写入 `dist/version.txt`。

正式脚本没有模板外的附加代码。原版 [build_discord_old.sh](../build_discord_old.sh) 保留旧 quick-sharun 流程，不参与 Actions；旧模块、Krisp、图形和语言处理均未恢复到新路线。完整故障历史原样保留在 [README](../README.md)。

本次已完成生成器语法检查和静态核对，AppImage 构建与桌面运行结果尚未验证。
