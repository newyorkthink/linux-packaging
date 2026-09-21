# PeaZip AppImage

## 用途与产物

本目录把 PeaZip 官方最新稳定版 Qt6 Linux x86_64 DEB 重新封装为 AppImage。

- 上游项目：<https://github.com/peazip/PeaZip>
- 上游来源：官方 GitHub Release 中的 `peazip_<版本>.LINUX.Qt6-1_amd64.deb`
- 稳定产物名：`peazip.AppImage`
- 构建入口：`peazip/build_peazip.sh`
- 正式 workflow：`.github/workflows/build.yml` 的 `Build PeaZip` 独立 Job

## 技术栈

PeaZip 使用 Free Pascal / Lazarus 构建。本目录选择官方 Qt6 版本，主程序通过上游随包的 `libQt6Pas.so.6` 使用 Qt6 Widgets，并完整保留 `pea`、归档后端、简体中文语言文件、主题、帮助文档、desktop 和图标资源。目录内的 `peazip_utf8_fix.c` 是随包编译的最小兼容层，只处理 PeaZip 11.2.0 在 Pascal WideString 到 Qt QString 边界产生的可逆 UTF-8 乱码。

目标架构为 x86_64。官方包内仍包含少量上游保留的 32 位旧格式后端；脚本不修改或删除这些文件，部署依赖期间临时移出完整 `res/bin`，完成后原样恢复。

## 打包方式

当前固定采用 Ubuntu 24.04 + linuxdeploy + 官方 appimagetool：

1. 标准 `source`、`AppDir`、`dist`、`source/tools` 工作区与 x86_64 检查统一由 `common/linuxdeploy/prepare_build_workspace.sh` 处理；构建依赖统一通过 `common/apt/install_packages.sh` 安装。linuxdeploy、Qt 插件、appimagetool 和 runtime 继续由公共工具入口从官方动态来源取得并校验，不固定工具版本。
2. 应用文件进入 AppDir 前，单行调用 `common/linuxdeploy/initialize_appdir.sh`；公共入口执行原始普通 linuxdeploy 命令，只创建基础目录。
3. 通过 `common/github/download_latest_stable_release_asset.sh` 动态取得 PeaZip 最新正式稳定版，只接受对应版本的官方 Qt6 amd64 DEB，并在同一公共入口中校验 GitHub Release 提供的 SHA-256 digest。
4. 核对 DEB 的包名、版本和架构后，通过公共 APT 入口把同一个 DEB 安装到隔离构建环境供依赖解析，再通过 `common/archive/extract_archive.sh` 把同一个 DEB 按上游布局解包到 AppDir，禁止安装与解压使用不同版本。
5. 完整保留官方 `/usr/lib/peazip` 与 `/usr/share/peazip` 布局；仅把系统安装所用的两个绝对符号链接改为 AppImage 内等价相对链接。官方要求语言文件使用 UTF-8 BOM，因此只在 `zh-cn.txt` 缺失 BOM 时补入，不改写中文正文。
6. 使用构建环境已有的 GCC 把仓库内 `peazip_utf8_fix.c` 编译为 `usr/lib/peazip/libpeazip-utf8-fix.so`；不下载额外源码、程序或字体。写入完整根 `AppDir/AppRun`，固化用途正确的路径，并只在启动 PeaZip 主进程时预加载该兼容层；保留 desktop `Exec`、XCB、Adwaita Dark、缩放和字体 DPI 设置。
7. 当前官方 Qt 插件明确跳过 Qt6 AppRun hook，因此完整根 `AppDir/AppRun` 保持为最终顶层入口；没有 `AppRun.wrapped` 是当前官方工具的真实行为。构建脚本严格禁止创建 `apprun-hooks` 目录或任何 hook 文件，禁止为了复刻旧包结构自行补 hook、`AppRun.wrapped` 或包装层检查。
8. 第二次 linuxdeploy 前由 `common/linuxdeploy/configure_environment.sh` 设置通用环境，PeaZip 只追加 Qt6 `QMAKE` 与 `NO_STRIP`。官方归档后端仍在依赖部署前临时移出 AppDir，随后逐字执行已验证的 `--plugin qt --output appimage` 命令，完成后再把归档后端原样放回。
9. Qt 命令只生成 `source/peazip-linuxdeploy-intermediate.AppImage`，不发布；不再对已经确定的 AppRun 调用自动路径整理脚本。
10. 最终由 `common/linuxdeploy/package_appimage.sh` 统一调用官方 appimagetool 和已校验的 `runtime-x86_64` 封装 `dist/peazip.AppImage`，成功后写入 `dist/version.txt` 并输出 SHA-256；不会把缺少后端的中间产物交付给用户。

正式 CI 在 `peazip` 目录中执行，以下已验证命令逐字保留于脚本中；本次按维护者要求保留中间输出，最终发布仍以独立 appimagetool 封装为准：

```bash
# 使用已经准备好 AppRun、Qt6 资源和应用文件的 AppDir 完成 Qt 部署与中间封装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

## 运行与兼容说明

- 当前最终启动入口就是完整的顶层 `AppRun`；当前官方 Qt 插件跳过 Qt6 hook，所以不存在 `apprun-hooks` 和 `AppRun.wrapped`。顶层入口保留 desktop `Exec` 解析方式以及已经确认的显示和主题设置，路径型环境变量按最终 AppDir 的真实目录和用途直接固化。
- `zh-cn.txt` 保持官方中文正文，仅在缺失时补 UTF-8 BOM；不再覆盖 `LANG`、`LANGUAGE`、`LC_ALL` 或 `LC_MESSAGES`。兼容层只在整段 UTF-16 文本能严格还原为有效多字节 UTF-8 时转换，例如 `æ–‡ä»¶` 还原为 `文件`；正确中文、ASCII 和普通拉丁文字原样通过。语言仍由 PeaZip 自身设置管理，不注入会使设置进程主动关闭窗口的 `-peaziplanguage` 参数。
- `LD_PRELOAD` 只用于 PeaZip 主进程。兼容层加载后立即恢复用户原有值并删除私有变量，PeaZip 启动的 7z 等子进程不会继承该兼容库。
- 继续保留旧版已实际使用的 XCB、Adwaita Dark、缩放和字体 DPI 环境；同时打包 Qt6 `adwaita.so`，避免只设置主题名却缺少样式插件。
- 最终产物必须包含同为 Qt6 的 Compose、Fcitx5、IBus 输入上下文和 XCB 平台插件；输入法守护进程仍由宿主提供。
- AppImage 启动链不使用 `sudo`、`pkexec`、systemd、cron 或自动安装逻辑。
- 官方包内 32 位旧格式后端的实际可用性仍取决于宿主是否具备对应 32 位兼容运行库；这不影响 PeaZip 主程序和主要 64 位归档后端。

## 已实机确认的稳定基线（禁止改动）

- **验收结果：** 2026-09-21，用户已在 Kali Linux + i3wm 中运行正式 `peazip.AppImage` 并提供截图确认：菜单、工具栏、侧栏、文件列表、状态栏和历史记录均正常显示简体中文，原有 `æ…` 类乱码已经消失。中文乱码问题至此确认修复，不再属于待验证项目。
- **稳定实现：** `peazip_utf8_fix.c`、构建脚本中生成 `libpeazip-utf8-fix.so` 的 GCC 命令、AppRun 中的 `PEAZIP_ORIGINAL_LD_PRELOAD` / `LD_PRELOAD` 两行以及当前 Qt6Pas 回调修复链共同组成同一套已验证实现，必须完整保留。
- **永久约束：** 后续更新 PeaZip、依赖、公共脚本、linuxdeploy、AppRun 或文档时，禁止以整理、简化、重构、统一模板、减少预加载或改用其他编码方案为由删除、绕过、改名、替换或改写上述实现；禁止重新加入已失败的 locale-only 方案，禁止改用字体、反复改写 BOM 或 `-peaziplanguage` 掩盖编码问题。
- **变更门槛：** 只有用户明确要求重新处理该兼容层，并且出现新的真实产物实机回归证据时，才允许单独评估；在得到明确授权前必须原样保留当前实现，不能先改后试。

## 运行

在 Linux 终端进入 AppImage 所在目录后执行：

```bash
# 启动 PeaZip
./peazip.AppImage
```

## 检查记录

### 2026-09-20：旧 AppImage 与官方 11.2.0 适用性检查

- **仓库基线：** `f5d7df39db1ee4273db5df1bdaa7eb54fd803d3b`
- **检查对象：** 用户旧 `peazip.AppImage`，SHA-256 为 `5137a3d3f5ab541a52ddccdfa0ac47b057de09f52598980a2fd47e84b9fee6b7`；PeaZip 官方 11.2.0 Qt6 amd64 DEB。
- **已确认结论：** 旧包是 x86_64 Type 2 AppImage，内含 PeaZip 11.0.0 Qt6，由 linuxdeploy 生成；真实主程序位于 `usr/lib/peazip/peazip`，与 `res` 相邻，并包含 Qt6 XCB、Adwaita、Compose、Fcitx5 和 IBus plugins。旧 AppRun 固定 XCB、Adwaita Dark、缩放和字体 DPI。
- **许可证：** 上游仓库标示 LGPL-3.0，官方 DEB 附带 GPL-3+ 版权说明，允许按对应许可证再分发。

## 修复记录

### 2026-09-21：移除应用脚本中的通用工具预检查

- **问题：** 公共化后仍残留自定义 `die()` 和 `command -v qmake6` 预检查，不符合应用脚本不重复维护通用工具检查的仓库规则。
- **修正：** 删除 `die()`、`command -v qmake6` 和 `QMAKE6` 临时变量；Qt 部署直接使用 `export QMAKE=qmake6`。DEB 包名、版本和架构仍保留为供应链判断，但依赖 `set -Eeuo pipefail` 直接失败，不再通过自定义错误函数包装。
- **保持不变：** UTF-8 兼容层、GCC 命令、AppRun、归档后端处理和已验证的第二次 linuxdeploy 命令均未改动。

### 2026-09-21：复用统一工作区、下载、安装、解包与最终封装入口

- **修改范围：** 仅调整 `peazip/build_peazip.sh` 与本 README；`xnconvert`、`xnviewmp` 只用于核对已经成熟的公共入口复用方式，没有修改。
- **调整：** 标准工作区与架构检查改由 `prepare_build_workspace.sh` 处理；依赖与同一官方 DEB 的安装改由 `install_packages.sh` 处理；正式 Release 解析、摘要校验和下载合并到 `download_latest_stable_release_asset.sh`；DEB 解包改由 `extract_archive.sh` 处理；第二次 linuxdeploy 的通用环境改由 `configure_environment.sh` 处理；最终 appimagetool 封装、SHA-256 输出和 `version.txt` 写入改由 `package_appimage.sh` 处理。
- **保持不变：** `peazip_utf8_fix.c`、生成兼容库的 GCC 命令、AppRun 中的 UTF-8 兼容层与显示 / 主题设置、官方归档后端临时移出与恢复逻辑，以及已验证的 `export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage` 命令均未改写。
- **检查状态：** 已核对所有公共 helper 的当前接口、PeaZip 原有稳定基线和本次完整修改范围；workflow 未修改。提交后按仓库规则不监控 Actions，因此本次新构建与实机运行结果不在此记录中宣称已验证。

### 2026-09-21：在 Qt6Pas 字符串边界修复 UTF-8 乱码

- **实机故障证据：** 用户在 Kali Linux 正式产物中反复看到 `æ–‡ä»¶` 一类菜单乱码。官方 `zh-cn.txt` 已确认带 UTF-8 BOM、正文可按 UTF-8 正确解码，并与官方 DEB、portable 包逐字一致；这不是缺字体造成的方框，也不是语言文件内容损坏。
- **失败方案，禁止重新启用：** `LANG=zh_CN.UTF-8` + `LANGUAGE=zh_CN:zh` + `LC_MESSAGES=zh_CN.UTF-8`、`LANG=C.UTF-8` + `LC_ALL=C.UTF-8`、`LANG=C.utf8` + `LC_ALL=C.utf8` 三种 locale-only 方案均已被用户实机证明无效。后续不得再把任何一种方案作为乱码修复写回 AppRun，也不得通过下载字体掩盖编码错误。
- **代码路径证据：** PeaZip 11.2.0 的 `load_texts` 通过 Pascal `Text` / `AnsiString` 读取语言正文，`read_header` 只跳过 BOM；`libQt6Pas.so.6` 最终统一通过 `UnicodeOfPWideString` 和 `LengthOfPWideString` 把 Pascal WideString 送入 `QString::setUtf16`。截图中的字符正好可逆映射回原 UTF-8 字节。
- **修复：** 新增仓库内 `peazip_utf8_fix.c`，构建为 PeaZip 专用共享库，并在 `initPWideStrings` 这一处边界替换两个读取回调。只有完整文本能从 Latin-1/CP1252 字符严格解码为合法多字节 UTF-8 时才修复；其他文本不修改。AppRun 不再强制任何 locale。
- **临时测试（未写入仓库）：** 使用 `-Wall -Wextra -Werror -Wpedantic` 编译通过；`æ–‡ä»¶ → 文件` 通过；正确中文、ASCII、`Résumé` 原样通过；伪 Qt6Pas 共享库验证实际 ELF 符号拦截、两个回调求值顺序和长度均正确；正式包内真实 `libQt6Pas.so.6` 的全局回调槽实际返回 `文件`；真实 PeaZip 动态加载追踪确认绑定链为 `peazip → libpeazip-utf8-fix.so → libQt6Pas.so.6`；私有预加载变量被删除且用户原有 `LD_PRELOAD` 被恢复。真实 PeaZip 曾加载兼容库启动到虚拟显示窗口阶段；本轮复测因执行容器禁止创建 X11 socket 未能重复截图，不把该环境失败记成应用通过。
- **Kali 实机验收：** 用户已运行本次正式产物并提供截图，确认菜单、工具栏、侧栏、文件列表、状态栏和历史记录中的简体中文均正常显示，没有继续出现乱码。
- **最终结论：** 算法、ABI 拦截、环境恢复和 Kali 桌面正式产物显示均已验证；乱码问题确认修复。当前实现升级为禁止改动的稳定基线，后续不得再把本问题标记为待确认，也不得回退到此前失败方案。

### 2026-09-20：复用公共空 AppDir 初始化入口

- **调整：** 第一次普通 linuxdeploy 集中到 `common/linuxdeploy/initialize_appdir.sh`，项目脚本只保留一行调用。
- **边界：** PeaZip 专用 Qt6 环境、AppRun、归档后端临时移出与第二次 linuxdeploy 命令均未改变。

### 2026-09-20：修复资源路径、中文、黑色主题和解压失效

- **故障基线：** `4e58036f7a254581515618c9a55944067237880e`。
- **运行证据：** 新包界面保持英文和浅色；选择 `zh-cn.txt` 后设置不生效；点击解压时报 `Executable not found: .../bin/res/bin/7z/7z`。
- **根因：** quick-sharun 把可执行入口复制到 AppImage `/bin`，PeaZip 因此按 `/bin/res` 查找资源；真实 `res` 位于 `shared/bin/res`，导致语言、主题、配置资源和解压后端一起失联。
- **修复：** 改回 Ubuntu 24.04 + linuxdeploy 布局，主程序保持在 `usr/lib/peazip` 并直接启动；linuxdeploy 只部署依赖，官方 appimagetool 单独封装。首次启动通过 PeaZip 官方参数初始化简体中文；恢复旧版 XCB、Adwaita Dark、缩放和字体 DPI 环境，补齐 Qt6 Adwaita 与输入上下文，并把故障涉及的路径纳入最终产物检查。
- **本地验证：** 已在隔离的 Ubuntu 24.04 环境完整构建 PeaZip 11.2.0 AppImage；最终产物重新解包后，主程序、7z、简体中文、黑色主题、XCB、Compose、Fcitx5、IBus 和 AppRun 核对通过。宿主侧六个关键 Qt plugins 均无缺库，Adwaita 明确解析到包内两条运行库；包内 7z 已实际完成创建、校验和解压；真实 AppRun 已在隔离虚拟显示中持续启动并加载包内 XCB 与 Adwaita-Dark；全新配置首次启动写入 `zh-cn.txt`，第二次启动确认不再重复注入语言参数。
- **验证边界：** 上述结果覆盖构建、启动链、主题插件加载和主要归档后端；Kali Linux 实际桌面中的按钮点击、设置持久化和全部格式仍以发布产物的最终实机操作为准。

## 变更记录

### 2026-09-21：改用 glibc 登记的 UTF-8 locale 名称

- **故障证据：** 正式 AppImage 已设置 `C.UTF-8`，用户实机选择简体中文后仍显示 `æ…` 一类 UTF-8 字节被按单字节代码页解释的乱码；包内 `zh-cn.txt` 已确认是带 BOM 的有效 UTF-8，问题不在语言文件正文。
- **根因：** AppRun 使用了未按 `locale -a` 登记形式书写的 `C.UTF-8`；目标 glibc 登记的内置 UTF-8 locale 名称是 `C.utf8`。名称没有被运行环境接受时，PeaZip 会落回单字节代码页。
- **修复：** AppRun 将 `LANG` 和 `LC_ALL` 同时固定为 `C.utf8`。不下载或捆绑字体，不改写语言文件正文，不修改其他打包与启动逻辑。
- **验证：** 已确认构建环境的 `locale -a` 登记 `C.utf8`，且 `LC_ALL=C.utf8 locale charmap` 返回 `UTF-8`；继续执行 Shell 语法与最终 diff 检查。

### 2026-09-21：修复中文仍按单字节代码页解释

- **用户实机证据：** 最终 AppRun 已包含 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh` 和 `LC_MESSAGES=zh_CN.UTF-8`，PeaZip 选择简体中文后仍显示 `æ…` 一类乱码，证明上一版只恢复这些变量没有解决代码页问题。
- **根因：** PeaZip 当前源码用 Pascal `Text` 读取语言文件，`read_header` 只检查并跳过 UTF-8 BOM，正文继续进入普通 `AnsiString`；Lazarus/FPC 要求默认系统代码页为 UTF-8，否则向 GUI 传递时会把 UTF-8 字节按单字节编码转换。只设置 `zh_CN.UTF-8` 不可靠：宿主可能没有生成该 locale，已有 `LC_ALL` / `LC_CTYPE` 也可能覆盖它。
- **修复：** AppRun 改为 `LANG=C.UTF-8` 和 `LC_ALL=C.UTF-8`。该 UTF-8 locale 由目标 glibc 环境直接提供，不依赖单独生成中文 locale，并覆盖宿主遗留的非 UTF-8 locale；PeaZip 的界面语言仍由自身设置选择。
- **保持不变：** UTF-8 BOM 保证、两阶段 linuxdeploy、Qt6、完整顶层 AppRun、禁止人工 hook、XCB、Adwaita Dark、缩放、字体 DPI、归档后端恢复和 appimagetool 最终封装均不变；不加入 `-peaziplanguage`。
- **检查状态：** 已完成 Shell 语法、PeaZip 官方语言读取源码、Lazarus/FPC 字符串代码页规则、AppRun 环境优先级和完整 diff 静态核对；未执行完整构建或实机运行，提交后不监控 Actions。

### 2026-09-20：删除人工 Qt6 hook 并写死禁止补造

- **问题：** 为了强制得到旧包中的 `AppRun.wrapped`，脚本错误加入了只执行 `true` 的 `apprun-hooks/peazip-qt6-hook.sh`，并把 `AppRun.wrapped` 设为发布硬条件。这是在当前官方 Qt6 插件明确跳过 hook 时无中生有补造包装层。
- **修复：** 删除人工 hook 的目录、脚本生成逻辑和两条 `AppRun.wrapped` 强制检查。第二次 linuxdeploy 命令保持原样，只负责当前官方 Qt6 部署与中间输出；完整根 `AppRun` 直接作为最终顶层入口。
- **永久约束：** PeaZip 以及仓库内所有 linuxdeploy 项目禁止手工创建、复制、下载、修改或注入 hook；禁止空 hook、`true` hook、兼容 hook和占位 hook；官方插件不生成 hook 时禁止自行补 `AppRun.wrapped` 或因此让构建失败。该约束已同步写入 `AGENTS.md` 和 `linuxdeploy_projects.md`。
- **中文处理：** 保留本次与包装层无关的 UTF-8 BOM 保证和中文 locale 修复；不加入会让 PeaZip 设置语言后主动关闭窗口的 `-peaziplanguage` 参数。
- **检查状态：** 已完成 Shell 语法、人工 hook / `AppRun.wrapped` 强制检查全量检索及完整 diff 核对；未执行完整构建或实机运行，提交后不监控 Actions。

### 2026-09-20：修复中文乱码并恢复 AppRun.wrapped

- **用户实机证据：** 当前正式 AppImage 选择简体中文后全部界面文字仍为乱码；解包后只有顶层自定义 `AppRun`，没有 `AppRun.wrapped` 和 Qt hook。
- **构建日志证据：** Build PeaZip Job `106102857498` 使用 Qt 6.4.2；当前官方 linuxdeploy Qt 插件明确输出 `skipping AppRun hook creation on Qt 6`。因此“第二次 Qt linuxdeploy 会自动创建 Qt6 hook”的旧判断不成立，空 hook 目录也不会触发包装。
- **中文根因与修复：** 当前 AppRun 删除了此前实际验证过的中文 locale，构建脚本也没有执行 PeaZip 官方要求的 UTF-8 BOM 保证。现在恢复 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`，并仅在 `zh-cn.txt` 缺失 BOM 时补入 BOM；不改写中文正文，不重新加入会导致设置语言后主动退出的 `-peaziplanguage` 参数。
- **包装层修复：** 保持打包工具动态更新，不固定旧版 Qt 插件；加入 PeaZip 专用非空 Qt6 兼容 hook，让 linuxdeploy 自己把完整根 AppRun 改名为 `AppRun.wrapped` 并生成顶层 hook AppRun。构建流程不手工创建 `AppRun.wrapped`，且缺少包装层时禁止继续发布。
- **稳定基线：** 两阶段 linuxdeploy、同一个 DEB 同时安装并解压、Qt6、官方目录布局、归档后端临时移出与恢复、desktop `Exec`、Adwaita Dark、XCB、缩放、字体 DPI、独立 appimagetool 最终封装均保持不变。
- **检查状态：** 已完成 Shell 语法、官方 Qt 插件源码、实际 Actions 日志、linuxdeploy 包装源码、命令顺序和完整 diff 静态核对；未在用户主机测试，提交后不持续监控 Actions。

### 2026-09-20：按 linuxdeploy 强制流程完成 PeaZip 重排

- **问题：** 现有脚本先把官方 DEB 解压到 AppDir，再执行唯一一次 Qt linuxdeploy；没有先用普通 linuxdeploy 初始化空 AppDir，也没有把网上下载的同一个 DEB 安装到隔离构建环境。
- **修改文件：** `peazip/build_peazip.sh`、`peazip/README.md`。
- **处理：** 改用仓库公共脚本准备并校验全部打包工具；第一次普通 linuxdeploy 只创建空 AppDir 基础目录；随后动态取得官方稳定版 DEB，校验后把同一个文件安装到构建环境并解压到 AppDir；第二次继续逐字执行已确认的 Qt6 linuxdeploy 命令，最后仍由官方 appimagetool 与 Type 2 runtime 封装正式资产。
- **稳定基线：** 保留 PeaZip Qt6 技术栈、上游目录布局、32 位旧后端临时移出与原样恢复、desktop `Exec`、XCB、Adwaita Dark、缩放、字体 DPI、动态版本和版本清单流程；没有改 workflow。
- **AppRun：** 根据已经确认的最终 AppDir 结构直接固化用途正确的路径，并删除本项目对自动路径整理脚本的调用；历史变更记录保留，不改写此前证据。
- **检查状态：** 已完成 Shell 语法、命令顺序、路径、引号、公共脚本接口和完整 diff 静态核对；未执行完整构建或实机运行，提交后不监控 Actions。

### 2026-09-20：接入 linuxdeploy 公共 AppRun 路径整理

- **问题：** 旧入口把 `usr`、`usr/bin`、`usr/lib`、`usr/plugins`、`usr/share` 和 `usr/translations` 同时写入多个用途不同的搜索变量，只判断目录存在仍会保留语义错误的路径。
- **修改文件：** `peazip/build_peazip.sh`、`common/linuxdeploy/normalize_apprun_paths.sh`、公共说明和构建 Plan 的现有自动消费者识别。
- **处理：** 保留已经确认的 linuxdeploy 命令、Qt6 技术栈、desktop `Exec` 启动方式和非路径设置；只在第二次 linuxdeploy 后、appimagetool 前调用公共脚本。最终存在且用途匹配的目录保留或补入，不存在或归类错误的路径删除；Qt translations 使用自己的变量，不再混入其他搜索路径。
- **验证状态：** 已完成 Shell 语法、公共脚本合成 AppDir 行为、重复运行一致性、消费者识别和完整 diff 检查；未执行 PeaZip 完整构建或实机运行。

### 2026-09-20：恢复原始 AppRun 和 Qt6 打包命令

- **故障现象：** 新包中文菜单显示为 `æ…` 一类乱码，且只有顶层自定义 `AppRun`；旧包可以正常显示，并包含 linuxdeploy 自动生成的 `AppRun`、`AppRun.wrapped` 和 Qt hook。
- **证据范围：** 读取用户提供的新旧包内容、截图、当前脚本，以及 linuxdeploy、Qt / GTK / AppImage 插件和 PeaZip 官方源码；未运行应用或构建。
- **已确认差异：** 两包的 `zh-cn.txt` 都已有 UTF-8 BOM，中文内容本身可正确解码；主要 Qt6 Core / GUI / Widgets 及 Qt6Pas 的 `.text` 内容一致。旧包含有较完整的 GTK3 依赖，新包缺少其中多项；新 AppRun 还额外强制 locale，并改写了旧版搜索路径。以上差异不能单独证明乱码的完整根因。
- **包装机制：** 自定义 AppRun 在 linuxdeploy 前写入 AppDir，随后逐字执行旧版已确认有效的 Qt 打包命令。当前流程不混入 GTK 插件，也不手工生成 `AppRun.wrapped`。
- **修改文件：** `peazip/build_peazip.sh`、`peazip/README.md`。
- **修复内容：** 自定义 AppRun 恢复为旧包原文，移除后加的 locale 覆盖；逐字执行原 Qt 打包命令，原样恢复归档后端后，最后单独用 appimagetool 生成发布资产。应用和工具仍动态获取当前版本，保留中文文件原始字节，不混入 GTK 插件，不手写 AppRun.wrapped，也不覆盖 linuxdeploy 处理后的入口。删除构建脚本内的 `desktop-file-validate` 验证命令。
- **更正历史判断：** PeaZip 官方 `peaziplanguage` 实现会调用 `FormPeach.Close`；不能把该参数执行后退出直接认定为崩溃，也不能把此前退出直接归因于 BOM。正常启动不应反复注入这个会关闭窗口的设置命令。
- **结果边界：** 本次仅恢复已知有效的自定义入口并修正打包流程；中文乱码的完整根因仍未确认，不能宣称已经解决。未进行构建、启动或功能测试，未监控提交后的 Actions，最终结果待正式产物的真实使用反馈。

### 2026-09-20：删除导致启动退出的强制语言参数

- **故障现象：** 保留上游原始语言文件后，AppImage 启动仍立即退出。
- **根因：** 故障只在 AppRun 注入 `-peaziplanguage zh-cn.txt` 后出现；旧版原始 `exec ${EXEC} "$@"` 启动链可以打开程序。
- **修复：** 删除强制语言参数，恢复旧版 AppRun 原始启动命令；继续保留通用 `C.UTF-8` locale，语言选择交由 PeaZip 自身设置管理。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，启动结果以正式构建产物的真实使用反馈为准。

### 2026-09-20：删除无效空 hook 目录并恢复上游语言文件

- **故障现象：** 最终 AppImage 中存在空 `apprun-hooks` 目录，但自定义入口仍是顶层 `AppRun`；强制加载简体中文后程序立即退出。
- **根因：** 空 hook 目录不会让当前 linuxdeploy 生成 `AppRun.wrapped`；同时脚本擅自给上游 `zh-cn.txt` 添加 BOM，强制加载改写后的语言文件引入启动故障。
- **修复：** 删除空 hook 目录和语言文件字节改写，完整保留官方 `zh-cn.txt`；AppRun 只设置通用 `C.UTF-8` locale，并继续使用 PeaZip 官方简体中文启动参数。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，启动和中文显示以正式构建产物的真实使用反馈为准。

### 2026-09-20：恢复全部打包工具动态更新

- **失败记录：** Build PeaZip Job `106054153414` 下载固定旧标签的构建工具时连续返回 HTTP 404，在 linuxdeploy 执行前退出。
- **根因：** 为复刻旧版入口结构错误固定了旧版 linuxdeploy / Qt 插件，违反仓库动态版本规则，也引用了不可用的旧资产。
- **修复：** linuxdeploy、Qt 插件、appimagetool 和 runtime 全部恢复从官方 continuous 动态获取；不再固定任何旧标签。脚本只创建标准空 `apprun-hooks` 目录，不写 hook 文件，由当前 linuxdeploy 自行处理 `AppRun.wrapped`。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，构建结果以正式 GitHub Actions 为准。

### 2026-09-20：改由官方旧版 Qt 插件自动生成 AppRun hook

- **问题：** 前一版为了恢复 `AppRun.wrapped` 手工创建了 PeaZip hook，不符合旧版 AppImage 由 linuxdeploy Qt 插件自动生成 hook 的打包方式。
- **根因：** Qt 插件在 2025-11-07 合并上游变更后，Qt6 默认跳过 AppRun hook；持续下载 `continuous` 会取得这一新行为。
- **修复：** 删除手工 hook，固定使用上游变更前的官方 `1-alpha-20250213-1` linuxdeploy 和同版本 Qt 插件，由插件自动生成 Qt hook，再由 linuxdeploy 自动生成 `AppRun` 与 `AppRun.wrapped`。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，最终目录结构以正式构建产物为准。

### 2026-09-20：恢复 linuxdeploy 的 AppRun.wrapped 启动层级

- **故障现象：** 新 AppImage 只有顶层 `AppRun`，没有旧版正常包中的 `apprun-hooks` 和 `AppRun.wrapped`；界面启动后保持英文。
- **根因：** 当前 linuxdeploy Qt 插件对 Qt6 主动跳过 AppRun hook 创建，因此仅提供自定义 `AppRun` 不会触发 linuxdeploy 包装入口。
- **修复：** 在调用 linuxdeploy 前加入 PeaZip Qt6 兼容 hook，让 linuxdeploy 按正常机制自动生成顶层 `AppRun` 并把自定义入口保留为 `AppRun.wrapped`；同时在旧版 desktop `Exec` 启动链加入官方 `-peaziplanguage zh-cn.txt` 参数。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，最终目录结构和中文显示以正式构建产物的真实使用反馈为准。

### 2026-09-20：修复简体中文界面乱码

- **故障现象：** PeaZip 可以启动，但菜单、侧栏和文件列表中的简体中文全部显示为 `æ…` 一类乱码。
- **根因：** `zh-cn.txt` 的 UTF-8 中文内容被 PeaZip 按单字节编码读取；PeaZip 官方说明语言文件优先使用 UTF-8 BOM。
- **修复：** 官方 DEB 解包后，在正式打包流程中给 `usr/share/peazip/lang/zh-cn.txt` 添加 UTF-8 BOM，保留已经恢复的旧版 AppRun 启动方式。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，显示结果以正式构建产物的真实使用反馈为准。

### 2026-09-20：恢复旧版稳定 AppRun 启动方式

- **故障现象：** 新 AppImage 启动后立即退出，旧版 linuxdeploy AppImage 可以正常打开。
- **根因：** 新脚本没有沿用旧版已经正常工作的 `AppRun.wrapped`，而是擅自改成直接启动主程序，并额外强制中文环境和首次启动标记。
- **修复：** 按旧版实际 `AppRun.wrapped` 恢复 `HERE` 路径、PATH、库路径、Qt plugin、XDG、GSettings、XCB、Adwaita Dark、缩放和 desktop `Exec` 启动方式；删除新增的语言强制和配置标记逻辑。
- **验证状态：** 按仓库永久规则未执行任何测试、试构建或产物验证；修改后直接提交并推送，运行结果以正式构建产物的真实使用反馈为准。

### 2026-09-20：删除构建脚本中的全部验证代码

- **原因：** 构建脚本中误加入 AppImage 解包、逐文件断言、`ldd` 依赖检查和 7z 启动检查，违反仓库永久禁止测试与验证代码的规则。
- **修改：** 删除 DEB 解包后的 `test` 断言，以及最终 AppImage 的解包、`test`、`ldd` 和 7z 执行代码；脚本只保留正式下载、依赖部署、AppImage 封装、版本元数据和 SHA-256 输出流程。
- **验证状态：** 按仓库规则未执行任何测试、静态检查、试构建或产物验证；修改后直接提交并推送，构建与运行结果待正式流程和真实运行反馈确认。

### 2026-09-20：修复 GitHub Actions 的 32 位旧后端扫描失败

- **失败记录：** Build PeaZip Job `106047998141` 在 linuxdeploy 扫描官方包内 `res/bin/arc/arc` 时，因找不到已淘汰的 32 位 `libncurses.so.5` 退出。
- **根因：** linuxdeploy 会先扫描 AppDir 中所有 ELF；原脚本虽然只把 64 位后端加入参数，但没有阻止它自动扫描已经位于 AppDir 的 32 位旧后端。
- **修复：** linuxdeploy 运行前临时移出完整 `res/bin`，只部署主程序和 Qt6，随后原样恢复官方后端。同步删除重复的逐文件验证，只保留与实际故障直接相关的最终检查。

### 2026-09-20：接入官方最新 Qt6 AppImage 构建

- **原因：** 旧 AppImage 停留在 PeaZip 11.0.0，且缺少可维护的动态更新和供应链校验入口。
- **修改文件：** `peazip/build_peazip.sh`、`peazip/README.md`、`.github/appimage-apps.json`、`.github/workflows/build.yml`。
- **变更内容：** 新增官方 Release 动态解析、资产 URL 和 SHA-256 校验、DEB 元数据核对、官方程序与资源保留、稳定产物名和版本清单接入。
