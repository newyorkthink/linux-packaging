# BlueMail 构建流程与模板差异

## 采用专用流程的原因

BlueMail 的最终程序来自官方 Snap Store `latest/stable` 通道。现有 Electron 模板覆盖 DEB 和系统安装目录来源，没有对应的 Snap 元数据、SHA3-384 校验和资源整理阶段。本目录按已确认的 Snap 布局维护专用流程，登记在[打包分类](../../docs/packaging-classification.md#专用打包流程)，不新增模板。

公共步骤采用[quick-sharun 固定注释](../../docs/quick-sharun-comments.md)的原文。Snap 来源、实际资源位置和启动兼容处理使用 `# 本程序专属处理：`；协议注册使用公共 hook 的固定注释。应用脚本不重复实现下载、校验、通用解包或版本保存。

## 来源与依据

- [AUR bluemail 配方](https://github.com/archlinux/aur/blob/bluemail/PKGBUILD)及[来源元数据](https://github.com/archlinux/aur/blob/bluemail/.SRCINFO)表明该包使用预编译 Snap；本目录通过公共 Arch 安装入口让包管理器准备应用和依赖。
- 最终 Snap 由 `common/snap/download_stable_snap.sh` 独立选择当前稳定通道，核对名称、发布者、架构与官方 SHA3-384。版本、图标和 desktop 均来自这一次下载。
- 本次检索 pkgforge-dev 未找到对应的 BlueMail 打包仓库，不把本仓库处理标成逐字复用的官方代码。
- 资源布局、中文输入、启动参数、Gmail 登录及回调的既有证据保存在[应用 README](../README.md)。本次核对基于提交 `4e7d3154a0e093d2de3f518eb155c28bc5298128` 的完整脚本和公共接口；具体固定取值见[固定配置](./hardcoded.md)。

## 执行阶段与专属内容

| 阶段 | 实际处理及原因 | 对应位置 |
| --- | --- | --- |
| 应用安装 | 先安装统一基础包，再安装 AUR `bluemail` 和已确认的运行库、GTK3 输入模块。AUR 安装按其配方下载和校验，不代替后续独立下载。 | [构建代码](../build_bluemail.sh#L13) |
| 工作区 | 公共入口检查 x86_64，只清理本项目的 `AppDir`、`dist`、`work`；应用创建 `shared/bin` 作为 Snap 程序目录。 | [构建代码](../build_bluemail.sh#L16) |
| 来源与版本 | 公共 Snap 入口下载当前稳定版，将 stdout 保存到 `work/source-version.txt`；公共 `text` 来源在首次收集前读取该版本。 | [构建代码](../build_bluemail.sh#L22)、[构建代码](../build_bluemail.sh#L63) |
| 桌面资源 | 从同一次 Snap 提取 desktop 和 PNG，保留 `%U` 与 OAuth 协议声明。资源放在 `work`，不使用安装阶段的应用资源代替当前 Snap。 | [构建代码](../build_bluemail.sh#L28) |
| Snap 目录 | 仅移除指定 Snap 平台目录和启动脚本，保留应用自带 Electron 程序、Chromium 库、ICU、PAK、`locales` 与 `resources`。 | [构建代码](../build_bluemail.sh#L35) |
| 依赖收集 | 真实主程序、crashpad helper 与已确认动态加载的通知、密钥和托盘库同次收集；命令级库路径指向当前应用目录。 | [构建代码](../build_bluemail.sh#L70) |
| 打包配置 | `DEPLOY_GTK=1` 收集 GTK3 及已安装的输入模块；`NO_STRIP=1`、`STRACE_MODE=0` 保留当前符号与扫描方式，`VERSION` 使用本次 Snap 版本。 | [构建代码](../build_bluemail.sh#L57)、[构建代码](../build_bluemail.sh#L66) |
| 区域数据 | 首次收集后生成包内中文 locale，并追加标准语言变量和 `LOCPATH`。locale 不生成应用翻译，也不替代输入法模块。 | [构建代码](../build_bluemail.sh#L77) |
| 相邻资源 | `.env` 指向包内 `shared/bin` 的额外库目录和工作目录；将主程序以外的相邻资源链接到包装器目录，保留已确认的 Electron 查找关系。 | [构建代码](../build_bluemail.sh#L87)、[构建代码](../build_bluemail.sh#L129) |
| 启动参数 | `90-bluemail-arguments.hook` 在用户参数前加入 `--ozone-platform=x11 --no-sandbox`，只规范 `me.blueone.linux` URI 的斜杠形式，保留其余参数。 | [构建代码](../build_bluemail.sh#L92) |
| 协议注册 | 公共入口生成 `20-bluemail-protocol.hook`，用实际 AppImage 路径登记用户级 desktop；只设置 `me.blueone.linux` 默认处理程序，`mailto` 仅声明，不覆盖其默认程序。 | [构建代码](../build_bluemail.sh#L117) |
| 封装与保存 | quick-sharun 生成正式 AppImage 后，由公共保存入口检查产物、设置 0755 并写入最终 `dist/version.txt`。 | [构建代码](../build_bluemail.sh#L136)、[构建代码](../build_bluemail.sh#L139) |

## 公共接口与发布

下载、解包、版本读取、版本保存、工作区和协议 hook 均使用现有公共接口，本次不修改公共脚本的实现或参数。公共文档补充 Snap 的四参数接口、版本 stdout 和职责边界；应用专属布局及 OAuth 处理继续留在本目录。

正式入口仍为 `bluemail/build_bluemail.sh`，由现有 Arch matrix 构建并发布 `bluemail.AppImage`。本次完成代码、注释、参数、执行顺序及文档的静态核对，不将提交结果写成新增的实机通过记录。
