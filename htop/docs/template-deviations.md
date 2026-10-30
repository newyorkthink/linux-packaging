# htop 模板差异

本文件说明 [build_htop.sh](../build_htop.sh) 相对 [Arch 官方仓库原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 的实际差异。固定输入见 [hardcoded.md](./hardcoded.md)，pkgforge 原文及未启用项见 [pkgforge-differences.md](./pkgforge-differences.md)。这些说明不参与打包，也不授权后续自动加入功能。

## 基础结构

脚本共 42 行。40 行原生系统入口基础模板之外，仅保留原有 MAIN_BIN 的两行；其余差别是模板允许替换的包名、路径、输出名、版本包名和已确认运行输入。通用注释、代码顺序、缩进和空行均按模板保留。

主程序来自 Arch 官方仓库，直接收集 `/usr/bin/htop`，不增加独立 DEB / tar 下载、解包或主程序复制阶段。htop 是终端程序，不添加 GUI locale、GTK / Qt 输入模块、窗口 hook 或自写 AppRun。

## 原有依赖全部保留

重写前共 17 个不同依赖名：`gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync htop ncurses libcap libnl lm_sensors lsof strace`。

| 负责安装的入口 | 保留的原依赖 |
| --- | --- |
| `common/arch/install_packages.sh --base` | gcc、base-devel、wget、binutils、patchelf、coreutils、appstream-glib、desktop-file-utils、util-linux、zsync，共 10 项。 |
| 应用级安装行 | htop、ncurses、libcap、libnl、lm_sensors、lsof、strace，共 7 项。 |

[build_htop.sh 第 12 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L12)：

```bash
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" htop ncurses libcap libnl lm_sensors lsof strace
```

只合并到公共安装接口，不删减原有包；统一基础包及公共安装实现没有修改。

## 保留的主程序元数据

原脚本已经显式设置 MAIN_BIN，当前继续保留在 OUTNAME 之后、读取版本之前。[build_htop.sh 第 29 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L29)：

```bash
# 包里的真实程序名。
export MAIN_BIN=htop
```

同一次收集包含三个可执行程序，继续明确指定 htop 为启动入口。这不是为了凑齐 Electron 元数据，也不需要额外加入 APPNAME、STARTUPWMCLASS 或 DEPLOY_GTK。该通用注释沿用现有 MAIN_BIN 标准表述。

## 保留的辅助程序与动态库输入

[build_htop.sh 第 35 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L35)：

```bash
# 收集程序及其运行依赖。
quick-sharun /usr/bin/htop /usr/bin/lsof /usr/bin/strace /usr/lib/libsensors.so* /usr/lib/libnl-3.so* /usr/lib/libnl-genl-3.so*
```

整条可执行命令、参数、通配符和顺序与重写前一致；上方注释使用原生模板的固定表述。这里不是 pkgforge 单入口命令的原样复用，而是本仓库既有收集方式：

| 输入 | 用途及依据 |
| --- | --- |
| `/usr/bin/htop` | Arch 包提供的真实主程序。 |
| `/usr/bin/lsof` | htop 的 Open Files 功能调用的外部命令。 |
| `/usr/bin/strace` | htop 的 Trace 功能调用的外部命令。 |
| `/usr/lib/libsensors.so*` | htop 通过动态加载读取温度的库。 |
| `/usr/lib/libnl-3.so*`、`/usr/lib/libnl-genl-3.so*` | htop 通过动态加载取得延迟统计数据的库。 |

作用依据为 [htop 手册的快捷键及外部库说明](https://man.archlinux.org/man/htop.1.en)。动态加载库和外部程序继续显式交给 quick-sharun；不据此声称所有目标环境的可选功能已经实测。

## 未启用项与维护边界

pkgforge 的源码静态构建、UPINFO、PNG 图标选择及正式构建中的 simple-test 均未启用；对应原文、官方原因和当前决定见 [pkgforge-differences.md](./pkgforge-differences.md)。当前 SVG、desktop、MAIN_BIN 和额外输入均有本仓库既有依据，不能为套用官方单入口例子将其删掉。

后续拟加入未启用处理时，先核实该处理的官方当前源码是否仍存在及是否适用，再按当次授权处理。当前静态检查和正式构建、实机验证的边界见 [README](../README.md#维护文档与验证范围)。
