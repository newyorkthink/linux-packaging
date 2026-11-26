# i3wm AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 `i3-wm`、`i3status`、dmenu、xss-lock 与常用 i3 工具打包为 `dist/i3.AppImage`。锁屏程序不随主 AppImage 打包，避免认证与权限模型冲突。

## 技术栈与打包方式

i3 为 X11 窗口管理器，主体使用 C。构建脚本已对齐标准模板 [arch-native.sh](../templates/quick-sharun/arch-native.sh)，统一通过 `common/` 公共脚本完成安装、工作区准备与版本读写；保留 `STARTUPWMCLASS="i3"`、`PATH_MAPPING`、20 个程序入口及默认 `/etc/i3` 与 `/etc/i3status.conf` 配置，详见 [模板差异说明](./docs/template-deviations.md)。

## 运行与兼容说明

在当前目录执行：

```bash
./dist/i3.AppImage
```

Perl 辅助脚本继续依赖宿主 Perl；i3lock/slock 不进入本 AppImage。现有 PATH_MAPPING、默认配置和 X11 工具集合保持当前稳定基线。

## 版本元数据

构建时从本次实际安装的 `i3-wm` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。统一版本清单键使用 `i3`，对应 Release 资产 `i3.AppImage`。

## 变更记录

### 2026-11-27：按标准模板重写 `build_i3wm.sh`

- 核实 `pkgforge-dev` 无 `i3` 仓库，确认沿用 Arch 官方 `extra/i3-wm` 原生包路线。
- 按 [arch-native.sh](../templates/quick-sharun/arch-native.sh) 重写 [build_i3wm.sh](./build_i3wm.sh)，统一接入公共安装、工作区与版本脚本；完整保留 `STARTUPWMCLASS="i3"`、`PATH_MAPPING`、全部 20 个入口及默认配置复制，并新增 [模板差异说明](./docs/template-deviations.md)。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-16：接入统一软件版本元数据

仅增加版本读取、`dist/version.txt` 与统一 `software_versions.json` 映射，不改变现有 i3 程序集合、配置映射或锁屏边界。

## 实机验证

### 2026-11-27：用户实机验证通过

用户已确认 i3wm `4.25.1` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 版本输出与窗口管理运行 | `i3 --version` 正常输出 `4.25.1`，更新后窗口管理与状态栏运行正常。 |
