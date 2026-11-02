# DingTalk AppImage

## 当前构建

2026-11-02 按用户确认的草稿对齐 AppDir / 官方 appimagetool 体系的直接封装标准。构建仍使用 Ubuntu 24.04 / x86_64，Release 名称仍为 `dingtalk.AppImage`。本项目不调用 linuxdeploy 或 quick-sharun，不使用 Docker，也不编译钉钉源码。

主 build 单行调用公共 AUR 组合入口，动态解析 `dingtalk-bin` 指向的官方 DEB 及完整摘要，在校验版本、包名、架构后，将同一份 DEB 安装到构建环境并解包。资源准备和依赖处理分别放在 `patches/prepare_appdir.sh`、`patches/collect_runtime.sh`；Qt/CEF 完整运行目录、NSS/NSPR、可执行栈处理与原有启动参数继续保留。最终封装与版本保存只调用公共 `package_appimage.sh`，不在正式构建中执行额外启动测试或 runtime 版本探测。

当前输出为 `dist/dingtalk.AppImage` 和 `dist/version.txt`。SHA-256 写入构建日志；workflow 直接上传标准版本文件，成功发布后按现有机制更新 `software_versions.json`。旧的本地 `dingtalk.AppImage.sha256`、`dingtalk-version.txt` 不再生成，也不再作为 CI 输入。

- [模板差异、来源和 CI 说明](./docs/template-deviations.md)
- [固定配置与原始故障依据](./docs/hardcoded.md)
- [打包分类](../docs/packaging-classification.md#直接-appimagetool)

## 本次核对与验证

已核对当前 AUR 快照及官方 DEB，完整 SHA-512 校验通过；真实包的目录整理、版权文档、desktop 净化和保留资源已核对。2026-11-02 用户已提供当前产物的实机验证截图，主界面、中文输入、文件选择器、会议摄像头及进入屏幕共享状态已通过；具体范围和日志观察见下方用户实机验证记录。

## 历史基线说明

下面保留 2026-08-06 的用户实测结果及后续修复历史。容器、makepkg、两阶段启动测试和旧产物格式属于当时实现，已在本次获准迁移中由上述公共流程替换；不能因历史保护项再恢复这些步骤。已确认的 Qt/CEF 启动方式与必要运行库处理继续作为当前基线依据。

## 历史基线状态

- 状态：稳定基线
- 基线日期：2026-08-06
- 架构：x86_64
- 构建环境：Ubuntu 24.04 GitHub Actions
- 上游来源：AUR `dingtalk-bin`
- 本次实测上游版本：`8.1.0.6021101-1`
- 输出文件：`dingtalk.AppImage`

工作流默认从 AUR 获取当前 `dingtalk-bin`。本基线记录的是 2026-08-06 在真实 Arch Linux + i3wm 环境完成验证的构建方案。

## 历史已确认功能

- AppImage 正常启动
- 扫码登录正常
- 登录后主界面正常
- 会话、消息和图片显示正常
- 文档、工作台等内嵌网页正常
- 视频会议窗口正常
- 摄像头和麦克风正常
- 退出后可以再次启动

## 历史基线包含的关键处理

1. 使用 Arch Linux 容器从 AUR 生成并提取完整 `dingtalk-bin` 包。
2. 保留以下已经验证有效的 AUR 构建命令：

   ```bash
   su - builduser -c "cd /tmp/dingtalk-bin && makepkg --nodeps --noconfirm"
   ```

3. 保留钉钉官方运行目录结构，不拆分 Qt、CEF 和私有组件。
4. 将 `plugins/dtwebview` 加入运行库搜索路径，并预加载内置 `libcef.so`。
5. 清除钉钉 ELF 文件的可执行栈标记，兼容较新的内核和 glibc。
6. 递归收集主程序、插件、会议组件和私有库的外部动态库。
7. 打包同一 Ubuntu 软件包版本的完整 NSS 运行组件，避免 `libsoftokn3.so` 与 `libnssutil3.so` 符号版本冲突。
8. 仅从临时 AppImage 源目录移除不参与主程序运行、且依赖旧 `libpangox` 的诊断组件。
9. 修正 AUR desktop 文件中的重复键，再交给 `appimagetool`。
10. 构建前检查全部 ELF 动态库，构建后分别执行 AppDir 和最终 AppImage 图形启动测试。
11. 生成 SHA-256 校验文件和版本说明文件，并上传到 `latest` Release。

## 历史基线保护项

以下内容已经实际验证有效，后续没有明确故障时不要改写、替换或删除：

- AUR 的 `makepkg --nodeps --noconfirm` 命令及执行顺序
- `CEF_LIB_DIR`、`LD_LIBRARY_PATH` 和 `LD_PRELOAD` 处理
- 完整 NSS 运行组件复制步骤
- ELF 可执行栈清理步骤
- 动态库递归收集和缺失依赖检查
- desktop 重复键净化
- AppDir 与最终 AppImage 两阶段启动测试
- `ARCH=x86_64 appimagetool "$APPDIR" "$OUTFILE"` 打包命令

修改这些部分前，应先完整检查工作流、构建脚本和历史故障原因，避免通过多次 Actions 运行试错。

## 历史生成文件

```text
dingtalk.AppImage
dingtalk.AppImage.sha256
dingtalk-version.txt
```

校验：

```bash
sha256sum -c dingtalk.AppImage.sha256
```

运行：

```bash
chmod +x dingtalk.AppImage
./dingtalk.AppImage
```

## 日志说明

下列日志在程序继续正常工作的情况下属于非致命信息，不应单独作为重新打包依据：

```text
The resource ... was preloaded ... but not used
Failed to set crash key
rpc request fail ... timeout
```

出现以下内容时才应按致命运行错误处理：

```text
error while loading shared libraries
symbol lookup error
NSSUTIL_* not found
Segmentation fault
Illegal instruction
Could not load the Qt platform plugin
```

## 相关文件

```text
.github/workflows/build.yml
.github/scripts/ci_build_dingtalk.sh
dingtalk/build_dingtalk.sh
dingtalk/README.md
```

## 历史版本元数据接入

### 2026-09-16：接入 `software_versions.json`

- 修改文件：`.github/workflows/build.yml`、本 README。
- 版本来源：`dingtalk-version.txt` 中的 `version=`，由 workflow 标准化为 `dist/version.txt`。
- 成功构建后上传 `software-version-dingtalk` 元数据 artifact；当前 Build 仅在对应构建成功后更新 `latest` Release 中的 `software_versions.json`。
- `software_versions.json` 使用版本号判断是否需要更新，Release SHA-256 仅用于文件完整性与本地状态；相同版本的重复构建不会仅因 SHA-256 改变而触发客户端更新。
- 本次不改应用打包、运行时、补丁和 Release 资产名；提交后按仓库规则不主动监控 Actions，实际新清单记录以下一次成功构建结果为准。

## 修复记录

### 2026-09-17：跳过会变动的服务条款 HTML 校验

- AUR `dingtalk-bin` 的 `service-terms-zh_*.html` 页面内容会变，导致 `makepkg` 的 `sha512sums` 失败；该文件只进 license 目录，不进入 AppImage。
- 在 `makepkg` 前把这一项改成 `SKIP`，DEB 和其余源文件校验保持不变。
- 不改 `makepkg --nodeps --noconfirm`、运行时收集和打包步骤。

### 2026-11-02：对齐直接 appimagetool 标准并接入公共 AUR 组合入口

- 故障：新版 appimagetool 在最终封装时拒绝 SVG `.DirIcon`，报 `appimagetool: no AppImage was created because .DirIcon is not valid.`；旧 CI 还重复安装环境、下载工具、生成旧版本文件并执行两轮启动测试，不能直接接上本次确认的精简 build。
- 修改文件：`build_dingtalk.sh`、两份 `patches/`、CI 入口及 `build.yml` 的 DingTalk job；同步本 README、模板差异、固定配置、打包分类、export 登记、上游索引和来源规范。
- 修复：主 build 一次调用公共 AUR 入口完成下载、摘要与包身份校验、安装、解包和版本返回；沿用 AUR 布局及组件清理，保留同一环境的 NSS/NSPR、可执行栈、递归依赖和 Qt/CEF 启动处理。最终只调用公共封装入口准备权限、PNG 根图标、正式 AppImage 和标准版本文件。
- CI：仍使用 Ubuntu 24.04，发布名称与软件清单 key 不变；旧容器、makepkg、旧版本文件转换和两轮图形启动测试不再执行。本次不更改其他 job、公共脚本或发布动作。
- 真实来源验证：动态读取 AUR `9f15353cb6556398d3cd3ac594a57ca4a824200a`，下载官方 DEB `8.2.8.260904001` 并通过完整 SHA-512。真实包经新补丁整理后，按 DEB 自带 MD5 清单核对了 2341 份保留文件；29 份清单文件按既有 AUR / 诊断组件规则移除，版权文档与 desktop 净化核对通过。
- 隔离验证：19 项检查通过，覆盖完整 CI → build 调用、NSS/NSPR 16 文件、真实 ELF 可执行栈清理、两轮依赖收集与软链接、SVG 渲染、AppRun 参数和宿主覆盖、错误拦截、YAML 与仅选中钉钉。使用当前官方 appimagetool / Type 2 runtime 对原生 ELF 替身真实封装并提取执行；依赖扫描使用官方 pax-utils 的 lddtree，来源传输及系统安装使用替身。
- 验证边界：本条记录的是迁移时的原生 ELF 替身检查；当次未在云端执行完整 Ubuntu 24.04 钉钉 GUI 构建、官方 DEB 安装脚本或登录、会议等功能测试。本轮用户实机验证结果见下方记录，历史用户实测成功记录继续保留。提交后不等待、监控或重跑 Actions。

### 2026-11-02：兼容 Ubuntu 平铺的 NSS 模块目录

- 故障：[Build DingTalk 失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41456031830/job/125312892486) 显示官方 DEB 下载、完整摘要校验和安装均已通过，随后公共 NSS 入口复制 5 个 `nss/` 路径时退出。该次 Ubuntu 24.04 的 `libnss3 2:3.98-1ubuntu0.3` 实际把 `libnssckbi.so`、`libnssdbm3.so`、`libsoftokn3.so` 及后两者的 `.chk` 平铺在 `/usr/lib/x86_64-linux-gnu/`。迁移时未核对公共入口与 Ubuntu 实际目录的差异，前次隔离验证只覆盖了旧 `nss/` 布局，漏检了此处。
- 修改文件：`common/linuxdeploy/copy_nss_runtime.sh`、`common/README.md`、本 README、固定配置和模板差异说明。公共入口优先使用完整的 `nss/` 模块组，否则整组使用 multiarch 平铺目录，必需文件缺失仍失败；原单参数 13 文件、`--with-nspr` 16 文件、复制选项和应用调用保持不变。
- 真实包与兼容验证：解包与失败日志同版本的官方 Ubuntu `libnss3` 和 `libnspr4 2:4.35-1.1build1`，旧入口复现相同的 5 个路径错误，新入口分别完成 13 / 16 文件复制。38 项检查通过，覆盖两种布局、旧目录不完整时整组回退、不拼接两套不完整目录、缺文件失败及文件内容、权限、时间戳和原参数兼容。
- 打包调用验证：使用平铺 NSS 文件和原生 ELF 替身，19 项隔离检查通过；真实调用现有 CI → build、依赖收集、官方 appimagetool / Type 2 runtime 封装及提取执行，并确认 AppRun 参数、宿主覆盖和符号不匹配拦截。当次来源传输及系统安装仍使用替身，未执行完整 Ubuntu 钉钉 GUI 构建；本轮用户实机验证结果见下方记录。
- 保留边界：钉钉 build、两份 patches、AppRun 与 workflow 沿用已确认版本；检查仅在临时目录执行，正式构建没有新增测试。Joplin、Binance 的原单参数调用保持兼容，应用实机成功记录继续保留。

### 2026-11-02：用户实机验证

- 验证依据：用户提供的 Linux 实机截图；运行日志显示版本 `8.2.8-Release.260904001`。
- 主界面与输入：可启动并进入已登录主界面，会话和历史消息可显示；聊天输入框可输入中文并显示输入法候选窗。
- 文件选择器：附件入口可打开文件选择窗口并浏览目录。
- 会议与摄像头：可进入视频会议，会议窗口可显示本机摄像头画面。
- 屏幕共享：可打开共享选择窗口并显示桌面预览，选择后进入“共享中”状态。
- 验证范围：本组截图未确认文件传输完成、双向音视频和对端共享接收效果；已通过项目按用户实测完成记录，历史基线实测结论继续保留。

#### 运行日志观察

本轮实测中仍出现以下告警、错误或含超时字样的日志，未观察到它们影响上述已验证功能。当前无需因此修改启动参数、调整打包或重新构建；如后续出现实际功能异常，再结合对应时间的日志判断。

| 日志类型 | 截图中的关键信息 |
| --- | --- |
| GLib/GIO 权限告警 | `Error creating IO channel for /proc/self/mountinfo: Permission denied (g-io-error-quark, 14)` |
| Qt 光标位置提示 | `QTextCursor::setPosition: Position '12' out of range` |
| 线程长任务 | `[ThreadPoolMonitor] OnLongTaskDetected` |
| 会话缓存与数据模型 | `conversation id is empty`、`conv not exist in cache`、`ProcessMemberChangedDelta, fail, model has no member version` |
| 内部事件分发 | `unrecognized web event`、`Two Can not find event`，涉及会话未读数、扩展、群直播状态和日历刷新等事件。 |
| RPC 请求超时 | `SendRequest fail`，其中 `status=-1`、`code=-3`、`reason=timeout`。 |
| 同步数据库日志 | `[sync]insert db timeout`、`[sync]insert db timeout and push data empty`；按截图中的日志文字记录，不据此判定数据库损坏。 |
