# htop AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `htop` 软件包，通过 quick-sharun 生成 `htop.AppImage`。现有打包逻辑同时包含 `lsof`、`strace` 以及 htop 运行时需要的 libsensors / libnl 组件。

正式构建由 `.github/workflows/build.yml` 的 `Build htop` Job 完成，最终资产固定发布为 `htop.AppImage`。

## 版本元数据

构建时从当前实际安装的 Arch `htop` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel，最终 AppImage 成功生成后写入：

```text
htop/dist/version.txt
```

该文件由 workflow 上传为 `software-version-htop`，成功构建后由当前 `Build htop` Job 立即写入仓库根目录的 `software_versions.json`。

## 维护说明

- 保持 Arch 官方 `htop.desktop` 与 `htop.svg`。
- 保持现有 quick-sharun 依赖收集逻辑，不因版本元数据接入改动运行依赖。
- 版本值必须来自本次实际安装的软件包，不手工写死。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 构建成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=htop` 与统一 `software_versions.json`。
- 移除原构建脚本末尾用于验证运行结果的 AppImage `--version` 调用；版本改从本次实际安装的软件包元数据取得。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
