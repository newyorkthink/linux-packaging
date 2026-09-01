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

## AppRun 入口踩坑

不要依赖 `linuxdeploy` 根据 desktop `Exec` 自动创建根目录 `AppRun` symlink。XnConvert 使用 Qt plugin 时会生成 `apprun-hooks`，如果构建前没有自己的根目录 `AppRun`，最终很容易得到：

```text
AppRun
AppRun.wrapped -> usr/bin/xnconvert
```

这里的 `AppRun.wrapped` 只是 symlink，不是实际启动脚本。

正确做法是在运行 `linuxdeploy` 前先写好根目录 `AppRun` 普通文件，并把已经验证正常的 Qt/XCB/Fcitx5 环境变量放在这个文件中。`linuxdeploy` 检测到现有 `AppRun` 后不会再创建入口 symlink；Qt plugin 创建 `apprun-hooks` 后，linuxdeploy 会把原来的 `AppRun` 重命名为 `AppRun.wrapped`，再生成新的 hook `AppRun`。

最终结构应为：

```text
AppRun                  # linuxdeploy 生成的 hook 入口，普通文件
AppRun.wrapped          # 构建前预置的真实启动脚本，普通文件
usr/bin/xnconvert       # desktop/命令入口
```

构建后必须检查：

- `AppRun.wrapped` 存在且可执行。
- `AppRun.wrapped` 不能是 symlink。
- 根目录 `AppRun` 必须实际调用 `AppRun.wrapped`。
- `AppRun.wrapped` 必须继续保留 `usr/plugins` 的 Fcitx5 Qt5 插件搜索路径。

## 踩坑记录

旧版可正常中文输入的 `AppRun.wrapped` 本身就包含 `usr/plugins` 等 Qt 插件搜索路径。后续重做打包时，如果只关注 XnConvert 自带的 `opt/XnConvert/lib` 和 XCB 插件，很容易把原先有效的 Fcitx5 插件路径覆盖掉。

因此后续修改启动器时：

- 不要把 `QT_PLUGIN_PATH` 写死为单一目录。
- 必须保留 `usr/plugins`，否则 Fcitx5 Qt5 输入法插件无法加载。
- 修改 Qt/XCB 运行时路径时，不要破坏已经验证正常的输入法插件搜索路径。
- 不要让最终 `AppRun.wrapped` 退化成指向 `usr/bin/xnconvert` 的 symlink。
- 构建后必须检查 Fcitx5 Qt5 input context plugin 是否真实存在于最终 AppImage。
