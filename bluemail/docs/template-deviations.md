# BlueMail 构建流程与模板差异

## 采用专用流程的原因

BlueMail 的最终程序来自 AUR 配方引用的官方 Snap，复用本次安装下载并校验的完整原始归档。现有 Electron 模板覆盖 DEB 和系统安装目录来源，没有对应的 Snap 来源保留与资源整理阶段。本目录按已确认的 Snap 布局维护专用流程，登记在[打包分类](../../docs/packaging-classification.md#专用打包流程)，不新增模板。

公共步骤采用[quick-sharun 固定注释](../../docs/quick-sharun-comments.md)的原文。Snap 来源、实际资源位置和启动兼容处理使用 `# 本程序专属处理：`；协议注册使用公共 hook 的固定注释。应用脚本不重复实现下载、校验、通用解包或版本保存。

## 来源与依据

- [AUR bluemail 配方](https://github.com/archlinux/aur/blob/93194394dc31b63f585963289f24700e09fd716d/PKGBUILD)及[来源元数据](https://github.com/archlinux/aur/blob/93194394dc31b63f585963289f24700e09fd716d/.SRCINFO)表明该包使用预编译 Snap，且安装时会删除部分 Chromium 库和桌面资源；打包继续使用完整原始归档。
- 公共 Arch 安装入口的显式 `--aur-source` 模式保留同次来源缓存，从本次构建目录的 `.SRCINFO` 唯一匹配 `bluemail-{version}.snap`，按原索引读取摘要并重新校验。当前配方使用 SHA-512；实际安装版本须与同次 `pkgver` 一致，版本跟随 AUR，不另行查询 Snap Store 稳定通道。
- 本次检索 pkgforge-dev 未找到对应的 BlueMail 打包仓库，不把本仓库处理标成逐字复用的官方代码。
- 资源布局、中文输入、启动参数、Gmail 登录及回调的既有证据保存在[应用 README](../README.md)。本次来源调整以提交 `e9121a2da0facfa3223b76236e2dc98fc4225209` 为基线，核对完整脚本、公共接口及上述 AUR 快照；具体固定取值见[固定配置](./hardcoded.md)。

## 执行阶段与专属内容

| 阶段 | 实际处理及原因 | 对应位置 |
| --- | --- | --- |
| 基础安装 | 通过公共 Arch 入口安装统一基础包。 | [构建代码](../build_bluemail.sh#L11) |
| 工作区 | 公共入口检查 x86_64，只清理本项目的 `AppDir`、`dist`、`work`；应用创建 `shared/bin` 作为 Snap 程序目录。 | [构建代码](../build_bluemail.sh#L14) |
| 应用、来源与版本 | `--aur-source` 安装 AUR `bluemail` 和已确认的运行库、GTK3 输入模块，并导出同次校验通过的完整 Snap 与来源版本。公共 `text` 来源在首次收集前读取该版本。 | [构建代码](../build_bluemail.sh#L21)、[构建代码](../build_bluemail.sh#L64) |
| 桌面资源 | 从本次导出的完整 Snap 提取 desktop 和 PNG，保留 `%U` 与 OAuth 协议声明，资源放在 `work`。 | [构建代码](../build_bluemail.sh#L28) |
| Snap 目录 | 仅移除指定 Snap 平台目录和启动脚本，保留应用自带 Electron 程序、Chromium 库、ICU、PAK、`locales` 与 `resources`。 | [构建代码](../build_bluemail.sh#L35) |
| 依赖收集 | 真实主程序、crashpad helper 与已确认动态加载的通知、密钥和托盘库同次收集；命令级库路径指向当前应用目录。 | [构建代码](../build_bluemail.sh#L69) |
| 打包配置 | `DEPLOY_GTK=1` 收集 GTK3 及已安装的输入模块；`NO_STRIP=1`、`STRACE_MODE=0` 保留当前符号与扫描方式，`VERSION` 使用本次 Snap 版本。 | [构建代码](../build_bluemail.sh#L58)、[构建代码](../build_bluemail.sh#L67) |
| 区域数据 | 首次收集后生成包内中文 locale，并追加标准语言变量和 `LOCPATH`。locale 不生成应用翻译，也不替代输入法模块。 | [构建代码](../build_bluemail.sh#L76) |
| 相邻资源 | `.env` 指向包内 `shared/bin` 的额外库目录和工作目录；将主程序以外的相邻资源链接到包装器目录，保留已确认的 Electron 查找关系。 | [构建代码](../build_bluemail.sh#L86)、[构建代码](../build_bluemail.sh#L129) |
| 启动参数 | `90-bluemail-arguments.hook` 在用户参数前加入 `--ozone-platform=x11 --no-sandbox`，只规范 `me.blueone.linux` URI 的斜杠形式，保留其余参数。 | [构建代码](../build_bluemail.sh#L92) |
| 协议注册 | 公共入口生成 `20-bluemail-protocol.hook`，用实际 AppImage 路径登记用户级 desktop；只设置 `me.blueone.linux` 默认处理程序，`mailto` 仅声明，不覆盖其默认程序。 | [构建代码](../build_bluemail.sh#L117) |
| 封装与保存 | quick-sharun 生成正式 AppImage 后，由公共保存入口检查产物、设置 0755 并写入最终 `dist/version.txt`。 | [构建代码](../build_bluemail.sh#L137)、[构建代码](../build_bluemail.sh#L140) |

## 公共接口与发布

公共安装入口新增显式 `--aur-source` 参数，只为选用该模式的调用保留并导出原始来源；`--base`、普通包名和 `--aur-deb` 的既有实现保持原样。解包、版本读取、版本保存、工作区和协议 hook 继续使用现有接口。公共说明补充参数、独立缓存、同次元数据与摘要核对规则；应用专属布局及 OAuth 处理继续留在本目录。

正式入口仍为 `bluemail/build_bluemail.sh`，由现有 Arch matrix 构建并发布 `bluemail.AppImage`。当前来源流程的实机通过结果见[实机验证](../README.md#实机验证)。
