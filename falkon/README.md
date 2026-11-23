# Falkon AppImage

Falkon 是基于 Qt 6 和 Qt WebEngine 的 KDE 浏览器。此目录用于准备 Linux x86_64 的 `falkon.AppImage`。程序来源为 [Arch Linux Extra 的 Falkon 软件包](https://archlinux.org/packages/extra/x86_64/falkon/)。

## 打包方式

- 按[从系统真实入口收集](../docs/packaging-classification.md#从系统真实入口收集)的方式使用 [Qt 6 系统入口模板](../templates/quick-sharun/qt-installed.sh)。
- [构建脚本](./build_falkon.sh) 由 [Generate build script](../.github/workflows/generate-build-script.yml) 生成。模板通过公共入口安装软件包及其依赖，并读取实际安装版本。
- [Build AppImages](../.github/workflows/build.yml) 的标准 Arch 矩阵构建 `falkon.AppImage`，构建成功后发布到 [latest Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest)。
- quick-sharun 从 `/usr/bin/falkon` 收集程序和依赖，使用同一软件包的桌面入口和图标。Qt WebEngine 的辅助进程与资源使用 quick-sharun 的自动部署逻辑。

## 当前状态

构建脚本已由标准生成器输出并通过 Bash 语法检查。Falkon AppImage 的首次标准构建已成功并发布。

## 运行

下载成品后，在普通用户的图形会话中执行。

```bash
chmod +x falkon.AppImage
./falkon.AppImage
```

## 实机验证

### 2026-11-24：用户实机验证通过

用户已确认 Falkon AppImage 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 启动 | 浏览器在 Linux 图形会话中正常启动。 |
| 中文界面和输入法 | 中文界面正常显示，地址栏可输入中文并显示输入法候选词。 |
| 网页和图片 | 百度首页、DuckDuckGo 搜索结果和图片搜索均能正常加载和显示。 |
| 快速访问页 | 四张网站预览缩略图均正常显示。 |
