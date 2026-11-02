# RealVNC Connect 与 linuxdeploy 标准的差异

## 标准链路

按根目录 [linuxdeploy 规范](../../linuxdeploy_projects.md) 和 [固定注释](../../docs/linuxdeploy-comments.md) 排列阶段，直接使用 Ubuntu 24.04。工具、官方来源解析、下载校验、安装解包、PNG 图标处理、最终封装及版本保存均复用现有公共脚本。

两次 linuxdeploy 分别用于空目录初始化和正式 GTK3 部署。自定义完整 AppRun 在第二次运行前写入根目录；hooks、AppRun.wrapped 和中间 AppImage 由官方工具自行生成，不手工创建或覆盖。

本次已检查仓库上游索引并检索 pkgforge-dev 的 realvnc / rvncconnect，未找到对应打包仓库，因此没有复用或暂存其专属代码，按本仓库标准及本项目原有兼容逻辑整理。

## 官方来源与实际路径

公共 DEB 入口使用 `--html-checksum --json-html article.body`，读取 `https://help.realvnc.com/api/v2/help_center/en-us/articles/27252822630301.json` 中同一篇官方 v8 校验文章的 HTML 表格，选择最新稳定版 `RealVNC-Connect-<版本>-Linux-x64.deb`，拼接官方下载地址并核对 SHA-256、包名与 amd64 架构。官方文章仍对应 v8 产品渠道，不是把应用锁定到某个具体版本。网页入口在本次 runner 请求中返回 HTTP 403，因此改用已实测可下载的公开 JSON 接口；字段缺失或表格无效即退出，不绕过摘要校验。故障与验证记录见 [README](../README.md#2026-11-02修正校验来源的-http-403)。

官方包的真实主程序为 `usr/lib/rvncconnect/rvncconnect`，私有库位于同级 `lib`，Flutter 资源位于同级 `data`。AppRun 直接执行真实主程序；不创建多余的 `usr/bin/rvncconnect` 转发入口。依赖搜索使用已核实的目录，不在每次启动时递归扫描 bundle。

`prepare_runtime.sh` 保存完整 bundle，整理主 desktop 的格式、图标名及启动参数，并暂存没有 Icon 的 URL handler desktop，避免 linuxdeploy 把辅助入口选成主入口。正式部署后由 `restore_runtime.sh` 恢复辅助 desktop。保留该文件不等于自动完成宿主机协议注册。

主 SVG 来自官方包，不自制图标；现有公共链路会为 appimagetool 准备有效 PNG `.DirIcon`。

## Flutter 与运行依赖

GTK3 库是官方 Flutter Linux 引擎的真实依赖，官方包目录没有列出系统 GTK 文件不代表程序不需要 GTK。应用 DEB 安装满足其声明的运行依赖；显式增加的开发包用于 GTK 插件查询元数据，Fcitx5/IBus 包用于 GTK3 输入模块，librsvg 用于 SVG 图标与 GTK 资源。原脚本未被当前 ELF 或插件需要的整套 C++/音频等开发包不再照搬。

linuxdeploy 会递归收集 `usr/lib` 中各个 ELF 的依赖，不逐个构造 `--executable` / `--library` 参数。`NO_STRIP=1` 保留 AOT 和私有库；部署时从保存的原始 `rvncconnect/lib` 解析私有库。部署结束恢复完整官方 bundle，避免 RPATH 改写破坏 Flutter 相邻资源定位。

恢复脚本保留原有 glibc、loader 及 GPU 库排除规则，恢复后的 vendor 目录不参与清理。GTK、输入模块和普通依赖继续保留。正式构建依赖基于 Ubuntu 24.04，不再承诺此前 Ubuntu 22.04 的 GLIBC 2.35 上限，不加入失效的旧基线断言。

## AppRun、输入与语言

默认保留 `APPIMAGE_GTK_THEME=Adwaita:dark`，同步设置 `GTK_THEME`，使官方 GTK hook 执行后的自定义入口仍采用原有深色默认值。用户显式指定主题时沿用该值。`GTK_IM_MODULE` 和 `XMODIFIERS` 继续允许宿主已有配置覆盖 Fcitx 默认值。

当前官方包尚未确认提供中文翻译，因此不调用中文 locale 准备脚本，也不强设 LANG/LANGUAGE；界面语言沿用宿主。GTK3 输入模块用于输入法，不能代替中文翻译或宿主输入法服务。

## 浏览器隔离的归属

隔离仅在 RealVNC 确认有需求，放在本项目 `patches/prepare_runtime.sh`，生成包内 `usr/bin/xdg-open`。根 AppRun 只保存宿主 PATH、XDG_DATA_DIRS 和 LD_LIBRARY_PATH；隔离入口负责移除官方 GTK hook 加入的共享数据前缀，恢复宿主路径并清除包内 GTK/GIO/Qt 等变量，再调用宿主 xdg-open。

**以后确认其他程序有相同需求，再考虑提取到公共脚本。** 当前不新增公共浏览器隔离接口，不改变其他应用。

## workflow 与验证结果

清单将 `realvnc_connect` 从 Arch 标准矩阵移为专用 job，保持原选择键、Release 资产名和版本元数据接口。专用 job 直接使用 Ubuntu 24.04；不新增手动触发、轮询或构建期 GUI 测试。

前期已用官方 DEB 检查资源与辅助入口、恢复逻辑、AppRun 环境及参数，并验证 YAML、清单和任务选择。[Actions 运行 41398751168](https://github.com/newyorkthink/linux-packaging/actions/runs/41398751168) 随后完成了实际构建、发布和版本元数据写入。

用户已实测启动、界面显示、深色主题、中文输入和连接正常，本轮验收通过。此前 `resetSettings` 引起的 `MissingPluginException` 经用户确认不影响实际使用，不再作为待修复或验收阻塞项；现有脚本和专属处理作为已验证基线保留。
