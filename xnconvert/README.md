# XnConvert

XnConvert 的 AppImage 打包说明与兼容性记录。

## 中文输入修复

XnConvert 使用 Qt5。构建环境即使已经安装：

- `fcitx5-frontend-qt5`
- `libfcitx5-qt1`

如果启动器把 `QT_PLUGIN_PATH` 只写成：

```bash
export QT_PLUGIN_PATH="$ROOT/opt/XnConvert/lib"
```

仍会导致 Fcitx5 中文输入失效。

原因是 `linuxdeploy` 打包后的 Fcitx5 Qt5 输入法插件位于：

```text
usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
```

但上述 `QT_PLUGIN_PATH` 没有包含 `usr/plugins`，Qt5 无法找到 `platforminputcontexts` 插件。

最终修复为保留 XnConvert 自带 Qt 插件目录，同时加入 AppImage 内的 `usr/plugins`：

```bash
export QT_PLUGIN_PATH="$ROOT/opt/XnConvert/lib:$ROOT/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
```

构建完成后同时检查最终 AppImage 必须包含：

```text
usr/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
```

否则构建直接失败，避免再次发布无法使用 Fcitx5 中文输入的产物。

## 踩坑记录

旧版可正常中文输入的 `AppRun.wrapped` 本身就包含 `usr/plugins` 等 Qt 插件搜索路径。后续重做打包时，如果只关注 XnConvert 自带的 `opt/XnConvert/lib` 和 XCB 插件，很容易把原先有效的 Fcitx5 插件路径覆盖掉。

因此后续修改启动器时：

- 不要把 `QT_PLUGIN_PATH` 写死为单一目录。
- 必须保留 `usr/plugins`，否则 Fcitx5 Qt5 输入法插件无法加载。
- 修改 Qt/XCB 运行时路径时，不要破坏已经验证正常的输入法插件搜索路径。
- 构建后必须检查 Fcitx5 Qt5 input context plugin 是否真实存在于最终 AppImage。