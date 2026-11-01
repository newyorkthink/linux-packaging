# kitty AppImage

## 用途与产物

本目录使用 kitty 官方 Linux 预编译包构建 `dist/kitty.AppImage`，并保留 `kitten` 分派、xterm-kitty terminfo 与现有输入法运行逻辑。

## 技术栈与打包方式

kitty 为 GPU 加速终端，主体由 C/Python 组件组成。构建脚本通过官方 installer 下载完整程序目录，补入 Arch `kitty-terminfo` 与 `libxcb-xkb`，自定义 AppRun 处理 terminfo、kitten、Fcitx5/IBus 与 tmux 环境，再使用 appimagetool + Type 2 runtime 生成 AppImage。

## 当前公共入口

| 操作 | 公共入口与职责 |
| --- | --- |
| 下载 installer、appimagetool 和 Type 2 runtime | 统一单行调用 `common/download/download_file.sh`，保留原官方 URL 和输出位置，由公共入口处理重试、超时和临时文件。 |
| PNG 图标、正式封装和版本保存 | 统一单行调用 `common/linuxdeploy/package_appimage.sh`，由它准备权限及 PNG、执行 appimagetool、检查产物、输出 SHA-256 并保存 `dist/version.txt`。 |

公共封装入口不会运行 linuxdeploy，kitty 仍使用官方预编译包与 appimagetool 路线。资源脚本只复制应用图标，不再手工创建 `.DirIcon` 或重复调用 PNG 准备入口；最终封装时由 appimagetool 根据 PNG 根图标创建 `.DirIcon`。

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
