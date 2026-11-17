# Gufw 构建故障记录

## 2026-11-17 主 desktop 自动选择错误

### 故障现象与发生阶段

首次构建在第二次 linuxdeploy 完成依赖部署、准备 AppDir 根目录桌面资源并运行 AppImage 输出插件时失败。后续最终封装和 Release 发布步骤未执行。

失败构建对应提交 [44f3a5e](https://github.com/newyorkthink/linux-packaging/commit/44f3a5eb576cc36a6b77d0d31f3bf7125dcaeefe)，原始日志见 [Build Gufw Job](https://github.com/newyorkthink/linux-packaging/actions/runs/43902110165/job/133421328107)。

### 报错原文

```text
WARNING: No desktop file specified, using first desktop file found: AppDir/usr/share/applications/python3.14.desktop
错误：Icon 名无法放到 AppDir 根目录：/usr/share/pixmaps/python3.14
ERROR: Failed to run plugin: appimage (exit code: 1)
```

### 触发条件与已核实原因

AppDir 同时包含 Gufw 和 Python 运行包提供的 desktop。`build_gufw.sh` 的第二次 linuxdeploy 调用没有传入 `--desktop-file`，工具自动选中了 `python3.14.desktop`。该文件的绝对图标路径随后被现有公共图标检查拒绝。

故障归属于应用构建脚本的主 desktop 选择。Gufw 上游提供的 desktop 使用 `Exec=gufw` 和 `Icon=gufw`，原文见 [gufw.desktop.in](https://github.com/costales/gufw/blob/26.04/gufw.desktop.in)。

### 修复内容

修改 `gufw/build_gufw.sh`，在第二次 linuxdeploy 调用中显式传入 `--desktop-file "$APPDIR/usr/share/applications/gufw.desktop"`，由 Gufw 自身的 desktop 部署根目录入口及图标。

### 处理状态与验证结果

已完成失败日志、上游 desktop、参数路径和调用顺序的静态核对。后续正式产物已发布，用户实测图形授权及主窗口启动通过；保留本次构建故障与修复过程。

用户实机验证通过，结果见 [README 实机验证](../README.md#实机验证)。
