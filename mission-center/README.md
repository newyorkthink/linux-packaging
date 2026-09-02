# Mission Center AppImage

## 用途与产物

本目录用于将 Arch Linux Extra 仓库中的官方 `mission-center` 软件包重新封装为可分发 AppImage。

- 上游项目：Mission Center
- 软件来源：Arch Linux Extra `mission-center`
- 架构：x86_64
- 稳定产物：`dist/mission-center.AppImage`
- 构建入口：`build_mission-center.sh`
- CI 入口：`.github/workflows/build.yml`

Mission Center 用于查看 CPU、内存、磁盘、网络、GPU、应用与进程等系统资源信息。

## 技术栈

Mission Center 是 Rust 编写的 GTK4 / Libadwaita 原生 Linux 应用。Arch Linux 软件包同时提供：

- `/usr/bin/missioncenter`：主界面程序。
- `/usr/bin/missioncenter-magpie`：系统信息采集后端。
- GSettings schema、图标、desktop、AppStream、硬件数据库和 gresource 等运行资源。
- GNU gettext 翻译资源，其中 `zh` 为简体中文，`zh_TW` 为繁体中文。

## 打包方式

构建环境使用仓库统一的 Arch Linux AnyLinux 容器和 `quick-sharun`。

构建脚本执行以下步骤：

1. 使用 `pacman` 安装 Arch Linux Extra 当前正式版 `mission-center`，不锁定具体应用版本。
2. 核对主程序、`missioncenter-magpie`、desktop、图标以及简体/繁体中文 gettext 文件。
3. 按 Mission Center 上游当前 AppImage 方案，同时把 `missioncenter` 与 `missioncenter-magpie` 交给 `quick-sharun` 部署。
4. 由 `quick-sharun` 收集 GTK4、Libadwaita、运行库、应用数据和 gettext 资源，并保留其现有 AppImage 路径映射逻辑。
5. 生成 AppImage 自带的 `zh_CN.UTF-8` glibc locale 数据，在 `.env` 中设置简体中文消息环境。
6. 由 `quick-sharun --make-appimage` 生成稳定文件名 `dist/mission-center.AppImage`。

## 中文环境

本 AppImage 使用 Mission Center 上游正式 gettext 翻译，不使用插件、第三方语言包或二进制汉化补丁。

运行时固定：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
```

其中：

- `zh_CN.UTF-8` locale 数据直接内置到 AppImage，不要求宿主预先生成该 locale。
- `LANGUAGE=zh_CN:zh` 会优先请求简体中文，并回退到上游实际使用的 `zh/LC_MESSAGES/missioncenter.mo`。
- `LC_MESSAGES` 只固定界面消息语言，不强制覆盖其他区域格式类别。
- `zh_TW/LC_MESSAGES/missioncenter.mo` 同样随包保留，但默认界面选择简体中文。

## 运行与验证

在当前目录执行：

```bash
./dist/mission-center.AppImage
```

构建阶段会检查：

- Arch Linux 官方包中的主程序与 magpie 后端均存在。
- 简体中文与繁体中文 `missioncenter.mo` 均存在且可由 `msgunfmt` 正确解析。
- `quick-sharun` 打包后两套中文翻译仍存在于 AppDir。
- AppImage 内的 `zh_CN.UTF-8` locale 数据成功生成。
- `.env` 中的中文环境变量和 `LOCPATH` 均完整写入。
- 最终 `dist/mission-center.AppImage` 非空。

Mission Center 的部分硬件指标仍取决于宿主内核、驱动、硬件能力和上游自身支持范围；本打包方案不额外修改这些系统级行为。

## 修复 / 变更记录

### 2026-09-02：新增 Mission Center AppImage 与独立简体中文环境

- 现象：仓库此前没有 Mission Center AppImage 项目，无法通过统一 workflow 构建和发布带明确简体中文环境的稳定资产。
- 根因：Mission Center 上游已经提供正式中文 gettext 资源，但仓库尚未建立对应 AppImage 打包与 locale 运行环境。
- 修改文件：`mission-center/build_mission-center.sh`、`mission-center/README.md`、`.github/workflows/build.yml`。
- 处理：基于 Arch Linux Extra 当前 `mission-center` 包和上游 `quick-sharun` AppImage 路线新增构建；保留官方 `zh` / `zh_TW` 翻译，内置 `zh_CN.UTF-8` locale，并固定界面消息使用简体中文。
- 验证：构建脚本包含 gettext、locale、`.env` 和最终 AppImage 的强制检查；workflow 纳入 push、手动选择、定时全量构建与 latest Release 发布路径。
