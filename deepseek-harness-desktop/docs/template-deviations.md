# DeepSeek Harness 桌面版模板差异

本文件说明当前构建为何与 [Electron 直接下载标准模板](../../anylinux_projects.md#直接下载安装包的标准模板) 不完全相同。通用阶段、元数据顺序、中文环境和公共版本接口沿用标准；只保留已确认的来源差异和本应用原有处理，不把专属修复加入其他应用。

## 来源核实与适用分类

- 本次按 DeepSeek Harness、deepseek-harness-desktop 等名称核实，未找到 pkgforge-dev 对应打包仓库；不编造官方专属代码或不存在的 hook。
- [官方桌面打包说明](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/packaging/README.md) 明确 Linux 不是受支持的桌面发布目标；当前 [AUR PKGBUILD](https://github.com/archlinux/aur/blob/deepseek-harness-desktop/PKGBUILD) 和 [.SRCINFO](https://github.com/archlinux/aur/blob/deepseek-harness-desktop/.SRCINFO) 从官方 Git tag 获取源码，并应用社区 Linux 适配。
- 当前未找到可用于此桌面版的 Linux DEB 或其他适用预编译安装包。因此采用 [从系统里已安装的程序取得](../../docs/packaging-classification.md#从系统里已安装的程序取得) 分类：先由 AUR 构建并安装，再复制完整程序目录。与已有二进制包时的两阶段规则区分，不把 simdjson 库包下载误写成应用安装包下载。

## 当前保留的差异

| 阶段 | 处理、必要性依据与影响 |
| --- | --- |
| 安装 | 保留原有 simdjson 动态下载及 `pacman -U --noconfirm simdjson.pkg.tar.zst`，再安装 AUR 应用和 `fcitx5-gtk`，最后独立追加 `libxcrypt-compat`。这是已有 Node ABI 和 `_crypt` 缺库故障的处理，不合并、替换或调整已确认的原命令。 |
| 程序来源 | 当前没有适用的预编译桌面安装包，将 AUR 已安装的 `/usr/lib/deepseek-harness-desktop/.` 完整复制到 `AppDir/bin/`；`/usr/bin` 的 shell 包装不作为真实程序入口。不添加不存在的应用 DEB 下载和解包阶段。 |
| 许可证 | 在程序复制之后、元数据之前，保留原有独立许可证复制命令。依据是上游 MIT 分发要求；当前未确认其他资源已包含同一声明，不能为套模板而直接省略。 |
| 版本 | 第一次 quick-sharun 前，用公共入口的 `pacman` 来源读取已安装应用版本；不套用其他程序的 `package.json` 路径。epoch 和 pkgrel 由公共实现去除，alpha 等应用版本标识保留。 |
| 依赖收集 | 保留仅作用于第一次 quick-sharun 的 Python 私有库搜索路径，解决历史 `_tkinter` 扫描缺少 Tcl/Tk 库的问题；不导出成永久运行时变量，也不影响后续 `--make-appimage` 调用。 |
| 版本保存 | 最终 AppImage 成功生成后，以单行调用公共保存入口；这是标准步骤，不额外维护一套版本写入实现。 |

依赖收集的既有命令保持原样：

```bash
# 内置 Python 的库不在系统路径上。只给这一次扫描使用。
LD_LIBRARY_PATH="AppDir/bin/resources/runtime/primary-runtime/dependencies/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun AppDir/bin/*
```

本应用原有显式依赖全部保留：基础工具继续由未修改的 `--base` 清单提供；`deepseek-harness-desktop`、`fcitx5-gtk`、`libxcrypt-compat` 和独立 simdjson 安装继续留在原阶段，不以标准化为由删包。

## 通用格式与行数

当前脚本共 75 行，其中 25 行为中文注释，12 行为空行。空行位于第 2、5、9、22、26、29、33、52、55、60、70、73 行。它与已批准草稿逐字一致，不为凑成 DEB 模板的行数而添加不存在的下载、解包或无意义空行。

共用的严格模式、脚本目录、基础安装注释、目录准备、完整程序复制、九项元数据及其顺序、版本注释、中文 locale、最终封装和单行保存沿用标准。差异段留在对应阶段，旧脚本顶部两条重复说明移除；三行手工版本解析改成一行公共调用。

## 依据与验证边界

- 固定值、许可证依据、simdjson 原始报错及旧 Python 日志缺失情况见 [固定配置说明](hardcoded.md)；`_crypt` 的故障与检查结果见 [README](../README.md#检查记录)。不把旧故障记录冒充对当前新产物的重新实测。
- 此前用户已经实测确认桌面启动和基础中文对话；本次保留该结论。当前修改只涉及脚本格式和公共版本接口，没有重新构建 AppImage，不能据此扩大为 Office、其他模型或跨发行版功能均通过。
- 当前没有对应 pkgforge-dev 处理的采用或暂不采用清单，因此不新增空的 `pkgforge-differences.md`。
