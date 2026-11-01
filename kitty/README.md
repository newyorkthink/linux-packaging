# kitty AppImage

## 用途与产物

本目录使用 kitty 官方 Linux 预编译包构建 `dist/kitty.AppImage`，并保留 `kitten` 分派、xterm-kitty terminfo 与现有输入法运行逻辑。

## 技术栈与打包方式

kitty 为 GPU 加速终端，主体由 C/Python 组件组成。构建脚本通过官方 installer 下载完整程序目录，补入 Arch `kitty-terminfo` 与 `libxcb-xkb`，自定义 AppRun 处理 terminfo、kitten、Fcitx5/IBus 与 tmux 环境，再使用 appimagetool + Type 2 runtime 生成 AppImage。

## 当前公共入口

| 操作 | 公共入口与职责 |
| --- | --- |
| 下载官方 installer | 调用 `common/download/download_file.sh`，保留原官方 URL、输出位置和 installer 的执行参数。 |
| 读取当前程序版本 | 调用 `common/build/read_app_version.sh` 的 `command` 来源，传入真实程序、字段 2 和原 `--version` 参数；解析与格式校验放在公共入口。 |
| 下载封装工具和 runtime | 一次调用 `common/linuxdeploy/prepare_linuxdeploy_tools.sh --appimagetool`，取得两个官方 continuous 文件、校验 SHA-256 并设置执行权限。 |
| PNG 图标、正式封装和版本保存 | 调用 `common/linuxdeploy/package_appimage.sh`，统一处理权限、PNG、封装、有效产物检查、SHA-256 和 `dist/version.txt`。 |

两个公共工具入口都不会让 kitty 运行 linuxdeploy，kitty 仍使用官方预编译包与直接 appimagetool 路线。资源脚本只复制应用图标；最终封装时由 appimagetool 根据 PNG 根图标创建 `.DirIcon`。主脚本不再单独下载两个封装工具、添加它们的执行权限或重复打印“已生成”。

## 运行与兼容说明

```bash
./dist/kitty.AppImage
```

现有 X11/Fcitx5 地址处理、terminfo、kitten 软链接和 tmux 环境隔离逻辑保持不变。

## 文件组织与 `kitten` 链接

- [build_kitty.sh](./build_kitty.sh) 保留主构建流程。
- [AppRun](./AppRun) 保存原有完整启动逻辑，构建时复制到包内；通过名为 `kitten` 的软链接启动时，继续转到包内 `bin/kitten`。
- [patches/prepare_appdir.sh](./patches/prepare_appdir.sh) 负责运行库、terminfo、desktop 与图标准备。
- 专属处理和检查取舍见 [整理说明](./docs/template-deviations.md)，固定配置及图标原始报错见 [配置与故障依据](./docs/hardcoded.md)。

在 `kitty.AppImage` 所在目录的 Linux 终端执行：

~~~bash
# 创建名为 kitten 的软链接，指向同一目录的 kitty.AppImage。
ln -s kitty.AppImage kitten

# 通过软链接调用包内 kitten，并查看帮助。
./kitten --help
~~~

## 版本元数据

构建脚本从本次官方 kitty 程序的 `kitty --version` 输出解析版本，并在现有构建流程结束后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=kitty` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本解析与发布元数据，不改变 kitty 官方包、AppRun、输入法、terminfo 或 appimagetool 基线。

### 2026-11-01：拆分构建脚本并修复 PNG `.DirIcon`

- 修改 `build_kitty.sh`；新增 `AppRun`、`patches/prepare_appdir.sh`、`docs/hardcoded.md` 和 `docs/template-deviations.md`。
- 原 `AppRun` 的 169 行正文逐字迁出，保留用户已确认可用的 `kitten` 软链接分派，以及既有 Fcitx5 / IBus、terminfo、tmux 和日志过滤行为。
- 删除冗余架构预检、文件断言及构建自测；保留版本、`kitten` 入口、GLFW 扩展、真实缺库和最终有效产物检查。
- 本次失败日志显示 `.DirIcon` 指向 `kitty.svg`，被新版 `appimagetool` 拒收。资源准备复用现有公共入口取得 PNG，并明确将 `.DirIcon` 指向 `kitty.png`。
- 原依赖安装、官方 installer、`appimagetool` 下载与封装命令保持不变；workflow、发布资产名和其他应用不变。
- 提交前的 14 项检查已通过，覆盖 Shell 语法、`AppRun` 正文逐字一致、原安装及封装命令、kitty / `kitten` 分派、参数与环境行为、PNG 图标、缺库失败分支、版本文件和文档链接。运行分派及资源处理使用隔离临时目录中的替身输入验证；未重复执行完整依赖安装、完整打包和桌面交互，原有用户确认的功能基线继续保留；提交后不监控 Actions。

### 2026-11-01：统一公共下载与封装入口

- 修改 `build_kitty.sh`、`patches/prepare_appdir.sh`、本 README 及两份专属说明，接续 [7813f09](https://github.com/newyorkthink/linux-packaging/commit/7813f09eb577e2c985c1b22f781286dad159a0b4) 的整理结果。
- 三处 `curl` 改为公共下载调用，官方 URL、下载位置、installer 的执行参数及原依赖安装命令保持不变。
- 最终封装、权限和 PNG 准备、产物非空检查、SHA-256 输出及版本保存统一交给公共封装入口，不再重复调用版本保存脚本。
- 资源脚本只准备图标文件，不再创建 SVG `.DirIcon`；公共入口先准备 PNG，再由 appimagetool 创建最终图标链接。
- `AppRun` 未修改，169 行正文及 kitten 软链接分流保持原样；现有输入法、terminfo 和 tmux 行为继续沿用。
- 提交前的 10 项检查已通过，覆盖 Shell 语法、三处下载来源、公共封装参数、PNG 准备顺序、版本写入、失败退出和文档链接；完整 diff 已核对。下载及封装调用链使用临时替身工具验证，公共脚本按原文执行，未执行真实下载、完整打包或桌面交互。

### 2026-11-01：统一版本读取、工具准备及规范分类

- 版本读取改为公共 `command` 来源，继续执行同一程序的 `--version` 并取首行第二字段；原版本格式校验移入公共入口，主脚本不再重复解析。
- 两个封装文件通过工具准备入口的 `--appimagetool` 模式一次下载、核对官方 SHA-256 并设置执行权限；该模式不取得 linuxdeploy 或插件，原两个输出路径保持不变。
- 删除末尾仅表示成功的 `echo`，保留公共封装入口已有的校验值输出。
- 依赖安装改用现有 Arch 公共入口，原有 10 个包参数及其安装阶段保持不变；不修改基础包清单。
- AppRun 及 kitten 分派未修改，原 installer 命令、依赖、构建顺序和必要运行检查保持不变。
- AGENTS、打包规范、注释标准及分类索引明确 AppDir / appimagetool 的两种模式属于同一体系，quick-sharun / sharun 使用另一套规范；不批量重写其他应用。
- 公共版本入口原三种来源、元数据参数，以及 linuxdeploy 工具准备的原独立执行与 source 接口继续保留。提交前 12 组检查已通过，覆盖新版本来源、命令失败、旧版本接口、元数据参数、工具下载和摘要、六种原插件组合、六种 source 调用方式及文档链接；联网调用使用临时替身，未执行真实下载、完整构建或图形程序。

### 2026-11-02：对齐主脚本的通用分区与注释

- 适用分区标题、依赖安装和 AppRun 执行权限注释逐字复用 [固定注释标准](../docs/linuxdeploy-comments.md)，原有版本读取、工具准备和最终封装注释继续保留；程序专属说明不改写。
- 只调整主脚本注释和对应空行。所有非注释、非空白代码行逐字一致，安装参数、路径、检查和执行顺序不变；独立 AppRun 及 kitten 分派未修改。Arch 基础包前置和封装工具的原下载位置保留，原因及适用边界见 [专属说明](./docs/template-deviations.md)。
- 提交前核对 Shell 语法、固定原文、去除注释与空行后的代码、文档链接和完整 diff；未重新安装依赖、试打包或运行程序。此项为注释整理，不作为新的构建或运行故障修复记录。
