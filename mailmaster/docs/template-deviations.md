# MailMaster 模板差异

MailMaster 是自带 Qt 5 和 CEF 的程序，使用 [quick-sharun 流程](../../anylinux_projects.md)及[固定注释标准](../../docs/quick-sharun-comments.md)。程序文件来自独立下载的 DEB，系统安装提供依赖和配方生成的兼容文件。

## 来源与版本

[AUR 的 .SRCINFO](https://github.com/archlinux/aur/blob/28daf15d8ff9c1efe75dbe2edd1e0673b3ffbe46/.SRCINFO)同时列出主 DEB、NSS Wrapper DEB、GConf stub、桌面资源和许可证。[PKGBUILD](https://github.com/archlinux/aur/blob/28daf15d8ff9c1efe75dbe2edd1e0673b3ffbe46/PKGBUILD)给出实际安装处理。链接固定到本次核对的快照作为证据，正式构建读取 AUR 当前配方。已检索 pkgforge-dev，未找到对应 MailMaster 打包项目。

公共入口按 `mailmaster-{version}.deb` 精确选择主包，并从同一来源组的对应位置读取摘要。第一阶段交给 yay / makepkg 按原配方安装，其余来源仍由配方处理。第二阶段独立下载、校验和解包主 DEB，公共入口核对 DEB 版本与 AUR `pkgver` 一致。GitHub Actions 的镜像可达性仍待验证。

## 专属处理

| 阶段 | 处理 | 原因及适用范围 |
| --- | --- | --- |
| 复制程序 | 完整复制 DEB 的 `opt/mailmaster/.` 到 `AppDir/bin/`。 | Qt、CEF、主程序及数据按原相对布局读取。 |
| 准备兼容文件 | 从 AUR 安装目录复制 `launch.sh`、NSS Wrapper、GConf stub，并保留 AUR 安装的许可证。 | 这些文件由该配方提供。主程序和相邻资源仍取自独立下载的 DEB。 |
| 处理插件 | 按 AUR 配方停用 XCB GL 集成插件和旧 Fcitx 插件。把 Arch 的 Qt 5 Fcitx5 模块放入应用插件目录，与自带 Qt 5 IBus 模块在同一次 quick-sharun 调用中收集。 | 应用使用自身 Qt 5 插件目录。两种模块所需的 Qt 符号已核对，实机输入待验证。 |
| 处理运行库 | 将 `libsasl2.so.3` 放入包内，`libsasl2.so.2` 指向同目录的该库。 | 维持原 AppImage 的库名兼容处理，避免运行时依赖 AUR 的系统绝对链接。 |
| 收集依赖 | 使用程序目录及其 `lib` 作为优先库路径，保留原 curl、hostname、NSS、PKCS#11 和 GTK、图形、音频部署设置。 | 让 quick-sharun 优先解析应用私有 Qt / CEF 库。输入法显式收集只传入应用使用的 Qt 5 模块。 |
| 启动环境 | 在第一次 quick-sharun 后向 `.env` 追加 locale、Qt 插件路径、库路径和工作目录。 | 运行时路径以 `SHARUN_DIR` 为基准，继续使用包内相邻资源。 |
| 启动参数 | `90-mailmaster-arguments.hook` 清除宿主 Qt 主题覆盖，保留宿主设置的 `QT_IM_MODULE`，默认使用 IBus，并在用户参数前加入 `--no-sandbox`。 | 保留原启动行为，由 quick-sharun 生成入口。包内 `chrome-sandbox` 权限为 0755。 |

## 附件选择器

在收集依赖前单行调用 `patches/prepare_attachment_dialog.sh`。该脚本用 Arch `qt5-base` 的头文件编译仓库自己的兼容层，链接 DEB 自带的 Qt 库。使用 patchelf 只重定向包内 `libmastercore.so` 对 `QFileDialog::getOpenFileNames` 的导入，保留原 `Qt_5` 符号版本，不设置全局预加载。缺少该导入时跳过补丁并输出提示。

兼容层用同一 QObject 翻译上下文匹配「选择附件」标题，只处理空目录与包内工作目录同时出现的情况，保留筛选条件、用户选择和其他对话框。该处理依赖 MailMaster 的 Qt 5 调用方式，不推广到其他应用。

以上运行兼容处理依赖 MailMaster 的 AUR 配方、私有 Qt / CEF 及目录布局，适用范围为 MailMaster。固定值依据见[固定配置](./hardcoded.md)，验证范围见 [README](../README.md)。
