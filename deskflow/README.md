# Deskflow AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 Deskflow 打包为 `dist/deskflow.AppImage`。

## 技术栈与打包方式

Deskflow 是跨平台键鼠共享软件，Linux GUI 使用 Qt6。构建脚本已对齐标准模板 [qt-installed.sh](../templates/quick-sharun/qt-installed.sh)，统一通过 `common/` 公共脚本安装 Deskflow、Qt6 主题/输入插件及 X11/Wayland 依赖，启用 `DEPLOY_QT=1` 与包内中文 locale，收集 `deskflow`、`deskflow-core` 和 `xdotool`，再把 `/usr/share/deskflow/translations` 整目录放进包并链接到主程序旁，详见 [模板差异说明](./docs/template-deviations.md)。该目录里的英文、西班牙语、意大利语、日语、韩语、俄语和简体中文一起进包。

## 运行

```bash
./dist/deskflow.AppImage
```

## 版本元数据

构建时从本次实际安装的 Arch `deskflow` 包读取版本，去掉 epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=deskflow` 接入统一清单。

## 变更记录

### 2026-11-27：按标准模板重写 `build_deskflow.sh`

- 核实 `pkgforge-dev` 无 `deskflow` 仓库，确认沿用 Arch 官方 `extra/deskflow` 原生 Qt6 包路线。
- 按 [qt-installed.sh](../templates/quick-sharun/qt-installed.sh) 重写 [build_deskflow.sh](./build_deskflow.sh)，统一接入公共安装、工作区与版本脚本，补齐 `fcitx5-qt`、`DEPLOY_QT=1` 与包内中文 locale，完整保留 `STARTUPWMCLASS="deskflow"` 及上游翻译目录复制与软链接，并新增 [模板差异说明](./docs/template-deviations.md)。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据；Deskflow 程序集合、Qt6/X11/Wayland 依赖和 quick-sharun 打包方式不变。

### 2026-10-12：带上上游翻译

Arch 包的 `/usr/share/deskflow/translations` 里是全套 qm，不只简体中文。旧 AppImage 只收集了 ELF，语言列表是空的。现在整目录复制进包，并链接到主程序同级的 `translations`。
