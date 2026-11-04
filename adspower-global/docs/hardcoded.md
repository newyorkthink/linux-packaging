# 固定构建参数与依据

## 固定内容及作用

下列值属于本次已确认的生成器参数。应用版本、下载地址及摘要由 AUR 当前元数据动态取得，不固定旧版本或旧校验值。

| 参数 | 固定内容 | 依据、用途与影响 |
| --- | --- | --- |
| AUR 包 | `adspower-global-bin` | 本次指定的包名，用于动态读取来源、安装应用及其声明的运行依赖。 |
| DEB 源文件名 | `AdsPower-Global-{version}-x64.deb` | 与 AUR 来源别名对应，`{version}` 由公共入口按同次元数据展开，用于选中 x86_64 官方 DEB。 |
| 解包程序目录 | `opt/AdsPower Global` | AUR 配方直接解包官方 DEB，并以 `/opt/AdsPower Global/adspower_global` 为真实入口；完整复制程序及相邻资源。 |
| 主程序与窗口标识 | `adspower_global`、`AdsPower Global` | 沿用官方程序入口和既有窗口标识，供 quick-sharun 生成启动入口及桌面资源。 |
| desktop | `/usr/share/applications/adspower_global.desktop` | AUR 配方保留该 desktop 路径，并调整其中的 Exec；正式脚本读取安装结果。 |
| 图标 | `/usr/share/icons/hicolor/256x256/apps/adspower_global.png` | 按获批生成稿选择 hicolor 中的同名图标；旧脚本按尺寸查找同名资源，本稿使用模板参数指定路径。 |
| 成品名 | `adspower-global.AppImage` | 保持既有构建清单与 Release 资产名称一致。 |
| 扫描目标 | `AppDir/bin/*`、`/usr/bin/xdg-open`、`/usr/bin/xdg-mime` | 保留完整程序目录的收集范围，并沿用仓库 Keyviz 的方式显式收集外部打开和 MIME 查询工具；`xdg-utils` 已由公共基础依赖安装。 |

AUR 配方依据为 [PKGBUILD](https://github.com/archlinux/aur/blob/071f26a3236e92008e0ecbd51f8cb588d29e38ef/PKGBUILD) 和 [.SRCINFO](https://github.com/archlinux/aur/blob/071f26a3236e92008e0ecbd51f8cb588d29e38ef/.SRCINFO)。

## 采用当前来源的原始故障记录

旧构建任务 [126701888873](https://github.com/newyorkthink/linux-packaging/actions/runs/41866452596/job/126701888873) 在地址解析阶段输出：

```text
Error: failed to resolve the current AdsPower Linux x64 package URL.
Error: Process completed with exit code 1.
```

官网页面中的 Linux DEB 已使用 `version-v2.adspower.net`，旧脚本的匹配和地址校验只允许 `version.adspower.net`。本次改用 AUR 配方中的官方来源和摘要，相关下载行为由已有公共入口处理。

上述原始报错对应旧下载解析失败。其他固定值是已批准的模板参数，并非声称由该次报错逐项证明；旧版 ICU、资源布局与输入法问题的原始记录继续保留在 [README](../README.md) 及 [旧版脚本](../build_adspower-global_old.sh)。
