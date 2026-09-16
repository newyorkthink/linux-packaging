# Remmina AppImage

## 用途与产物

本目录把 Ubuntu 24.04 官方仓库中的 Remmina 与 FreeRDP 3、GTK3、WebKitGTK 等运行组件封装为 x86_64 AppImage，稳定产物名为 `remmina.AppImage`。

## 技术栈与打包方式

Remmina 为 GTK3 / C 桌面应用，RDP 使用 FreeRDP 3。当前构建脚本在 Ubuntu 24.04 容器中安装官方软件包，使用 linuxdeploy 部署 AppDir，再由官方 appimagetool 与明确 runtime 生成 AppImage。

现有兼容处理包括 Remmina 插件相对路径、简体中文翻译、Local Terminal / SSH 运行环境、OpenSSL 3 legacy provider、WebKitGTK 运行目录、GTK3 Fcitx5 / IBus 输入模块以及本地 RDP 认证默认值。最终 workflow 仍先执行 `build_remmina.sh`，再执行 `fix_remmina_webkit.sh`；本次不改这些稳定运行逻辑。

## 版本元数据

`build_remmina.sh` 使用：

```text
dpkg-query -W -f='${Version}' remmina
```

取得实际打包的软件包版本，并在现有构建日志输出 `Remmina 版本：<版本>`。统一 workflow 在最终运行时修复完成后，从该构建日志生成：

```text
dist/version.txt
```

随后上传 `software-version-remmina`，汇总 Job 使用 `remmina.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`。相关脚本：

```text
remmina/build_remmina.sh
remmina/fix_remmina_webkit.sh
```

运行最终产物：

```bash
./remmina.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 版本信息只从当前构建已经输出的 Remmina 软件包版本提取，不改变应用构建、WebKitGTK 修复或 Release 资产名。
- 提交后不主动监控 Actions，实际新清单记录以下一次成功构建为准。

### 2026-09-16：修复版本元数据写入权限

- 故障现象：Remmina AppImage 已完成构建和 WebKitGTK 修复，但 `Prepare software version metadata` 在写入 `remmina/dist/version.txt` 时返回 `Permission denied`。
- 根因：`build_remmina.sh` 通过 Docker 在挂载的工作区中创建 `dist/`，目录归属为 root；后续 GitHub Actions runner 用户不能直接在该目录创建新文件。
- 修复内容：仅将版本文件写入改为通过 `sudo tee` 写入 root 所有的 `dist/`；不修改 Remmina 构建、WebKitGTK 修复、AppImage 内容或 Release 资产名。
