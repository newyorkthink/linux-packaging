# Deskflow AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 Deskflow 打包为 `dist/deskflow.AppImage`。

## 技术栈与打包方式

Deskflow 是跨平台键鼠共享软件，Linux GUI 使用 Qt6。构建脚本安装 Deskflow 与 X11/Wayland、Qt6、OpenGL 等运行组件，使用 quick-sharun 收集 `deskflow`、`deskflow-core` 和 `xdotool`，再把 `/usr/share/deskflow/translations` 整目录放进包并链接到主程序旁。该目录里的英文、西班牙语、意大利语、日语、韩语、俄语和简体中文一起进包。

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

Arch 包的 `/usr/share/deskflow/translations` 里是全套 qm，不只简体中文。旧 AppImage 只收集了 ELF，语言列表是空的。现在整目录复制进包，并链接到主程序同级的 `translations`。
