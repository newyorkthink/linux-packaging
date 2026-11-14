# Xberg AppImage

本目录将 [Xberg](https://github.com/xberg-io/xberg) 官方 GNU x86_64 预编译命令行归档封装为 `xberg.AppImage`。程序及其相邻运行库来自官方正式 Release，使用 quick-sharun 收集其余运行依赖，不从源码编译。

## 文件与入口

| 文件 | 用途 |
| --- | --- |
| `build_xberg.sh` | 安装构建来源、独立下载最终归档、保留完整程序目录并封装 AppImage。 |
| `patched/xberg.svg` | 原样保存的官方 SVG 图标。 |
| `patched/branding-LICENSE` | 官方品牌资源的 MIT 许可证。 |
| `docs/template-deviations.md` | 来源、公共入口、专属布局及维护依据。 |

## 打包流程

构建运行在统一 Arch matrix 中，登记于 `.github/appimage-apps.json`，由 `.github/workflows/build.yml` 的 `Build Xberg` 调度。输出目录为 `xberg/dist`，最终资产为 `xberg.AppImage`，版本由同次最终归档的公共下载入口返回并保存到 `dist/version.txt`。

1. 使用公共 Arch 基础安装和工作区入口。基础包提供 GNU 运行时、GCC 运行库、OpenSSL、证书和打包工具。
2. 独立下载、校验并解包安装来源，在隔离构建系统的 `/opt/xberg` 保留完整目录并提供系统命令入口。
3. 再独立下载、校验最终归档，将该归档中的完整目录放入 `AppDir/bin`；最终程序不从系统安装目录复制。
4. 将明确指定的完整程序目录交给 quick-sharun 收集依赖，保留官方相邻共享库和许可证。
5. 准备命令行 desktop 与官方图标，封装后由公共入口保存实际版本，既有 workflow 完成发布及软件版本清单更新。

归档版本动态选择，不锁定当前版本。下载使用现有固定资产入口，校验同一 Release 资产的 GitHub SHA-256；直链失败时仍按同一资产 ID 认证回退。公共下载、解包、安装、工作区和版本脚本保持原样。

## 使用

在 Linux 终端中，进入 AppImage 所在目录执行：

```bash
# 查看官方命令行帮助。
./xberg.AppImage --help

# 提取指定文档的内容，文档路径需按实际文件替换。
./xberg.AppImage extract "<文档路径>"
```
`AppRun` 由 quick-sharun 生成，保持命令行参数传递。desktop 中的 `Terminal=true` 表示终端程序，不额外创建 GUI 或后台服务。输出和导出行为仍由 Xberg 官方命令与参数控制。

## 来源与维护

GNU 包内的主程序和相邻 `.so` 是一个整体，不只提取主程序，也不按旧截图写死共享库名单。应用、REST API、MCP、格式支持等保留官方这份二进制已有的编译特性；不将官方不同发行资产的功能混作本包新增能力。

图标和品牌资源 MIT 许可证分别原样保存在 [`patched/xberg.svg`](./patched/xberg.svg) 与 [`patched/branding-LICENSE`](./patched/branding-LICENSE)，构建时复制到工作区后随包保留；不重画或修改标志。详细定位与专属处理见[差异说明](./docs/template-deviations.md)。本项目归入 [quick-sharun 官方预编译归档命令行工具](../docs/packaging-classification.md#用-quick-sharun-打包的官方预编译归档命令行工具) 分类，不新增模板。

## 实机验证

### 2026-11-14：用户实机验证通过

用户已确认 Xberg 官方 GNU CLI 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| DOC 文档提取 | 用户在 Linux 终端使用官方 GNU CLI 的 extract 命令成功提取 DOC 正文，并确认可用。 |
