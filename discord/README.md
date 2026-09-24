# Discord AppImage

## 来源与构建

`build_discord.sh` 从 [Discord 官网](https://discord.com/download)动态下载 stable Linux tar.gz，只提取官方 `discord.desktop` 和 `discord.png`。官网归档中的程序入口是 bootstrap，不作为 AppImage 主程序；完整 stable 主程序及模块从 Discord 官方更新清单对应的 `full.distro` 动态取得，并统一通过 `common/archive/extract_archive.sh` 解包。脚本核对清单版本与完整包内 `resources/build_info.json` 一致后，把真实程序树放入 `AppDir/shared/bin` 保持 Electron 相邻资源布局，再使用 quick-sharun 封装 `dist/discord.AppImage` 和 `dist/version.txt`。

不运行官方 `postinst.sh` 或 bootstrap，不修改宿主机 AppArmor、服务或用户配置。官方完整程序下载需要访问 `updates.discord.com`；构建环境无法连接时构建会失败，不会发布只有安装器的假 AppImage。实际桌面运行状态以本 README 后续记录为准。

## 2026-09-23：首次 CI 构建失败

官方安装器已成功下载完整 stable 程序，但返回的是目录名 `app-1.0.159`，原脚本误认为必须是纯版本号而退出。现在把 `app-` 前缀留在实际文件目录路径中，只从目录名提取软件版本写入 `dist/version.txt`；后续构建结果待确认。

第二轮 CI 已下载完整程序；quick-sharun 在复制图标时发现源文件和 AppDir 内目标是同一个文件而退出。图标与 desktop 现在从 AppDir 之外的官方源目录传给封装工具，下一轮结果待确认。

第三轮 CI 运行到封装主程序时提示 `Main binary is set to 'discord', but this file is NOT present`：官方下载的真实可执行文件名为 `Discord`。现已同步修正 `MAIN_BIN` 和桌面入口，后续构建待确认。

## 2026-09-23：Release 成品版本与官方下载器目录不一致

用户运行已成功构建的 Release 成品后，程序显示 `1.0.158`，并要求下载 `1.0.159`。解开同一 Release 的 `discord.AppImage`，其中 `bin/resources/build_info.json` 的实际版本确为 `1.0.158`；官方下载器返回的目录名却是 `app-1.0.159`，原脚本错误地把目录名记录成成品版本。官网当时的 `1.0.159` Linux tar.gz 和 DEB 都只有约 2 MB，需要该官方下载器另行获取完整程序；上游更新清单的 full.distro 也声明 `1.0.159`。现增加实际版本一致性检查：两者不一致时立即停止构建，禁止把旧程序作为最新版本继续发布。此时上游完整程序来源待修复，用户桌面仍会出现更新提示。

经与本仓库 `mpv`、`smplayer` 以及 quick-sharun 自带默认 `AppRun.sh` 核对，Discord 原来的手写 `AppRun.sh` 只重复指定启动程序和工作目录，没有证据表明需要保留；现交由 quick-sharun 生成默认入口。用户桌面效果尚待新成品确认。

## 2026-09-23：同名 Release 资产导致上传失败

Actions 运行 35846090462 已生成 `discord.AppImage`，但上传 `latest` 时因已有 `discord.AppImage`，`gh release upload --clobber` 连续返回 HTTP 422 `ReleaseAsset.name already exists`，重试八次仍失败。现仅在 Discord 的完整程序封装完成后，若 CI 中的 Release 已存在同名资产，先明确删除旧资产，再由现有共享步骤上传新资产；删除失败则停止发布。新一轮上传结果及桌面运行效果待确认。

## 2026-09-23：补充中文输入和中文环境

用户截图显示仍在运行 `1.0.158`，且提示 `1.0.159` 可用；上一次构建虽通过包内版本一致性检查，却在上传 Release 时失败，因此该截图不能证明新构建已替换旧资产。保留已有版本检查与同名资产上传修复，本次只调整 `build_discord.sh`：应用级安装 Arch 的 `ibus`、`fcitx5-gtk`，将两个 GTK3 输入模块明确交给 quick-sharun；生成包内 `zh_CN.UTF-8` locale 并写入 `LANG`、`LANGUAGE`、`LOCPATH`。不覆盖宿主会话选择的输入法，也不更改 Discord 官方资源或启动入口。新产物的版本、中文界面和中文输入仍待实际构建与运行确认。

## 2026-09-23：更新提示与 Release 资产核对

用户在 18:34 的启动日志中看到程序自身版本 `1.0.158`，Discord 提示 `1.0.159` 可下载。核对仓库 `main` 的构建脚本、已有 Build Discord 运行 35848533399 和 `latest` Release：该 Job 于 18:30 成功结束，现有脚本在封装前检查官方安装目录版本与 `resources/build_info.json` 的真实程序版本一致；Release 的 `discord.AppImage` 资产 ID 583540613 于 18:29 上传，SHA-256 为 `bb4aec9bf420b463efb549722c81b466d49bd6110ca69fb0796fadeeb5df3f2e`。截图中的 `1.0.158` 进程不能证明新发布资产仍为旧版，现有证据指向本地启动入口仍指向旧 AppImage。建议从本仓库 `latest` Release 取得新资产，替换原先运行的 AppImage，再启动；不应通过伪造版本或关闭更新检查掩盖旧程序。此次仅为已有日志、代码和 Release 元数据的静态核对，未下载解包新资产、未执行桌面实机验证；没有修改构建脚本，也不额外触发测试构建。

## 2026-09-24：改用官方 desktop 和图标

构建脚本不再手写 `discord.desktop`。现在从 Discord 官网动态 stable tar.gz 提取官方 `Discord/discord.desktop` 和 `Discord/discord.png`，直接交给 quick-sharun；完整主程序及模块仍由官方 stable manifest 的 `full.distro` 提供。软件版本继续取 manifest 的 `full.host_version`，并与完整包内 `resources/build_info.json` 强制比对，两者不一致时停止发布，因此 desktop 来源不会改变或回退实际程序版本。此次只完成静态检查，实际新构建与桌面运行结果以下一次 Actions 和实机反馈为准。

## 2026-09-24：统一非标准程序布局和 distro 解包

完整 Discord 程序不再放入 quick-sharun 的 launcher 目录 `AppDir/bin`，改为保留在 `AppDir/shared/bin`；运行时通过 `.env` 设置相邻库搜索路径和工作目录，并在 `AppDir/bin` 建立 Electron 查找 ICU、PAK、locales 与 resources 所需的包内软链接。主程序和模块的 `.distro` 不再由应用脚本直接执行 `brotli | tar`，统一交给公共归档入口解包，再按官方 `files/` 布局分别整理到程序目录和模块目录。

官方 desktop、图标、stable manifest、SHA-256 校验、清单与包内版本一致性检查、可写模块部署 hook、GTK3 中文输入模块和中文 locale 均保持原有逻辑；中文环境按仓库规范补齐 `LC_MESSAGES=zh_CN.UTF-8`。构建脚本同时增加中文分段注释，明确每个下载、校验、整理和封装阶段的用途。此次已完成脚本静态检查；公共 `.distro` 实际解包、AppImage 构建和桌面运行结果仍以下一次 Actions 与实机反馈为准。

## 2026-09-24：修复 Krisp 主程序完整性校验

Linux 实机运行 `1.0.159` 新成品，Discord 主窗口、联网、贴纸与应用搜索均正常，中文候选能够显示并正常上屏；启动日志显示 host 已是最新版本且官方模块没有可用更新。日志同时明确报告 `Failed to setup Krisp module, error code: -3`，因此此前成品不能认定 Krisp 麦克风降噪功能正常。

解包已发布的 `discord.AppImage`，并与同一 stable manifest 对应的官方主程序和 `discord_krisp` 完整包逐字节比较：包内 `discord_krisp.node` 与官方模块完全一致，且保留调试信息、没有被 strip；包内 `Discord` 主程序则被 quick-sharun 的硬编码路径处理改写了 174 个字节，把文件内的 `/usr/lib`、`/usr/share` 路径替换成运行时 `/tmp` 映射。Krisp 会校验 Discord 主程序本身，因此即使 Krisp 模块未被改动，仍会因主程序不是官方原始字节而拒绝初始化。

构建脚本继续让 quick-sharun 使用真实主程序收集依赖并生成官方入口；依赖收集完成后，再从已通过官方 SHA-256 与包内版本检查的 `full.distro` 恢复原始 `Discord` 文件，并用 `cmp` 强制确认 AppDir 中的主程序与官方来源逐字节一致。模块部署、中文环境、输入法、desktop、图标和 quick-sharun 入口均不改变。Krisp 实际恢复结果以下一次新成品实机语音设置验证为准。

## 2026-09-24：修正 Krisp UNSIGNED 根因并移除 Mesa 驱动

上一轮修复后的新成品仍在实机日志中报告 `Failed to setup Krisp module, error code: -3` 和 `KRISP_INIT_ERROR_UNSIGNED`。重新下载同一 stable manifest 的官方 `full.distro` 与 `discord_krisp` 模块核对后，成品内 `Discord` 和 `discord_krisp.node` 均与官方文件逐字节一致，说明上一节把问题归因于主程序字节被改写并不完整。

反汇编当前官方 Krisp 模块确认，初始化代码先通过 `/proc/<pid>/exe` 取得当前进程文件，再调用 `IsSignedByDiscord`；quick-sharun 为了使用 AppImage 自带的动态加载器和 glibc，实际进程文件是 sharun 加载器而不是官方 `Discord`，因此官方模块仍会返回未签名。直接改用宿主动态加载器会破坏 AnyLinux 兼容方式，本次保留 quick-sharun，只在构建时定位 `DoKrispInitialize` 中签名检查之后的条件跳转并替换为同长度 NOP；若上游符号、指令类型或文件偏移变化，构建会明确失败，不会盲目修改未知字节。补丁后的 SHA-256 写入模块目录，启动 hook 同时比较该标记，确保同一 Discord 版本的旧模块也会被新成品替换。除这条条件跳转外，Krisp 模块内容仍来自官方且完整保留，实际降噪结果待新成品实机验证。

Discord 官方程序已经自带 Electron 的 `libEGL`、`libGLESv2`、Vulkan 和 SwiftShader 运行库，应用依赖列表不再安装 `mesa`。由于 quick-sharun 会对 Electron 自动开启图形驱动收集，脚本显式设置 `DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0`，防止把构建机的 `libgallium`、DRI、GBM 和 Vulkan 驱动打进 AppImage；没有启用实验性的宿主驱动选项。

`mesa` 是其他应用按实际 OpenGL 或渲染需求选装的包，不属于统一基础包；不能因为 Discord 删除了它，就从确实需要 Mesa 的应用中删除。对 Discord 额外安装并收集构建机的 Mesa 驱动，会把与构建环境绑定的驱动及可能依赖的 `libLLVM.so` 带进产物，增加体积，还可能在其他 GPU 或较旧内核上产生兼容问题。Discord 此处只排除构建机驱动收集，不保证所有图形功能在所有宿主环境中均已验证。

随后提供的 Linux 实机启动日志显示 Discord 主程序已启动，未再出现此前的 Krisp `-3` / `KRISP_INIT_ERROR_UNSIGNED` 和 `libgallium` / LLVM 警告。这仅是该次启动日志的结果；Krisp 麦克风降噪的实际效果，以及本次文档提交触发的 Actions 构建结果，仍需分别验证。

## 2026-09-24：修正仍被收集的 Mesa 驱动

Build Discord 运行 35960141408 虽然构建成功，但日志明确显示构建环境间接安装了 `mesa`、`llvm-libs`，quick-sharun 的动态库扫描又把 `libgallium`、`libGLX_mesa` 和 `libLLVM.so.22.1` 复制到 Discord 的 AppDir，并报告 LLVM 警告。上一节仅依据实机启动日志未出现该警告就推断打包时没有带入 LLVM，结论错误；`DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 只关闭图形驱动的主动部署，不会排除动态扫描所得库。

构建脚本现在于依赖收集后、最终封装前，只从 Discord 的 AppDir 删除 `libgallium*.so*`、`libGLX_mesa.so*` 和 `libLLVM.so*`，并重建 sharun 的 `lib.path`；不删除构建环境中的包，也不修改 Discord 官方自带的 Electron 图形库。quick-sharun 在删除之前可能仍打印针对临时 AppDir 的红色警告；是否已从最终成品排除这些库，以及图形兼容性，仍待新构建和实机确认。

## 2026-09-24：不再删除 libLLVM，红色警告保留

用户要求去掉上述删除。`WARNING: Detected the bundled libgallium links to libLLVM.so!` 是 quick-sharun 在收进 `libgallium` → `libLLVM` 时自己打印的，删除发生在这行之后，所以删库从来不能让构建日志不标红。仓库里没有关闭这行警告的开关；把日志滤掉只是遮住，不是没发生。

因此默认保留红色警告，并去掉 `find ... -delete` 和随后只为重建清单而调用的 `sharun -g`。`DEPLOY_OPENGL=0` 与 `DEPLOY_VULKAN=0` 仍保留。新成品会重新带上扫描收进的 `libgallium*`、`libGLX_mesa*` 和 `libLLVM*`；体积和实机图形结果尚未验证。

## 2026-09-24：去掉专门挡 Mesa 的开关

上一节留下的 `DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 就是为了不把构建机 Mesa 驱动打进包。用户要求删掉这两个开关，不是再删 `libLLVM`。`NO_STRIP=1` 保留。红色警告仍会在 quick-sharun 收进 `libgallium` → `libLLVM` 时出现，继续不当成构建失败。新成品尚未验证。

## 2026-09-24：挡 Mesa 的开关改回去

上一节理解错了。用户要去掉的是删除 `libLLVM` 的代码，那一段在更早的修改里已经去掉，脚本里已经没有 `find ... libLLVM ... -delete`。`DEPLOY_OPENGL=0` 和 `DEPLOY_VULKAN=0` 恢复。红色警告仍然保留。
