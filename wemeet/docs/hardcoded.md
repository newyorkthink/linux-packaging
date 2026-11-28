# 腾讯会议固定配置

| 配置 | 用途与依据 |
| --- | --- |
| 官网 JSON 的 Linux x86_64 DEB，channel `0300000000` | 使用[构建脚本中的固定请求参数](../build_wemeet.sh#L34)动态选择官方发布版本。包名为 `wemeet`，架构为 `amd64`。 |
| `/usr/lib/qt5/bin/qmake` | 让 linuxdeploy Qt 插件查询实际 Qt5 工具。[插件直接使用 `QMAKE`](https://github.com/linuxdeploy/linuxdeploy-plugin-qt/blob/9b9fca179e7312ae4a433ad6c3183d73c116180b/src/util.cpp#L59-L77)，因此无需 `QT_SELECT`。 |
| `TZ=Asia/Shanghai`、包内 `zh_CN.UTF-8` | 沿用官方时区，保留可用时的中文 locale 和回退逻辑。 |
| Wayland 下的 XWayland 回退 | 保留已有会话脚本路径和 XCB 回退，实际程序由根 AppRun 启动。 |
| `NO_STRIP=1` | 沿用官方程序与私有库的既有部署设置。 |
| `wemeet.AppImage` | 固定发布资产名，版本由本次校验的 DEB 元数据确定。 |
