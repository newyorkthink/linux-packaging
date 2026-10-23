# KeePassXC AppImage

## 用途与产物

本目录将 Arch 当前 KeePassXC 打包为 `keepassxc.AppImage`，并同时保留 CLI、proxy、X11 剪贴板和自动输入相关运行组件。

## 技术栈与打包方式

KeePassXC 为 C++ 桌面应用，自 2.8.0 起使用 Qt6。构建脚本安装 Arch `keepassxc` 及 Qt6/X11/Fcitx5 相关依赖，通过 quick-sharun 生成 AppImage。实际打包版本以 Arch 仓库提供的 `keepassxc` 包为准。

## 界面语言与资源

应用翻译位于 `AppDir/share/keepassxc/translations/`。真实程序位于 `AppDir/shared/bin/`，构建时增加 `AppDir/shared/share -> ../share`，让当前 Qt6 按真实程序路径查找时也能访问同一份翻译、词表等数据。

包内生成 `AppDir/lib/locale/zh_CN.utf8`，并在 quick-sharun 已有 `.env` 后追加 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8` 和 `LOCPATH=${SHARUN_DIR}/lib/locale`。这样“系统默认”可使用简体中文，不要求宿主预先生成中文 locale；用户在 KeePassXC 中明确选择的界面语言仍由上游配置处理。不设置 `LC_ALL`。

资源路径决定能否找到翻译，中文环境决定默认选择哪种语言，两者作用不同。原理、旧版差异和适用边界见 [quick-sharun 与 Qt6 资源路径案例](../docs/packaging-cases/quick-sharun-qt6-resources.md)。

## 版本元数据

构建时从本次实际安装的 `keepassxc` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=keepassxc` 接入统一版本清单。

## 运行

```bash
./keepassxc.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据输出和发布清单接入，不改变现有 Qt5、剪贴板、自动输入或 Fcitx5 打包逻辑。

### 2026-10-23：修正 Qt6 资源路径并补齐默认中文环境

现象是 KeePassXC 2.8.0 界面没有中文、语言选择只剩系统默认；用户确认中文输入正常。核对实际产物发现中文 `.qm` 已打包，不能归因于缺翻译或输入法。旧版 2.7.12 / Qt 5.15.19 与故障包 2.8.0 / Qt 6.12.0 的 `.env` 相同，均没有 `shared/share` 链接。

sharun 启动后，Qt5 使用 `/proc/<pid>/exe` 得到 `AppDir/bin/keepassxc`；本次 Qt6 使用 `AT_EXECFN` 得到 `AppDir/shared/bin/keepassxc`。KeePassXC 据此查找 `../share/keepassxc`，新版路径缺失后回退到顶层 `share`，随后误找 `share/translations`。这里的旧版路径是 `bin`，不是动态加载器所在的 `lib`。

本次只在首次 quick-sharun 后、最终封装前增加资源链接，并按仓库 GUI 规则生成中文 locale、追加上述四项 `.env` 配置。已有 `.env` 内容、Qt6/Fcitx5 依赖、输入法选择、剪贴板、自动输入、CLI/proxy、quick-sharun 参数和版本元数据流程均保留。

检查：`bash -n`、完整 diff 和文档链接核对通过。云端隔离临时副本使用 offscreen 平台启动，不打开数据库；文件访问记录显示旧 Qt5 包成功打开 `keepassxc_zh_CN.qm`，故障 Qt6 包查错目录，修复副本成功打开该文件；修复副本选择“系统默认”时也成功打开中文翻译。资源链接可访问全部 48 个应用翻译文件，原 `.env` 内容保留。临时跟踪方法和验证边界见专项案例，测试代码与日志不入仓库。

以上是已有产物的临时对照检查，不是新 AppImage 的构建或实机验收。未监控本次提交触发的 Actions，新构建及桌面交互结果未验证。
