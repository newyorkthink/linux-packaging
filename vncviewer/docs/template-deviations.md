# RealVNC Viewer 专属差异

## desktop 兼容处理

- **位置：** `build_vncviewer.sh` 的「准备桌面资源和运行库」阶段，安装包解包后、linuxdeploy 运行前。
- **故障依据：** [GitHub Actions Job 128770404168](https://github.com/newyorkthink/linux-packaging/actions/runs/42492346252/job/128770404168)。appimagetool 对官方 DEB 提供的桌面入口报错：`[NewConnection Shortcut Group]` 不符合扩展分组命名规则，另有废弃的 `Encoding` 和 `Application` 分类警告；最终退出码为 1。
- **处理内容：** 保留现有 `Exec=vncviewer` 和 `Icon=vncviewer48x48` 命令，在其后只对 `realvnc-vncviewer.desktop` 副本移除 `Encoding`，删除 `Categories` 中的 `Application;`，把 `X-Ayatana-Desktop-Shortcuts=NewConnection` 改为 `Actions=NewConnection;`，把 `[NewConnection Shortcut Group]` 改为 `[Desktop Action NewConnection]`，并删除 `TargetEnvironment=Unity`。
- **影响：** 保留新建连接快捷方式的名称和启动命令，适配现代桌面入口规范；不改动原始 DEB、公共下载脚本、依赖部署、AppRun、打包工具及其他应用。

本处理仅针对本应用旧版 DEB 的桌面资源，不加入公共模板。
