# CopyQ 官方处理取舍

## 来源

核对的 pkgforge-dev 快照为 `f7de79ddd826a17c3a53508b7ab87252f2b14da9`：[依赖脚本](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/f7de79ddd826a17c3a53508b7ab87252f2b14da9/get-dependencies.sh)、[封装脚本](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/f7de79ddd826a17c3a53508b7ab87252f2b14da9/make-appimage.sh)、[workflow](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/f7de79ddd826a17c3a53508b7ab87252f2b14da9/.github/workflows/appimage.yml) 和 [README](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/f7de79ddd826a17c3a53508b7ab87252f2b14da9/README.md)。其 workflow 使用 Arch 容器安装官方 CopyQ 包，再由 quick-sharun 封装；没有本仓库必须复制的独立应用 hook 或 wrapper 文件。

本项目继续使用 Arch 官方二进制包和系统入口。CopyQ 自身的 [正式 Release](https://github.com/hluk/CopyQ/releases/latest) 也提供现成 AppImage，本次保持已有重新封装路线，不切换为下载另一个成品。

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装 CopyQ | 官方直接系统升级命令未启用，使用本仓库标准公共入口。 | [基础包](../build_copyq.sh#L11)、[应用依赖](../build_copyq.sh#L13)。 | 安装官方二进制包，保留原依赖覆盖，不引入额外系统升级流程。 |
| 瘦身包 | 未启用。 | 上游 `get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan` 未写入本项目。 | 沿用现有 Arch 软件包与运行库，不替换 Mesa / Qt 组件。 |
| 完整依赖与资源收集 | 采用，原样复用官方代码。 | [完整命令](#完整收集命令)，[构建位置](../build_copyq.sh#L44)。 | 明确收集程序、插件和共享资源；官方仅注释 Deploy dependencies，未逐项说明额外目录的原因。目录用途由官方软件包文件列表核对。 |
| 版本读取与保存 | 官方直接解析命令未启用，使用标准公共入口。 | [读取](../build_copyq.sh#L41)、[保存](../build_copyq.sh#L76)。 | 保留当前实际安装版本来源及去除 epoch、pkgrel 的行为，成功封装后再保存。 |
| 图标 | 保留现有 SVG，不采用上游 PNG 路径。 | [图标位置](../build_copyq.sh#L28)。 | 官方包同时提供 SVG 与 PNG，现有取值有效，不为对齐而更换图标。 |
| 自更新与更新信息 | 未启用上游 self-updater hook，不显式设置 UPINFO。 | 未加入 `export ADD_HOOKS="self-updater.hook"`，也未显式设置 `UPINFO`。 | 上游 README 说明该 hook 会请求检查更新并提示新版；本次沿用本仓库发布方式。未显式配置 UPINFO 不代表工具不会自行推断更新元数据。 |
| 强制软件渲染 | 未启用。 | 未加入 `export ALWAYS_SOFTWARE=1`；保留 [现有 OpenGL 配置](../build_copyq.sh#L36)。 | 官方未说明原因；本次没有切换 CopyQ 渲染方式的故障依据，保持已有配置。 |
| 最终封装 | 保留标准步骤，与官方命令相同。 | `quick-sharun --make-appimage`，[构建位置](../build_copyq.sh#L73)。 | 由工具生成并封装 AppImage，不另写 AppRun。 |

## 完整收集命令

上游 [make-appimage.sh](https://github.com/pkgforge-dev/CopyQ-AppImage/blob/f7de79ddd826a17c3a53508b7ab87252f2b14da9/make-appimage.sh) 的以下完整命令原样保留：

```bash
# 复用官方代码：收集程序及其运行依赖。
quick-sharun /usr/bin/copyq /usr/lib/copyq /usr/share/copyq
```

`/usr/bin/copyq` 是程序入口，`/usr/lib/copyq` 包含功能插件，`/usr/share/copyq` 包含主题与翻译；对应目录见 [Arch 官方文件列表](https://archlinux.org/packages/extra/x86_64/copyq/files/)。上游未另外说明各个收集目录的具体原因。

本仓库原有的插件兼容链接和翻译目录配置继续保留，不标成上游原样代码；详情见 [模板差异](./template-deviations.md) 与 [固定配置](./hardcoded.md)。
