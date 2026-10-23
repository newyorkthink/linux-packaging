# KeePassXC AppImage

## 用途与产物

本目录将 Arch 当前 KeePassXC 打包为 `keepassxc.AppImage`，并同时保留 CLI、proxy、X11 剪贴板和自动输入相关运行组件。

## 技术栈与打包方式

KeePassXC 为 C++ 桌面应用，自 2.8.0 起使用 Qt6。构建脚本安装 Arch `keepassxc` 及 Qt6/X11/Fcitx5 相关依赖，通过 quick-sharun 生成 AppImage。实际打包版本以 Arch 仓库提供的 `keepassxc` 包为准。

## 界面语言与资源

应用翻译位于 `AppDir/share/keepassxc/translations/`。真实程序位于 `AppDir/shared/bin/`，构建时增加 `AppDir/shared/share -> ../share`，让当前 Qt6 按真实程序路径查找时也能访问同一份翻译、词表等数据。

包内生成 `AppDir/lib/locale/zh_CN.utf8`，并在 quick-sharun 已有 `.env` 后追加 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8` 和 `LOCPATH=${SHARUN_DIR}/lib/locale`。这样“系统默认”可使用简体中文，不要求宿主预先生成中文 locale；用户在 KeePassXC 中明确选择的界面语言仍由上游配置处理。不设置 `LC_ALL`。

资源路径决定能否找到翻译，中文环境决定默认选择哪种语言，两者作用不同。原理、旧版差异和适用边界见 [quick-sharun 与 Qt6 资源路径案例](./docs/quick-sharun-qt6-paths.md)。

## 浏览器集成与代理入口

当前 Arch 程序按 Qt 识别的程序目录生成原生消息配置，Qt6 下会登记 `AppDir/shared/bin/keepassxc-proxy`。该位置需要提供经过包内启动器的可执行入口，不能让浏览器直接执行依赖包内 Qt/glibc 的原始 ELF。

首次 quick-sharun 后，原 `bin/keepassxc-proxy` 启动器和 `shared/bin/keepassxc-proxy` 代理程序分别改名为同目录的 `keepassxc-proxy.real`，原位置新建两个仅执行 `exec` 的转发入口。两条调用路径最终均由 `bin/keepassxc-proxy.real`（原 sharun）加载 `shared/bin/keepassxc-proxy.real`（原代理），完整保留参数及标准输入输出。

原生消息 JSON 仍由 KeePassXC 自身生成和更新；构建脚本不写宿主浏览器配置，不写死 AppImage 临时挂载路径，也不修改 KeePassXC/Qt 源码或二进制内容。通用机制和适用条件见 [Qt5 转 Qt6 的程序路径说明](../docs/packaging-cases/quick-sharun-qt6-resources.md)。本应用的详细对照与验证边界见 [Qt6 路径专项记录](./docs/quick-sharun-qt6-paths.md)。

## 版本元数据

构建时从本次实际安装的 `keepassxc` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=keepassxc` 接入统一版本清单。

## 运行

```bash
./keepassxc.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据输出和发布清单接入，不改变现有 Qt5、剪贴板、自动输入或 Fcitx5 打包逻辑。

### 2026-10-23：修正 Qt6 资源路径并补齐默认中文环境

现象是 KeePassXC 2.8.0 界面没有中文、语言选择只剩系统默认；用户确认中文输入正常。核对实际产物发现中文 `.qm` 已打包，不能归因于缺翻译或输入法。旧版 2.7.12 / Qt 5.15.19 与故障包 2.8.0 / Qt 6.12.0 的 `.env` 相同，均没有 `shared/share` 链接。

sharun 启动后，Qt5 使用 `/proc/<pid>/exe` 得到 `AppDir/bin/keepassxc`；本次 Qt6 使用 `AT_EXECFN` 得到 `AppDir/shared/bin/keepassxc`。KeePassXC 据此查找 `../share/keepassxc`，新版路径缺失后回退到顶层 `share`，随后误找 `share/translations`。这里的旧版路径是 `bin`，不是动态加载器所在的 `lib`。

本次只在首次 quick-sharun 后、最终封装前增加资源链接，并按仓库 GUI 规则生成中文 locale、追加上述四项 `.env` 配置。已有 `.env` 内容、Qt6/Fcitx5 依赖、输入法选择、剪贴板、自动输入、CLI/proxy、quick-sharun 参数和版本元数据流程均保留。

检查：`bash -n`、完整 diff 和文档链接核对通过。云端隔离临时副本使用 offscreen 平台启动，不打开数据库；文件访问记录显示旧 Qt5 包成功打开 `keepassxc_zh_CN.qm`，故障 Qt6 包查错目录，修复副本成功打开该文件；修复副本选择“系统默认”时也成功打开中文翻译。资源链接可访问全部 48 个应用翻译文件，原 `.env` 内容保留。临时跟踪方法和验证边界见专项案例，测试代码与日志不入仓库。

以上是已有产物的临时对照检查，不是新 AppImage 的构建或实机验收。未监控本次提交触发的 Actions，新构建及桌面交互结果未验证。

### 2026-10-23：用户实机验收通过

用户实机运行修复后的 KeePassXC 2.8.0，确认中文界面、中文输入正常，并反馈使用没有发现问题，本次修复测试通过。用户提供的截图显示主界面和关于窗口已显示中文，搜索输入框可正常显示中文输入法候选。

验收对应 [ba30a16](https://github.com/newyorkthink/linux-packaging/commit/ba30a160db2d46615257f8379bb4d23f5fe1c9f8) 的 Qt6 资源路径与默认中文环境修复。当前构建脚本及其中的资源链接、包内中文 locale、保留原 `.env` 后追加环境配置的方式，作为已验证稳定基线保留；后续不得无故重写或改动已确认实现。

本条补齐上一条记录中尚未取得的用户实机结果；此前“未验证”是修复提交时的状态，原有排查过程和临时检查记录继续保留。

### 2026-10-23：补齐 Qt6 浏览器代理入口适配

用户随后反馈旧版浏览器集成正常，新版 Firefox 和 Vivaldi 均无法连接；提供的原生消息配置显示，两者都登记到临时挂载目录的 `shared/bin/keepassxc-proxy`。此前实机验收覆盖中文界面和中文输入，本条单独记录后续发现的浏览器连接问题。

对照旧版 2.7.12 / Qt 5.15.19 与当前 2.8.0 / Qt 6.12.0：两版 KeePassXC 生成默认代理路径的源码相同，均使用 `applicationDirPath()` 加代理名。隔离启动实际生成的配置分别指向旧版 `bin/keepassxc-proxy` 和新版 `shared/bin/keepassxc-proxy`。后者是原始动态链接程序，直接执行会绕过 sharun。

本次只增加上述代理入口适配。必须先改名保留原 sharun 硬链接，再创建转发脚本；直接在原硬链接上重定向写入会破坏其他同 inode 的启动器。原代理及启动器内容逐字节保留为 `.real`，原有中文 locale、`.env`、资源链接、输入法、剪贴板、CLI 和其他构建命令保留。

检查结果：旧版和新版 `bin` 原入口均能加载各自包内 Qt；新版原登记的 `shared/bin` ELF 在云端报缺少 `libQt6Network.so.6`，退出码 127。修复临时副本的两个入口均实际加载包内 Qt6 Core/Network，在标准输入结束后以 0 退出且标准输出无额外内容。两份真实转发脚本的隔离夹具检查通过：带空格路径、空参数、引号及中文参数、二进制标准输入输出和标准错误均按原样传递。

其余 `bin` / `shared/bin` 入口、AppRun、`.env`、中文 locale、48 个应用翻译文件及资源链接与本次原产物核对一致；脚本语法、文档链接和完整 diff 检查通过。所有临时检查文件、日志和产物均不入仓库。

验证边界：云端禁止创建 Unix socket，解除限制的检查请求也被自动审批拒绝，因此未完成与真实 KeePassXC 服务的公钥交换，未验收 Firefox/Vivaldi 实际连接。本次代理适配已完成启动链检查，浏览器连接仍待新产物实机确认。提交后不监控 Actions，新构建结果未验证。
