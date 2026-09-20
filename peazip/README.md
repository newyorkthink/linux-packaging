# PeaZip AppImage

## 用途与产物

本目录把 PeaZip 官方最新稳定版 Qt6 Linux x86_64 DEB 重新封装为 AppImage。

- 上游项目：<https://github.com/peazip/PeaZip>
- 上游来源：官方 GitHub Release 中的 `peazip_<版本>.LINUX.Qt6-1_amd64.deb`
- 稳定产物名：`peazip.AppImage`
- 构建入口：`peazip/build_peazip.sh`
- 正式 workflow：`.github/workflows/build.yml` 的 `Build PeaZip` 独立 Job

## 技术栈

PeaZip 使用 Free Pascal / Lazarus 构建。本目录选择官方 Qt6 版本，主程序通过上游随包的 `libQt6Pas.so.6` 使用 Qt6 Widgets，并完整保留 `pea`、归档后端、简体中文语言文件、主题、帮助文档、desktop 和图标资源。

目标架构为 x86_64。官方包内仍包含少量上游保留的 32 位旧格式后端；脚本不修改或删除这些文件，部署依赖期间临时移出完整 `res/bin`，完成后原样恢复。

## 打包方式

当前固定采用 Ubuntu 24.04 + linuxdeploy + 官方 appimagetool：

1. 通过 GitHub `releases/latest` API 动态读取 PeaZip 最新稳定版，不锁定具体应用版本。
2. 只接受与 Release tag 对应的官方 Qt6 amd64 DEB，并校验 GitHub Release 提供的 SHA-256 digest。
3. 核对 DEB 的包名、版本和架构。
4. 完整保留官方 `/usr/lib/peazip` 与 `/usr/share/peazip` 布局，包括上游原始 `zh-cn.txt`；仅把系统安装所用的两个绝对符号链接改为 AppImage 内等价相对链接。
5. linuxdeploy、Qt 插件、appimagetool 和 runtime 全部从官方 continuous 动态取得当前版本。先写入旧包原始自定义 `AppRun`，不加入 GTK 插件，也不手工编写 `AppRun.wrapped`。
6. 官方归档后端在依赖部署前临时移出 AppDir，随后逐字执行已验证的 `--plugin qt --output appimage` 命令，由 linuxdeploy 部署 Qt6、处理 AppRun 并完成中间封装。
7. Qt 命令的 `--output appimage` 只生成 `.work/peazip-intermediate.AppImage`，不发布。归档后端原样放回后，最后仍由官方 appimagetool 配合单独下载并校验的 `runtime-x86_64` 封装 `dist/peazip.AppImage`；不会把缺少后端的中间产物交付给用户。

正式 CI 在 `peazip` 目录中执行，以下已验证命令逐字保留于脚本中；本次按维护者要求保留中间输出，最终发布仍以独立 appimagetool 封装为准：

```bash
# 使用已经准备好 AppRun、GTK hook 和资源的 AppDir 完成 Qt 部署与中间封装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

## 运行与兼容说明

- 自定义 AppRun 原样保留旧包的环境变量和 desktop `Exec` 解析方式，包括 `usr/translations` 搜索路径；Qt6 组件和 AppRun 处理只交给 linuxdeploy Qt 插件。
- 删除后来加入的 `LANG=C.UTF-8` 和 `LC_ALL=C.UTF-8` 强制设置，恢复旧入口继承宿主 locale 的行为。保持官方原始语言文件；不注入 `-peaziplanguage` 参数，语言由 PeaZip 自身设置管理。
- 继续保留旧版已实际使用的 XCB、Adwaita Dark、缩放和字体 DPI 环境；同时打包 Qt6 `adwaita.so`，避免只设置主题名却缺少样式插件。
- 最终产物必须包含同为 Qt6 的 Compose、Fcitx5、IBus 输入上下文和 XCB 平台插件；输入法守护进程仍由宿主提供。
- AppImage 启动链不使用 `sudo`、`pkexec`、systemd、cron 或自动安装逻辑。
- 官方包内 32 位旧格式后端的实际可用性仍取决于宿主是否具备对应 32 位兼容运行库；这不影响 PeaZip 主程序和主要 64 位归档后端。

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

### 2026-09-20：修复资源路径、中文、黑色主题和解压失效

- **故障基线：** `4e58036f7a254581515618c9a55944067237880e`。
- **运行证据：** 新包界面保持英文和浅色；选择 `zh-cn.txt` 后设置不生效；点击解压时报 `Executable not found: .../bin/res/bin/7z/7z`。
- **根因：** quick-sharun 把可执行入口复制到 AppImage `/bin`，PeaZip 因此按 `/bin/res` 查找资源；真实 `res` 位于 `shared/bin/res`，导致语言、主题、配置资源和解压后端一起失联。
- **修复：** 改回 Ubuntu 24.04 + linuxdeploy 布局，主程序保持在 `usr/lib/peazip` 并直接启动；linuxdeploy 只部署依赖，官方 appimagetool 单独封装。首次启动通过 PeaZip 官方参数初始化简体中文；恢复旧版 XCB、Adwaita Dark、缩放和字体 DPI 环境，补齐 Qt6 Adwaita 与输入上下文，并把故障涉及的路径纳入最终产物检查。
- **本地验证：** 已在隔离的 Ubuntu 24.04 环境完整构建 PeaZip 11.2.0 AppImage；最终产物重新解包后，主程序、7z、简体中文、黑色主题、XCB、Compose、Fcitx5、IBus 和 AppRun 核对通过。宿主侧六个关键 Qt plugins 均无缺库，Adwaita 明确解析到包内两条运行库；包内 7z 已实际完成创建、校验和解压；真实 AppRun 已在隔离虚拟显示中持续启动并加载包内 XCB 与 Adwaita-Dark；全新配置首次启动写入 `zh-cn.txt`，第二次启动确认不再重复注入语言参数。
- **验证边界：** 上述结果覆盖构建、启动链、主题插件加载和主要归档后端；Kali Linux 实际桌面中的按钮点击、设置持久化和全部格式仍以发布产物的最终实机操作为准。

## 变更记录

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
