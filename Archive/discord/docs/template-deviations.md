# Discord 模板差异说明

## 当前标准与实际问题

[build_discord.sh](../build_discord.sh) 仍由固定 [LinuxDeploy GTK DEB 模板](../../../templates/appimage/linuxdeploy-gtk-deb.sh)完整生成，保留 Ubuntu 22.04、GTK3、内联 AppRun 和公共最终封装。生成运行 [42789334037](https://github.com/newyorkthink/linux-packaging/actions/runs/42789334037) 来自提交 `c0ed3c55b4756077ccdc144776fee56b66cca875`，输出 SHA-256 为 `6ac3053d1e823813d2fd37161cb8a518156b4f94c1645335dee7a07b31dd1723`；正式脚本与该输出逐字一致。

上一轮运行 [42784000043](https://github.com/newyorkthink/linux-packaging/actions/runs/42784000043) 只取得 2331 KiB 的官方引导 DEB，未包含完整客户端，生成入口还指向不存在的 `usr/share/discord/Discord`。用户启动成品后报 `No such file or directory`。因此本次恢复有直接证据支持的完整来源与模块准备，不把旧 quick 流程整体搬回。

## 固定标准与专属阶段

| 位置 | 本次处理 | 依据与影响 |
| --- | --- | --- |
| 原 DEB 来源阶段 | 保留公共 `--url` 下载、安装及解包 | 取得构建环境依赖、官方 desktop 和图标，不能把其引导器当完整客户端。 |
| `APPLICATION_PREPARE` | 调用 `patches/prepare_application.sh prepare` | 从同次 stable 清单下载完整主程序及全部模块，逐份核对官方 SHA-256，返回完整程序实际版本。 |
| 程序与模块布局 | `usr/lib/discord`、`usr/share/discord-modules` | 完整主程序参与递归扫描；模块模板保持官方原文件，动态加载的已确认运行库显式收集。 |
| `APPRUN_PREPARE` | 调用包内 `usr/lib/discord/prepare_modules.sh` | 按 1.0.169 实机日志把模块放入用户可写的 `discord/module_data`，不以 `newUpdater` 推断目录。 |
| `APPLICATION_FINALIZE` | 调用 `patches/prepare_application.sh finalize` | 依赖部署后从本次已校验来源恢复官方主程序并逐字节比较；模块模板未交给 ELF 改写。 |
| 原最终封装 | 继续调用 `common/linuxdeploy/package_appimage.sh` | 处理正式 AppImage、产物权限、SHA-256 和实际版本保存，发布路径不变。 |

## 参数与版本

`APP_BIN_DIR`、`APP_LIB_DIR` 为 `usr/lib/discord`，`MAIN_EXECUTABLE` 为 `usr/lib/discord/Discord`；`GIO_MODULE_DIR` 仍是 Ubuntu amd64 的 `usr/lib/x86_64-linux-gnu/gio/modules`。新增依赖提供 `jq`、Brotli、C++ 运行库及完整 Electron 程序需要的运行库，原 GTK 标准依赖保持原顺序。动态加载库按旧版已确认的明确列表收集，并补入完整模块需要的 `libc++.so.1`；依赖收集交给 linuxdeploy，NSS/NSPR 由现有公共入口统一准备。

引导 DEB 的临时版本由来源阶段取得；完整准备阶段用 `common/build/read_app_version.sh package-json` 读取真实 `build_info.json`，并与清单 `full.host_version` 数组还原的版本比较，最终 `version.txt` 使用该完整版本。

## 恢复范围与旧版保留

完整主程序、官方模块、版本比对和可写复制取自 [build_discord_old.sh](../build_discord_old.sh) 中直接对应本次故障的部分。新布局适配 LinuxDeploy，运行准备是普通脚本调用，不手写或注入 `apprun-hooks`，不伪造 `AppRun.wrapped`。模块按来源标记更新，已有模块自身升级不会仅因 `installed.json` 改变而被覆盖。

旧 quick 的 Krisp JE/NOP 补丁、额外图形开关、locale、专属输入模块扫描和加载器布局不恢复。主程序与模块使用官方原文件；旧备份保留且不参与任何 Action。

生成器已检查正式主脚本和内联 AppRun 的 Bash 语法；helper 已作静态核对，本次未作桌面运行验证。历史和实际错误见 [README](../README.md)。

## module_data 实机反馈修正

用户提供的 1.0.169 日志同时包含 `newUpdater:false`、`modulepath: <用户配置目录>/discord/module_data` 和 `Cannot find module 'discord_desktop_core'`，反驳了此前仅凭开关推断版本目录的处理。当前 helper 按实际记录部署到 `module_data`，原包内版本标记和来源摘要继续用于识别本次完整分发。

仅替换包内提供的模块子目录并同步 `installed.json`，保留根目录其他数据。正式构建脚本与三个标准阶段调用均未改动，无需重新生成主脚本。
