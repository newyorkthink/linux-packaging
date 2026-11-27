# Rainlendar2 模板差异

使用 [GTK DEB 模板](../../Templates/appimage/linuxdeploy-gtk-deb.sh)。构建在原生 Ubuntu 24.04 x86_64 独立 Job 执行，复用仓库的 AppImage 发布和版本清单入口。

| 阶段 | 处理与依据 |
| --- | --- |
| 程序来源 | 官方 GitHub 最新正式 Release 的 Pro amd64 DEB。上游标签只含版本，资产名另含构建号和 Debian 修订号。公共入口匹配唯一资产，并绑定下载地址、SHA-256 和资产 ID。`dist/version.txt` 保留 Release 标签版本。 |
| 资源准备 | `patches/prepare_appimage.sh` 在解包后整理官方桌面入口，保留官方 PNG。提前放入 GTK3 IBus 模块和 libcanberra Pulse 驱动，由 linuxdeploy 扫描主程序及动态加载库的依赖。 |
| AppRun | 旧成品的 AppRun 和包内文件确认应用库位于 `usr/lib/rainlendar2` 及 `usr/lib`。保留原有路径优先级与宿主路径回退。GTK3 使用包内 IBus 模块连接宿主输入法，并为当前挂载路径生成缓存。延续旧版 X11、Adwaita 深色主题和 Pulse 后端。启动工作目录为 `usr/lib/rainlendar2`，用于解析相对路径 `resources/alarm.wav`。 |
| 依赖部署与收尾 | Ubuntu 24.04 的 GTK3 输入法模块索引工具位于 `libgtk-3-0t64` 的架构库目录，构建时加入 `PATH` 供插件使用。`NO_STRIP=1` 保留 GetPath 修复需要的二进制符号。依赖部署后，`patches/prepare_appimage.sh` 清理与 Rainlendar2 冲突的 Fcitx GTK 模块，并将 libcanberra 的绝对驱动路径改为由包内库目录查找。`patches/patch_rainlendar_getpath.py` 沿用旧脚本的并发修复，对已识别的共享 `wxString` 返回结构应用补丁并校验。无法识别布局时构建失败。 |
| 封装与发布 | 保留 linuxdeploy 生成的 GTK hook 和启动包装层。官方 appimagetool 使用 Type 2 runtime 输出 `rainlendar2.AppImage`，发布后由同一 Job 即时更新 `rainlendar2` 版本条目。 |

旧版曾为默认铃声和同步线程加入专属兼容处理，源码保留了对应的触发条件和补丁边界。[旧版 AppRun 与铃声处理](https://github.com/newyorkthink/linux-packaging/blob/f0490b8/rainlendar2/build_rainlendar2.sh#L189-L328) · [GetPath 修复依据及原补丁](https://github.com/newyorkthink/linux-packaging/blob/f0490b8/rainlendar2/build_rainlendar2.sh#L330-L545)

实测结果见[应用 README 的实机验证记录](../README.md#实机验证)。
