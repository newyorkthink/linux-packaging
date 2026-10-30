# htop AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `htop` 软件包，通过 quick-sharun 生成 `htop.AppImage`。现有打包逻辑同时包含 `lsof`、`strace` 以及 htop 运行时需要的 libsensors / libnl 组件。

正式构建由 [Build AppImages](../.github/workflows/build.yml) 按 [应用清单](../.github/appimage-apps.json) 的标准 Arch matrix 执行，显示为 `Build htop`，最终资产固定发布为 `htop.AppImage`。

## 技术栈与打包方式

htop 是基于 ncurses 的终端进程查看器，当前正式构建为 x86_64。按 [Arch 官方仓库原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 使用 [Arch 官方 htop 二进制包](https://archlinux.org/packages/extra/x86_64/htop/)，不在本目录编译主程序，也不预先将主程序复制到 AppDir/bin。

1. 公共入口安装基础包，再安装 htop、ncurses、libcap、libnl、lm_sensors、lsof 和 strace；原有 17 项依赖全部由基础包或应用安装行保留。
2. 图标和 desktop 读取已安装包提供的 `htop.svg`、`htop.desktop`；保留 `MAIN_BIN=htop` 明确指定主程序。
3. 一次 quick-sharun 调用收集 htop、lsof、strace，以及原有 libsensors、libnl-3、libnl-genl-3 通配路径，整条调用的输入和顺序保持不变。
4. quick-sharun 生成 AppRun，并最终封装为 `dist/htop.AppImage`。本目录不另写启动 wrapper、locale 或输入法配置。

lsof 对应 htop 的 Open Files 功能，strace 对应 Trace 功能；libsensors 用于温度读取，libnl-3 / libnl-genl-3 用于延迟统计，后两类库由 htop 在运行时动态加载。作用依据见 [htop 手册](https://man.archlinux.org/man/htop.1.en)，本次保留原有收集方式，不把这些可选功能添加到其他应用。

已核实 [pkgforge-dev/htop-AppImage 的固定源码](https://github.com/pkgforge-dev/htop-AppImage/tree/138bc266d885f0ac987921a99417aa1278169b76)。它自行编译 ncurses、libsensors 和 htop，并使用静态构建选项；本仓库继续使用 Arch 官方二进制。官方 UPINFO、PNG 图标选择、源码构建和构建后的 simple-test 均未照搬，当前采用自己的标准流程和既有 SVG。官方原文及逐项依据见 [pkgforge 取舍](./docs/pkgforge-differences.md)。

## 版本元数据

第一次 quick-sharun 之前，通过 `common/build/read_app_version.sh pacman htop` 读取当前实际安装的 Arch htop 版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel。最终 AppImage 成功生成后，单行调用 `common/build/save_appimage_version.sh`，由公共入口确认产物非空后写入：

```text
htop/dist/version.txt
```

该文件由 workflow 上传为 `software-version-htop`，成功构建后由当前 `Build htop` Job 立即写入 `latest` Release 中的 `software_versions.json`。

## 维护说明

- 保持 Arch 官方 `htop.desktop` 与 `htop.svg`。
- 保持现有 quick-sharun 依赖收集逻辑，不因版本元数据接入改动运行依赖。
- 版本值必须来自本次实际安装的软件包，不手工写死。

## 维护文档与验证范围

| 文档 | 用途 |
| --- | --- |
| [固定配置依据](./docs/hardcoded.md) | 说明软件包、系统路径、主程序名及输出约定的取值和来源。 |
| [模板差异](./docs/template-deviations.md) | 说明基础模板之外保留 MAIN_BIN 和辅助程序、动态库输入的原因。 |
| [pkgforge 取舍](./docs/pkgforge-differences.md) | 保存官方源码、作用、采用与未采用决定；后续加入前先核实当前官方是否仍保留且适用。 |

本次完成 Shell 语法、原有依赖覆盖、模板注释与空行、文档链接及源码原文的静态检查；没有在本次任务执行正式打包或实机运行。Open Files、Trace、温度及延迟统计的实际可用性仍取决于运行环境、内核支持、权限和配置，不能仅凭打包输入存在就写成实测通过。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 构建成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=htop` 与统一 `software_versions.json`。
- 移除原构建脚本末尾用于验证运行结果的 AppImage `--version` 调用；版本改从本次实际安装的软件包元数据取得。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-10-30：按原生系统入口标准整理

按本次批准的 42 行草稿统一严格模式、脚本目录、通用注释和空行。开始构建时仅清理当前脚本目录的 AppDir、dist；安装、版本读取和版本保存改用现有公共入口。原有 17 项依赖、MAIN_BIN=htop，以及收集 htop、lsof、strace、libsensors 和 libnl 的完整调用均保留；原有产物非空检查由公共保存入口承担，不再在应用脚本重复。

本次继续使用 Arch 官方二进制，不照搬 pkgforge-dev 的源码静态构建、UPINFO 和 simple-test。同步补齐三份 docs，并在 quick 标准和原生系统入口分类登记本次已完成的标准化。既有 2026-09-16 记录完整保留；本次结果限于上述静态检查，正式构建与实机功能未在本次核实。
