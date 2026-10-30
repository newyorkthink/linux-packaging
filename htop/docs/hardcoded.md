# htop 固定配置依据

本文件回答当前固定输入为什么这样写、具体值是什么、有什么作用，以及可核实的来源是什么。当前内容来自 Arch 包布局、本仓库标准输出和已有打包输入；没有提供原始故障日志的事项如实说明，不补造报错。模板差异见 [template-deviations.md](./template-deviations.md)，官方取舍见 [pkgforge-differences.md](./pkgforge-differences.md)。

## 当前固定输入

| 配置 | 固定取值与用途 | 依据与原始记录 |
| --- | --- | --- |
| 系统包与主入口 | `htop`、`/usr/bin/htop`。安装官方二进制后直接收集真实程序，不预复制主程序。 | [Arch 官方包](https://archlinux.org/packages/extra/x86_64/htop/) 与 [文件表](https://archlinux.org/packages/extra/x86_64/htop/files/)；本仓库原有入口。 |
| 应用级依赖 | `htop ncurses libcap libnl lm_sensors lsof strace`。保留基础包没有显式列出的 7 项原依赖。 | [重写前脚本](https://github.com/newyorkthink/linux-packaging/blob/c32d1e811cb2483a728027bf62732c64e302ff51/htop/build_htop.sh) 的应用安装行；另外 10 项由未修改的 --base 覆盖，映射见模板差异。 |
| 图标 | `/usr/share/icons/hicolor/scalable/apps/htop.svg`。使用已安装的官方 SVG。 | Arch 文件表提供该文件；保留仓库原值，不因 pkgforge 使用 PNG 改换图标。 |
| desktop | `/usr/share/applications/htop.desktop`。供 quick-sharun 收集桌面入口。 | 同一 Arch 包提供；不另外改写 Exec、Icon 或终端属性。 |
| 主程序名 | `MAIN_BIN=htop`。多个可执行输入中明确选择 htop 为入口。 | 继承原脚本已设置的值；不是新增一个启动 wrapper。 |
| 可选功能命令 | `/usr/bin/lsof`、`/usr/bin/strace`。分别支持 Open Files、Trace。 | 原脚本已有输入；[htop 手册](https://man.archlinux.org/man/htop.1.en) 说明其用途。是否能读取或跟踪特定进程仍受运行权限约束。 |
| 动态加载库 | `/usr/lib/libsensors.so*`、`/usr/lib/libnl-3.so*`、`/usr/lib/libnl-genl-3.so*`。显式收集温度和延迟统计库。 | 原脚本既有精确前缀；htop 手册明确这些库经运行时动态加载。通配符只覆盖这三组库，不复制整个 /usr/lib。 |
| 架构 | ARCH 通过 `uname -m` 获取，现有标准 workflow 的正式构建为 x86_64。 | 继承当前 Arch matrix；未新增其他架构产物或架构判断。 |
| 版本 | 公共读取入口参数 `pacman htop`。读取本次实际安装版本并去掉 epoch、pkgrel。 | 沿用原软件包元数据来源，不锁定版本号；最终非空 AppImage 生成后才写版本文件。 |
| 输出 | `dist/htop.AppImage`、`dist/version.txt`；OUTPATH 从 SCRIPT_DIR 生成。 | 现有应用清单的 `htop` 项及统一版本接口；不写入用户主机路径。 |
| 清理范围 | 当前脚本目录的 `AppDir`、`dist`。 | 经批准的原生模板；脚本先定位并切到自身目录，清理只在临时构建环境中执行，不进入成品启动逻辑。 |

## 原有基线与故障记录边界

重写前源码明确列出了以下基线说明，现原样保存以便追溯：

```bash
# 稳定基线说明：
# - 使用 Arch Linux Extra 官方 htop 软件包。
# - 使用 quick-sharun 打包，不使用 linuxdeploy。
# - 保留 Arch 官方 htop.desktop 和 htop.svg。
# - 显式封装 htop 运行时动态加载的 libsensors、libnl。
# - 同时封装 Arch 官方列出的 lsof、strace 可选功能。
```

原有依赖收集命令保持原样：

```bash
# 收集程序及其运行依赖。
quick-sharun /usr/bin/htop /usr/bin/lsof /usr/bin/strace /usr/lib/libsensors.so* /usr/lib/libnl-3.so* /usr/lib/libnl-genl-3.so*
```

上面的调用采用当前统一注释；原命令的参数和顺序未改。原始注释及完整上下文可从 [重写前脚本](https://github.com/newyorkthink/linux-packaging/blob/c32d1e811cb2483a728027bf62732c64e302ff51/htop/build_htop.sh) 查阅。

现有材料没有提供这些配置对应的完整原始运行日志或故障输出；不把源码注释当成实机成功证明，也不推测当初发生过什么错误。配置作用以已读手册、包文件表和原脚本为依据，本次只完成静态检查。后续若有实际故障记录，按原始内容追加，不覆盖已有历史。
