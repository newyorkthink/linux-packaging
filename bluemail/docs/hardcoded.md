# BlueMail 固定配置

本文登记当前应用的来源标识、程序布局及运行参数，不固定应用版本或 Snap 修订号。最终版本从本次 Snap Store 稳定通道动态取得，并同步到临时 AUR 配方；详细执行阶段见[模板差异](./template-deviations.md)。

## 来源、路径与用途

| 配置 | 取值 | 依据与用途 |
| --- | --- | --- |
| 官方来源 | AUR `bluemail` / `x86_64`；Snap `bluemail` / `blix` / `amd64`；源文件名模板 `bluemail-{version}.snap` | AUR 提供安装配方，Snap Store 提供动态 `latest/stable` 包。核对发布者、架构、官方 SHA3-384 及新旧 Snap ID 后，仅同步临时配方的版本、来源和摘要；不固定 URL、应用版本或修订号。 |
| 系统应用包 | `bluemail` | 公共安装入口显式启用 `--aur-source` 与 `--snap-stable bluemail blix amd64`，由 yay 本地配方模式安装官方稳定版及依赖，并保留同一份完整 Snap；最终程序不复制已裁剪的系统安装目录。 |
| 来源与版本输出 | `work/bluemail.snap`、`work/source-version.txt` | 官方稳定版只下载一次，安装缓存重新校验后导出归档；实际安装版本须与重新生成的 `.SRCINFO` 的 `pkgver` 一致，封装前再由公共 `text` 来源读取。 |
| 工作目录 | `work`、`AppDir`、`dist` | 公共工作区入口只处理应用根目录下明确列出的一级目录。 |
| 实际程序目录 | `AppDir/shared/bin` | 保持官方 Electron 程序、库和资源的相邻关系，继续使用已确认的布局。 |
| 主程序及 helper | `bluemail`、`chrome_crashpad_handler` | 与现有 Snap 构建入口一致，显式交给 quick-sharun 收集。 |
| 桌面资源 | Snap 内 `meta/gui/bluemail.desktop`、`meta/gui/icon.png`；提取到 `work/bluemail.desktop`、`work/bluemail.png` | 两份资源与最终程序来自同一次 Snap，提取后再清理 Snap 平台目录。 |
| 窗口与资产 | `APPNAME=BlueMail`、`MAIN_BIN=bluemail`、`STARTUPWMCLASS=BlueMail`、`bluemail.AppImage` | 保持已有应用标识、窗口对应关系和正式 Release 资产名。 |
| 动态加载库 | `/usr/lib/libnotify.so.4`、`/usr/lib/libsecret-1.so.0`、`/usr/lib/libappindicator3.so.1` | 保留现有通知、密钥和托盘库的显式收集；不复制整个系统库目录。 |
| 符号与扫描 | `NO_STRIP=1`、`STRACE_MODE=0` | 沿用当前打包配置，保留符号并关闭运行跟踪扫描。 |
| 区域环境 | `zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、包内 `lib/locale` | 使用标准 locale 生成和 `.env` 配置；不声称生成软件未提供的翻译，不覆盖宿主输入法变量。 |
| 运行目录 | `SHARUN_EXTRA_LIBRARY_PATH` 追加 `${SHARUN_DIR}/shared/bin`，`SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin` | 保留 README 已确认的相邻库加载和工作目录行为。 |
| 固定参数 | `--ozone-platform=x11 --no-sandbox` | README 的输入及入口实测记录已确认该组合；hook 在保留用户参数的前提下传入。 |
| 协议 | `me.blueone.linux`，desktop 使用 `%U` | 用于浏览器 OAuth 回调；公共 hook 仅设置该协议的默认程序，不覆盖 `mailto`。 |
| hook 顺序 | `20-bluemail-protocol.hook`、`90-bluemail-arguments.hook` | 分别完成协议登记和后置参数整理，由 quick-sharun 生成的入口加载。 |

## 已有故障事实与证据位置

完整故障经过和已有实机结论继续保存在 [README](../README.md)，本页不以概括替代该记录。2026-11-11 的来源核对发现 AUR `1.143.44` 落后于当时官方稳定版 `1.143.65`；因此显式启用稳定通道同步，而非继续按旧版本配方取包。可核实的关键原文与对应配置如下：

| 已保存的现象或原文 | 对应配置及作用 | 记录位置 |
| --- | --- | --- |
| 邮件编辑框只能输入英文，产物未找到 `im-ibus.so`、`im-fcitx5.so` | 安装 `ibus`、`fcitx5-gtk` 并通过 `DEPLOY_GTK=1` 收集匹配的 GTK3 输入模块。 | README「中文输入修复」「中文输入实机确认」 |
| 启动参数包含 `--ozone-platform=x11 --no-sandbox`，资源由 `shared/bin/resources` 加载 | 保留固定参数、相邻程序布局和 `.env` 中的运行目录。 | README「quick-sharun 新入口实机确认」 |
| `Exec=bluemail %F` 无法将自定义协议 URI 交给应用 | 将 desktop 入口设为 `Exec=bluemail %U`。 | README「修正 Google OAuth 浏览器回调」 |
| `default-url-scheme-handler not implemented for xfce` | 使用公共协议 hook 写入用户级 desktop 与协议默认项。 | README「OAuth 回调仍被浏览器当成搜索」 |
| `Received platform-specific URL`、`Handling platform-specific deep link`、`Decoded URL param: null` | 保留 URI 斜杠规范化及协议 hook；后续记录确认账户已完成登录，`null` 行本身不能判定登录失败。 | README「OAuth 回调已送达但参数为 null」「Gmail 登录已完成，协议注册改用公共入口」 |

上述错误文本来自仓库已经保存的记录，不补造缺失日志。来源名称、工作路径和资产名用于标识实际输入与输出，不属于以锁定版本规避故障的处理。
