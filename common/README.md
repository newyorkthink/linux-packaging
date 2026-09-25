# common

应用构建脚本只单行调用这里的公共入口。某个软件的修复记录不要写到这里，写回该软件目录。

## 公共代码与公共函数

- `common/` 当前包含 `apt/`、`archive/`、`aur/`、`build/`、`desktop/`、`download/`、`github/`、`gui/`、`linuxdeploy/` 等目录。本项只是标记为**需要后续重新完整审计**，不是认定这些公共实现当前一定有错误。
- 后续 AI 需要从调用方和公共实现两端一起检查，不能只看某一个 helper：确认职责边界是否正确、是否存在重复通用逻辑、参数语义是否一致、错误处理与返回码是否可靠、下载 / 校验 / DEB 元数据 / 解包 / linuxdeploy 初始化与最终封装是否由正确层负责。
- 重点检查近期从 PeaZip 等项目下沉到公共函数的逻辑，确认没有把应用专用规则错误公共化，也没有让应用脚本重复做公共入口已经负责的检查。
- 已经由用户明确确认有效的命令、调用顺序、AppRun 行为和打包基线必须逐字保留；公共化不能成为顺手重写这些稳定内容的理由。
- 必须同时检查所有受影响调用方，避免只修公共函数后才逐个发现调用参数、路径、返回值或行为不兼容。
- `archive/extract_archive.sh` 统一支持 DEB、Snap、tar 系列归档和 Brotli 压缩的 `.distro` tar 包；应用脚本只传入归档文件与输出目录，应用专用的文件定位和目录调整仍留在应用脚本。
- `aur/resolve_deb_source.sh` 接收 AUR 包名、架构、工作目录、元数据输出文件和依赖输出文件；仅接受同名单包 `.SRCINFO` 中唯一的架构专用 HTTPS DEB 与 SHA-256，输出可供 Bash 加载的版本、pkgrel、来源和摘要，以及去版本约束后的运行依赖。浅克隆和解析只在公共入口完成。
- `download/download_verified_with_wayback.sh` 接收官方 HTTPS URL、目标文件、原 SHA-256 和可选的 `--deb`；先调用 `download_file.sh`，未取得匹配摘要的文件时才查同一 URL 的 Internet Archive 快照，所有候选文件仍须通过原摘要，`--deb` 还核对 DEB 文件类型。
- `github/download_latest_stable_named_asset.sh` 接收仓库、固定资产名、目标文件及可选的 DEB 包名和架构。只选择最新正式版本中的唯一资产，核对 GitHub SHA-256；直链失败时用同一资产 ID 和现有认证令牌回退，stdout 仅返回版本。带 `{version}` 的资产仍使用原有模板入口。
- `build/prepare_x86_64_workspace.sh` 接收项目根目录、`--skip-create`、一个清理后不创建的一级目录名，以及其余清理后重建的一级目录名。先检查 x86_64 和全部目录名，再只处理这个项目下明确传入的目录；应用自行决定哪些工作目录需要重建。

- `desktop/write_scheme_hook.sh` 写出 AppImage 启动 hook。hook 把本次实际的 AppImage 路径写成用户级 desktop，`Exec` 使用 `%U`，并且只把调用方传入的协议设为默认程序，不改其它协议的现有默认程序。原因和禁止事项见 [AppImage 自定义协议](../docs/appimage-scheme-handler.md)。

### 可选的最终产物检查与收尾

- `build/check_appimage_artifact.sh` 接收最终 AppImage 路径和 SHA-256 文件路径，确认产物非空且可执行，再以原 `sha256sum | tee` 方式生成校验文件。应用在生成正式产物后自行决定何时调用；图形检查仍独立按需调用。
- `gui/check_appimage_gui.sh` 仅由确有需要的应用显式调用，不是所有 AppImage 的默认步骤。参数依次是最终 AppImage 路径、1～20 秒上限、隔离工作目录、会话顺序（`timeout-dbus-xvfb`、`xvfb-dbus-timeout` 或 `timeout-xvfb`）、成功规则（`timeout-only` 或 `timeout-or-zero`）、调用方的致命日志正则、可选窗口标题正则，以及 `--` 后的应用参数。空窗口标题只检查进程存活和日志，不声称确认了可见窗口；非空标题还要求 Xvfb 中找到存活的可见窗口。调用方可在命令前设置应用专属环境变量，公共入口不添加 `--disable-gpu` 等应用参数。该检查不验证登录、代理、中文输入或实机功能。
- `build/finish_appimage_build.sh` 在调用方完成所有检查后接收版本号、`version.txt` 路径和原成功提示，按顺序写入版本文件并输出提示；不负责打包、图形检查或发布。已有 `common/linuxdeploy/package_appimage.sh` 同时承担封装和版本写入，使用该入口的应用不需要重复调用收尾函数。
- `build/save_appimage_version.sh` 接收最终 AppImage 路径、版本号和 `version.txt` 路径。先确认产物存在且非空，再写入版本。不写 SHA-256，也不打印成功提示。已经分开做产物校验和成功提示的应用不要改成这个入口。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `PENDING_AI_TASKS.md` 的「后续处理原则」，未改写。

1. 等 AI 有足够额度后再统一继续，不在额度不足或上下文不完整时逐项试错。
2. 开始修改前先一次性读完整相关代码、README、workflow、公共函数和历史问题记录，确认稳定基线、未验证项和禁止重复的失败方向。
3. Wine 的后续修复必须以真实构建产物和实机功能验证为准；构建成功、静态检查通过或代码看起来合理都不能替代实机结论。详见 [wine/README.md](../wine/README.md)。
4. JRiver AppImage 已归档到 [archive/jriver](../archive/jriver/README.md)，不再构建。两条旧路线的修复记录仍留在该目录，没有新证据不重复已经失败的包装实验。
5. 公共函数审计应一次覆盖公共实现和所有相关调用方；确认完整 diff 后再修改，避免反复小提交和依赖 GitHub Actions 失败结果试错。
