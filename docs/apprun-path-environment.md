# AppRun 路径型环境变量说明

这份文档说明 AppImage / linuxdeploy 中常见路径型环境变量的用途，以及仓库公共路径整理脚本的边界。目录不是越多越好；每个变量只应包含与自身用途匹配的目录。

| 变量 | 用途 | 常见 AppDir 目录 |
| --- | --- | --- |
| `PATH` | 查找可执行程序 | `usr/bin`、`usr/libexec`、`bin`、`opt/<应用>` 中真实入口所在目录 |
| `LD_LIBRARY_PATH` | 查找 ELF `.so` 动态库 | `usr/lib`、`usr/lib64`、multiarch lib、`opt/<应用>/lib` |
| `XDG_DATA_DIRS` | 查找共享数据、desktop、icons、schemas 等 | `usr/share`、`share`、`opt/<应用>/share` |
| `QT_PLUGIN_PATH` | Qt plugin 根目录 | `usr/plugins`、Qt 安装的 `plugins` 根目录、应用自带 Qt plugin 根目录 |
| `QT_QPA_PLATFORM_PLUGIN_PATH` | Qt 平台插件目录 | 实际 `platforms` 目录 |
| `QML_IMPORT_PATH` / `QML2_IMPORT_PATH` | QML import 根目录 | 实际 `qml` 目录 |
| `QT_TRANSLATIONS_PATH` | 当前项目需要时指定 Qt 翻译目录 | 实际 `translations` 目录 |
| `GI_TYPELIB_PATH` | GObject Introspection typelib | `girepository-1.0` |
| `GTK_PATH` | GTK 模块搜索路径 | 当前 GTK 主版本对应的模块目录 |

不要把 `etc`、`usr`、`usr/bin`、`usr/lib`、`usr/share` 无差别塞进所有变量。例如 `usr/share` 不属于 `LD_LIBRARY_PATH`，`usr/lib` 也不属于普通 `PATH`。

`GSETTINGS_SCHEMA_DIR`、`GIO_MODULE_DIR`、GTK immodules / pixbuf cache 等并不是上表这种可以统一扫描的通用路径列表。使用 linuxdeploy GTK plugin 时，这些值优先由 GTK hook 根据最终部署结果设置；不要在公共脚本里重新覆盖。

## 公共整理脚本

仓库公共脚本：

`common/linuxdeploy/normalize_apprun_paths.sh`

固定调用位置是：**第二次 linuxdeploy 完成之后、最终 appimagetool 封装之前**。应用构建脚本只增加一条实际调用命令，前面的下载、AppDir、AppRun、Qt / GTK plugin 和第二次 linuxdeploy 流程仍按各应用原有逻辑执行。

脚本处理规则：

- 优先处理 `AppDir/AppRun.wrapped`；没有 wrapped 时才处理 `AppDir/AppRun`。
- 只整理当前应用已经声明的路径型 `export`，不会创建“万能 AppRun”，也不会给应用强行增加未声明的环境变量。
- 已声明且目录真实存在的 AppDir 路径保留；不存在的路径删除；第二次 linuxdeploy 后实际生成的同用途标准目录会补入并去重。
- 保留应用现有路径顺序，再追加自动发现目录，避免无依据改变已有搜索优先级。
- 公共脚本不会猜测某个已经存在的应用专用 `/opt` 路径是否写进了错误变量；这类应用语义仍由对应 AppRun 和 README 明确维护。
- 只改路径型 `export` 行；不会改 `exec`、语言、主题、缩放、输入法、`QT_QPA_PLATFORM`、OpenGL 后端等应用专用逻辑，也不会覆盖 linuxdeploy 生成的顶层 hook `AppRun`。
- 如果同一个受管变量在目标 AppRun 中重复定义，脚本直接失败，不猜测应该修改哪一处。
- `common/linuxdeploy/` 发生修改时，构建计划会扫描应用脚本，只选择实际引用该公共脚本的消费者重新构建。

因此公共脚本负责“根据最终 AppDir 校准路径”，而每个应用自己的 AppRun 仍负责决定“这个应用到底需要哪些变量和特殊设置”。
