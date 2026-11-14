# AltTab 专用打包流程与模板差异

## 分类与同类参考

本项目登记在[专用打包流程](../../docs/packaging-classification.md#专用打包流程)：从官方最新正式 Release 对应提交取得源码，应用九个独立补丁，经 `configure` / `make` 编译后交给 quick-sharun 封装。现有 Arch 系统入口模板不包含这条源码适配和编译流程。本次按明确要求手动对应同类项目，不运行生成器，不新增标准模板。

参考基线为 [`37014f1`](https://github.com/newyorkthink/linux-packaging/tree/37014f1ca48de02fc8ea1c27d8bed97fa58aed2a)，具体对应关系如下：

| 参考项目 | 对应部分 |
| --- | --- |
| [Webcamoid](https://github.com/newyorkthink/linux-packaging/blob/37014f1ca48de02fc8ea1c27d8bed97fa58aed2a/webcamoid/build_webcamoid.sh) | 公共安装和 `AppDir/work/dist` 工作区、正式 Release 源码准备、编译后收集及公共版本保存。 |
| [st](https://github.com/newyorkthink/linux-packaging/blob/37014f1ca48de02fc8ea1c27d8bed97fa58aed2a/st/build_st.sh) | 源码构建与补丁的专属标注、工作区管理、明确主程序入口及许可证保留。 |
| [Newsboat](https://github.com/newyorkthink/linux-packaging/blob/37014f1ca48de02fc8ea1c27d8bed97fa58aed2a/newsboat/build_newsboat.sh) | 通用初始化、固定注释、元数据、依赖收集和最终封装的写法。 |

这里只对应实际适用的公共部分；各参考项目自己的 Qt、终端、字体配置及其他专属处理不复制进 AltTab。应用清单中的 `kind: standard` 表示使用统一 Arch matrix 调度，不表示逐字套用了某份系统软件包模板。

## 公共阶段

| 阶段 | 当前处理 | 依据与影响 |
| --- | --- | --- |
| 初始化 | 严格模式，定位并切到本应用目录。 | 相对路径均落在本应用工作区。 |
| 依赖安装 | `common/arch/install_packages.sh --base` 加一行明确的原有额外依赖。 | 原先 25 项显式包名逐项核对：基础入口已覆盖 gcc、base-devel、pkgconf、wget、git、jq、binutils、patchelf、coreutils、appstream-glib、desktop-file-utils、util-linux、zsync、glib2；应用行保留三个 Xorg 包、原有 X11 图形库及 uthash，不减少依赖覆盖。 |
| 工作区 | 调用 `common/build/prepare_x86_64_workspace.sh`，只清理本应用的 `AppDir`、`work`、`dist`，重建 `work` 与 `dist`。 | 源码为 `work/source`，桌面文件为 `work/alttab.desktop`；不再使用原独立临时目录和退出 trap。工作区保留至下一次构建清理。 |
| 版本与源码 | 调用 `common/github/download_latest_stable_release_source.sh`，参数为 `sagb/alttab`、源码目标目录及 `--archive`。 | 保留最新正式 Release → 完整提交 SHA → 源码归档的来源方式；认证、下载、SHA-256 记录及格式解包在公共入口处理，stdout 返回原始标签。 |
| 元数据与封装 | 固定 `MAIN_BIN=alttab`，输出 `dist/alttab.AppImage`；原 quick-sharun 收集与封装命令保留。 | 源码 SVG、生成的 desktop 和许可证按下节保留。 |
| 版本保存 | 最终封装后调用 `common/build/save_appimage_version.sh`。 | 产物非空检查、执行权限及 `dist/version.txt` 写入由现有公共入口负责；应用脚本不重复通用存在性检查。 |

## 保留的专属处理

| 处理 | 代码位置 | 保留原因与影响 |
| --- | --- | --- |
| 九个独立补丁 | [`patches/apply-icon-patch.sh`](../patches/apply-icon-patch.sh) 和同目录九个 `.patch` 文件。 | 保留已确认的图标、挂载命名空间、字体、标题及键盘行为；不合并、不重写 patch，`patch --batch --forward --fuzz=0` 和应用顺序保持原样。 |
| GLib 参数 | [`build_alttab.sh`](../build_alttab.sh) 的 `pkg-config --cflags glib-2.0`、`pkg-config --libs glib-2.0`、`CPPFLAGS` 和 `LIBS`。 | 原 desktop 元数据解析补丁需要 GLib；编译、链接参数及顺序不变。 |
| 源码编译 | 原 `./configure --prefix=/usr` 与 `make -C "$SOURCE_DIR" -j"$(nproc)"`。 | 使用本次正式版源码和全部现有补丁生成真实程序，不改为收集另一个系统安装包。 |
| 桌面资源与许可证 | 生成的 `alttab.desktop`、源码 `doc/alttab.svg` 和 `COPYING`。 | desktop 正文、图标来源、许可证目标位置及复制参数保持原样，仅把生成 desktop 的位置统一到 `work`。 |
| 更新指纹 | `normalize_fingerprint_script`、`ALTTAB_BUILD_FINGERPRINT` 和 `ALTTAB_UPDATE_VERSION`。 | 保留两个脚本忽略空行及纯注释行、所有 patch 按文件名排序并按原字节计算、取 SHA-256 前 12 位的规则；版本格式仍为“上游版本 + linuxpackaging 指纹”。AppImage 内部 `VERSION` 保持纯上游版本。 |

补丁应用脚本仍保留历史文件名 `apply-icon-patch.sh`。迁移到 `patches/` 后，脚本内部从自己的目录直接读取九个 patch；主构建的实际调用和指纹输入均同步为新路径。指纹中的 `*.patch` 集合仍只有原来的九个文件，不会把 `.sh` 重复计入。

公共调用及脚本路径发生变化，因此本次按原有算法产生新的构建指纹；不是锁定新上游版本，也不引入时间戳或额外版本规则。

## 核对与运行记录

本次静态核对完整差异、依赖覆盖、公共接口、补丁路径和顺序、原编译与封装命令及 Git 文件模式。没有新增测试文件、修改公共脚本或 workflow，也不手动触发额外构建。

原有图标、字体和标题排版的稳定基线及完整历史见 [README](../README.md#稳定基线与维护规则)。原生 `-vp pointer` 的虚拟副屏显示通过结果统一见 [README 实机验证](../README.md#实机验证)，本次没有增加显示源码补丁。
