# Falkon 模板差异

本项目沿用 Arch 官方仓库二进制包和 quick-sharun 路线。公共结构、固定注释与执行顺序以 [qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh) 和 [Qt 程序规范](../../anylinux_projects.md#有窗口的-qt-程序) 为底稿，只保留以下经批准的应用专属差异。具体固定取值与原始报错依据见 [hardcoded.md](./hardcoded.md)。

## 上游来源核实

2026-11-26 按 `falkon` 和曾用名 `qupzilla` 复核 `pkgforge-dev` 组织，未查到对应的上游打包仓库，因此不创建 `pkgforge-differences.md`。主程序继续使用 Arch 官方 Extra 仓库的原生二进制包 `falkon`（入口 `/usr/bin/falkon`），不使用源码包。

## 相对标准模板的差异

| 所在阶段 | 相对 `qt-installed.sh` 的变化 | 位置与原因 |
| --- | --- | --- |
| 依赖安装 | 在单行安装命令末尾追加 `breeze-icons`，原有 `falkon`、`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin` 保持不变。 | [build_falkon.sh 第 13 行](../build_falkon.sh#L13)。为包内补充深色图标主题来源。 |
| 语言环境 | 删除模板第 38–46 行生成 `zh_CN.utf8` locale 及向 `AppDir/.env` 写入 `LANG`、`LANGUAGE`、`LC_MESSAGES`、`LOCPATH` 的代码块，保留 `fcitx5-qt` 输入模块。 | 避免浏览器向对地区或风控敏感的站点固定暴露中文区域特征（`Accept-Language`、`navigator.language`、`Intl` 等），防止在英文或海外环境触发地区误判；改为跟随宿主机系统语言。后续同步或维护模板时不得为此重新加回固定中文 locale。 |
| 图标与深色主题 | 在 `quick-sharun /usr/bin/falkon` 后补入 `/usr/share/icons/breeze-dark`，并基于官方 `/usr/share/falkon/themes/linux` 叠加仓库静态资源生成 `dark-slate`（Dark Slate）和 `oled-black`（OLED Black）两套主题写入 `AppDir/share/falkon/themes/`。 | [build_falkon.sh 第 38–51 行](../build_falkon.sh#L38-L51)。让未配置 `qt6ct` 的机器也能在“首选项 → 外观”直接切换到深色主题，不修改用户主目录配置。 |
| 运行时启动 hook | 在最终封装前写入 `AppDir/bin/90-falkon-runtime.hook`：外部未指定 `QT_QPA_PLATFORMTHEME` 时默认设为 `qt6ct`；仅 `root` 且外部未指定时设为 `QTWEBENGINE_DISABLE_SANDBOX=1`；仅无可读可写 `/dev/dri/renderD*` 且外部未指定时设为 `QTWEBENGINE_CHROMIUM_FLAGS='--disable-gpu --use-gl=disabled'`。 | [build_falkon.sh 第 53–83 行](../build_falkon.sh#L53-L83)。让已配置 `qt6ct` 的环境直接加载深色外框，同时自动处理无 GPU 远程桌面与 `root` 启动报错；普通用户及带可用显卡的桌面环境不受影响，外部显式传入同名变量时优先生效。 |

## 未改动部分

脚本初始化、公共基础包安装、工作区准备、`ARCH`/`ICON`/`DESKTOP`/`OUTPATH`/`OUTNAME`/`DEPLOY_QT` 元数据、公共版本读取、`quick-sharun /usr/bin/falkon`、最终封装与公共版本保存均保持 [qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh) 原样。

实机通过记录见 [README 实机验证](../README.md#实机验证)。
