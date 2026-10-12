# Deskflow AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 Deskflow 打包为 `dist/deskflow.AppImage`。

## 技术栈与打包方式

Deskflow 是跨平台键鼠共享软件，Linux GUI 使用 Qt6。构建脚本安装 Deskflow 与 X11/Wayland、Qt6、OpenGL 等运行组件，使用 quick-sharun 同时收集 `deskflow`、`deskflow-core`、`xdotool` 和 `/usr/share/deskflow`。翻译文件放到主程序旁的 `translations`，否则语言列表为空，界面只能保持英文。上游自带简体中文 `deskflow_zh_CN.qm`。

## 运行

```bash
./dist/deskflow.AppImage
```

## 版本元数据

构建时从本次实际安装的 Arch `deskflow` 包读取版本，去掉 epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=deskflow` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据；Deskflow 程序集合、Qt6/X11/Wayland 依赖和 quick-sharun 打包方式不变。

### 2026-10-12：带上上游翻译

Arch 包里有 `deskflow_zh_CN.qm` 等语言文件。旧 AppImage 只收集了 ELF，Deskflow 找不到 `translations`，设置里的 Language 下拉是空的。现在把 `/usr/share/deskflow` 打进包，并链接到主程序同级的 `translations`。
