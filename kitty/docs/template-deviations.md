# kitty 脚本整理与专属处理

## 路线与范围

继续使用官方 Linux 预编译包、自定义 `AppRun`、官方 `appimagetool` 和 `Type 2 runtime`。基线为 [65850a8 中的 build_kitty.sh](https://github.com/newyorkthink/linux-packaging/blob/65850a8e11bad58bcf30fac33dae6dc20dd31be9/kitty/build_kitty.sh)，不套用 `quick-sharun` 或 `linuxdeploy` 模板。

已查阅上游打包参考索引并检索 pkgforge-dev 的 kitty 对应仓库，本次未找到对应打包实现，因此没有新增第三方 hook 或启动代码。官方程序仍由原 installer 取得，应用与打包工具都不固定旧版本。

## 7813f09 基线的文件与执行阶段

| 文件 | 阶段与处理 | 原因及影响 |
| --- | --- | --- |
| ../build_kitty.sh | 保留环境准备、官方下载、版本解析、`AppRun` 安装和最终封装；实际版本通过公共入口保存。 | 主脚本只负责构建顺序；原 installer、依赖安装和 `appimagetool` 封装命令保持原样。 |
| ../AppRun | 原 heredoc 的完整正文逐字保存，构建时复制到 `AppDir/AppRun`。 | 保留 `kitten` 分派、参数、输入法地址、terminfo、tmux 与既有日志过滤行为。 |
| ../patches/prepare_appdir.sh | 下载应用后准备 libxcb-xkb、terminfo、desktop 和根图标。 | 程序专属的资源处理集中维护，不混入工具下载阶段。 |
| ../../common/appimage/prepare_appdir_for_appimagetool.sh | 在资源准备末尾取得合格的 PNG 根图标，再将 `.DirIcon` 指向 `kitty.png`。 | 复用已有公共实现，修复本次 SVG `.DirIcon` 封装失败；不修改公共脚本。 |
| ../../common/build/save_appimage_version.sh | 最终封装完成后确认 AppImage 非空，再写 `dist/version.txt`。 | 保留有效产物检查，避免构建未产生有效资产时写出成功版本。 |

## 精简检查的边界

删除仅用于预检或自测的架构判断、可由后续实际命令报错的文件断言、`AppRun` 的 `bash -n` 与 `grep` 清单、`infocmp` 查询、Python `+runpy` 探针，以及最终 AppImage 的版本、terminfo 和临时 `kitten` 链接自测。语法、启动分派和图标检查在提交前的隔离临时目录中进行，不再留在正式构建流程里。

保留以下必要判断：

- kitty 版本格式校验，防止无效版本进入发布元数据。
- 包内 `bin/kitten` 的可执行性检查，避免普通 kitty 可运行但软链接入口缺失的产物。
- 动态加载的 `kitty.glfw-x11.so` 存在性与真实缺库检查。
- 既有严格模式、错误退出与最终 AppImage 非空检查。
- `AppRun` 中用于启动分派、输入法就绪和 tmux 环境处理的全部运行判断。

没有把“精简判断”扩大为删除所有 `if` 或 `test`。运行功能、真实依赖错误和发布所需的有效性判断继续保留。固定配置与本次原始报错见 [hardcoded.md](./hardcoded.md)。

## 当前公共入口与执行顺序

下表接续上面的基线记录，说明本次公共化后的当前实现。原基线的资源阶段 PNG 准备和单独版本保存已由公共封装入口替代。

| 当前阶段 | 实际调用与职责 |
| --- | --- |
| 官方文件下载 | 三次单行调用 `common/download/download_file.sh`，分别下载原 installer、appimagetool 和 Type 2 runtime。 |
| 应用安装与版本读取 | 沿用原 installer 命令和版本解析，不更换官方程序来源或目录布局。 |
| 程序资源准备 | `patches/prepare_appdir.sh` 保留运行库、terminfo、desktop 和原图标复制；移除手工 `.DirIcon` 链接、PNG 公共调用和因此不再使用的路径变量。 |
| 运行入口 | 原样复制 `AppRun`，保留 kitten、输入法及 tmux 的全部行为。 |
| 最终封装 | 单行调用 `common/linuxdeploy/package_appimage.sh`，传入 appimagetool、AppDir、输出文件、runtime 和实际软件版本。 |

`package_appimage.sh` 内部只执行 PNG / 权限准备和 appimagetool 封装，不运行 linuxdeploy。PNG 准备在封装前执行一次；资源脚本不再创建旧的 SVG `.DirIcon`，由 appimagetool 根据合格根图标创建最终链接。最终资产非空检查、SHA-256 输出和版本写入也由该入口负责，调用方不再重复保存版本。

本次未修改 `common/`、workflow、应用清单或其他应用；仍由既有 push 规则选中 kitty 构建。上文精简检查的边界继续有效。

## 当前公共版本与工具准备接口

本节替代前一阶段中“分别下载两个封装工具”的当前调用方式，前述记录保留为演变依据。

| 操作 | 当前调用及保留依据 |
| --- | --- |
| 版本读取 | `read_app_version.sh command "$KITTY_DIR/bin/kitty" --field 2 -- --version`；保留原程序、查询参数、首行第二字段和原版本格式规则。 |
| 工具准备 | `prepare_linuxdeploy_tools.sh --appimagetool /tmp/appimagetool /tmp/runtime-x86_64`；一次处理两个官方 continuous 资产、摘要及权限，跳过 linuxdeploy 和插件。 |
| 最终封装 | 沿用公共 `package_appimage.sh`；PNG、有效产物、SHA-256 和版本只处理一次。 |
| 构建输出 | 删除仅表示“已生成”的末尾 echo，保留公共入口必要的校验结果与错误输出。 |

直接模式与 linuxdeploy 归入同一 AppDir / 官方 appimagetool 体系，复用适用的风格与公共入口；quick-sharun 另按其规范。kitty 保留已验证的 Arch 构建环境、installer 执行顺序、独立 AppRun、kitten 入口及资源准备，不为风格一致套用 linuxdeploy 的 Ubuntu / 插件 / 中间产物步骤。

AppRun 的 169 行正文保持原样，公共接口扩展不修改其他应用脚本。固定取值及历史依据见 [hardcoded.md](./hardcoded.md)。

## 2026-11-02：主脚本注释与分区对齐

直接 appimagetool 模式逐字使用 [固定注释标准](../../docs/linuxdeploy-comments.md) 中适用的分区标题、依赖安装和 AppRun 执行权限注释；已一致的通用注释和现有程序专属说明保留。

本次只整理注释与空行，不移动或改写命令。Arch 基础包仍按原位置提前安装；最终封装工具仍在 AppRun 准备之后取得，保留原有已确认顺序。分区仅标明实际执行阶段，不为了套用 linuxdeploy 的默认顺序移动代码，也不增加初始化、插件、部署或中间包阶段。独立 AppRun 及 kitten 分派保持原样。
