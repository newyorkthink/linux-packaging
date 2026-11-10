# BlueMail 构建流程与模板差异

## 采用专用流程的原因

BlueMail 的最终程序来自 Snap Store 官方稳定通道，AUR 安装和后续打包复用同次校验的完整原始 Snap。现有 Electron 模板覆盖 DEB 和系统安装目录来源，没有对应的 Snap 来源保留与资源整理阶段。本目录按已确认的 Snap 布局维护专用流程，登记在[打包分类](../../docs/packaging-classification.md#专用打包流程)，不新增模板。

公共步骤采用[quick-sharun 固定注释](../../docs/quick-sharun-comments.md)的原文。Snap 来源、实际资源位置和启动兼容处理使用 `# 本程序专属处理：`；协议注册使用公共 hook 的固定注释。应用脚本不重复实现下载、校验、通用解包或版本保存。

## 来源与依据

- [AUR bluemail 配方](https://github.com/archlinux/aur/blob/93194394dc31b63f585963289f24700e09fd716d/PKGBUILD)及[来源元数据](https://github.com/archlinux/aur/blob/93194394dc31b63f585963289f24700e09fd716d/.SRCINFO)表明该包使用预编译 Snap，且安装时会删除部分 Chromium 库和桌面资源；打包继续使用完整原始归档。
- 公共 Arch 安装入口显式使用 `--aur-source` 与 `--snap-stable bluemail blix amd64`，先下载并核对官方 `latest/stable` 的 SHA3-384，再仅更新临时 AUR 配方的版本、同一 Snap ID 的下载地址及对应 SHA-256 / SHA-512。当前配方使用 SHA-512；新摘要从已通过官方摘要的文件计算，其他来源和校验保持原样。
- yay 的 `-G` 只获取配方；`-Bi` 从本次临时目录重新生成 `.SRCINFO`、解析依赖并安装。依据为 [yay 手册](https://github.com/Jguer/yay/blob/0938a75e98e63648ebf6e22ece6b4a30ec11a907/doc/yay.8)及[本地配方安装实现](https://github.com/Jguer/yay/blob/0938a75e98e63648ebf6e22ece6b4a30ec11a907/local_install.go)。安装后继续按同次元数据核对版本和缓存，导出时不再下载 Snap。
- 本次检索 pkgforge-dev 未找到对应的 BlueMail 打包仓库，不把本仓库处理标成逐字复用的官方代码。
- 资源布局、中文输入、启动参数、Gmail 登录及回调的既有证据保存在[应用 README](../README.md)。本次稳定通道调整以提交 `abe5e72f70f4ab67fbf5ec7646fafb6698db1194` 为基线，核对完整脚本、公共接口、上述 AUR 快照及官方稳定通道；具体固定取值见[固定配置](./hardcoded.md)。

## 执行阶段与专属内容

| 阶段 | 实际处理及原因 | 对应位置 |
| --- | --- | --- |
| 基础安装 | 通过公共 Arch 入口安装统一基础包。 | [构建代码](../build_bluemail.sh#L11) |
| 工作区 | 公共入口检查 x86_64，只清理本项目的 `AppDir`、`dist`、`work`；应用创建 `shared/bin` 作为 Snap 程序目录。 | [构建代码](../build_bluemail.sh#L14) |
| 应用、来源与版本 | `--aur-source --snap-stable` 用官方稳定版更新临时 AUR 配方，安装 `bluemail` 和已确认的运行库、GTK3 输入模块，再导出同一份已校验 Snap 与实际版本。公共 `text` 来源在首次收集前读取该版本。 | [构建代码](../build_bluemail.sh#L21)、[构建代码](../build_bluemail.sh#L64) |
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

公共安装入口在 `--aur-source` 下新增可选 `--snap-stable`，只在调用方明确给出 Snap 名称、发布者和架构时更新本次临时配方；未传选项的来源导出、`--base`、普通包名和 `--aur-deb` 保持原行为。公共 Snap 入口按需输出同次来源 JSON，原四参数调用保持原行为。解包、版本读取、版本保存、工作区和协议 hook 继续使用现有接口。公共说明补充参数、独立缓存、同次元数据与摘要核对规则；应用专属布局及 OAuth 处理继续留在本目录。

正式入口仍为 `bluemail/build_bluemail.sh`，由现有 Arch matrix 构建并发布 `bluemail.AppImage`。既有实机通过记录见[实机验证](../README.md#实机验证)。
