# CC Switch AppImage

本目录将 [farion1231/cc-switch](https://github.com/farion1231/cc-switch) 的官方 Linux x86_64 DEB 重新封装为 `cc-switch.AppImage`，沿用现有 Arch Linux AnyLinux / quick-sharun 路线。

## 用途与产物

- 软件用于管理 Claude Code、Codex 和 Gemini CLI 等工具的配置。
- 最终发布资产为 `dist/cc-switch.AppImage`，成功生成后写入 `dist/version.txt`。
- 构建入口为 `cc-switch/build_cc-switch.sh`，由现有 `.github/workflows/build.yml` 标准 Arch matrix 和 `build-anylinux` Action 执行；清单 key 为 `cc_switch`。

## 技术栈

CC Switch 为 Tauri 2 / Rust 桌面应用。已核对的 Linux 主程序直接依赖 GTK 3、WebKitGTK 4.1 和 libsoup 3；托盘通过 AppIndicator / Ayatana AppIndicator 动态加载。分类归入 Tauri / GTK 程序。

## 打包方式

1. 通过公共入口安装统一基础包，再安装 `cc-switch-bin` 及原有运行依赖；原来的 60 项安装参数全部有保留来源，同时补充 `fcitx5-gtk` 和 `dpkg`。
2. 公共 GitHub 下载入口选择当前正式 semver Release 的唯一 x86_64 DEB，核对 GitHub SHA-256、DEB 包名 `cc-switch` 和 `amd64` 架构，并把同一资产的版本输出到 `cc-switch.version`。最终程序独立下载，不从系统安装的 `/usr/bin` 复制。
3. 公共解包入口展开 DEB，将其中完整的 `usr/bin/.` 复制到 `AppDir/bin/`。本次核对的包在该目录只有 `cc-switch` ELF；desktop 和 128×128 图标继续使用已安装包的原路径。
4. 通过公共 `text` 版本入口读取本次下载的 Release 版本，保持在第一次 quick-sharun 之前；不使用可能滞后的 AUR 安装版本代替。
5. 调用 `quick-sharun AppDir/bin/* /usr/lib/libayatana-appindicator3.so.1`，保留原有托盘动态库修复。GTK 输入模块由工具自动收集；实际 ELF 的 WebKitGTK 依赖可被工具识别，无需另加部署开关和目录。
6. 按标准生成包内 `zh_CN.UTF-8` 并追加语言环境，最终封装成功后单行调用公共保存入口写入 `dist/version.txt`。

脚本按已确认的 69 行草稿执行。通用注释、元数据顺序和空行保持标准格式；程序来源、版本来源和托盘参数的具体依据见下方说明。

## 运行

在 AppImage 所在目录打开 Linux 终端：

```bash
# 赋予 AppImage 执行权限。
chmod +x cc-switch.AppImage

# 启动 CC Switch。
./cc-switch.AppImage
```

## 运行与兼容说明

- 托盘依赖由 `libayatana-appindicator` 提供，显式收集 `libayatana-appindicator3.so.1`，其必要依赖由 quick-sharun 处理。
- IBus 由公共基础包保留，Fcitx5 的 GTK 模块由 `fcitx5-gtk` 提供；宿主会话仍需正常配置并运行相应输入法。包内 locale 用于避免依赖宿主是否生成简体中文环境。
- 本次已校验官方 DEB、包名、架构、desktop、图标、ELF 依赖及脚本语法；这些静态结果不代表新的 AppImage 已构建成功或完成实机验收。

## 维护说明

- [固定配置依据](docs/hardcoded.md)：包内路径、资产模板、托盘库、版本文件和现有故障记录。
- [模板差异说明](docs/template-deviations.md)：Tauri / GTK 布局、依赖覆盖、下载版本来源及工具自动部署依据。
- [打包分类](../docs/packaging-classification.md#用-quick-sharun-打包的-tauri--gtk-程序)：只登记已经按当前标准完成重写的项目。

## 修复记录

### 2026-09-21：修复启动时缺少 AppIndicator 动态库导致的崩溃

- **故障现象：** CC Switch 3.20.3 AppImage 启动后 panic，错误为 `Failed to load ayatana-appindicator3 or appindicator3 dynamic library`，并报告 `libayatana-appindicator3.so.1`、`libappindicator3.so.1` 等无法打开。
- **根因：** 构建环境已经安装 `libayatana-appindicator`，但原 `quick-sharun` 输入只有 CC Switch 主程序和 GTK3 IBus module。CC Switch 的托盘库通过运行时动态加载，不能保证仅靠主程序 ELF 依赖自动进入 AppImage。
- **依据：** CC Switch 上游 Linux 构建明确依赖 Ayatana AppIndicator；上游 Flatpak 配置也打包 `libayatana-appindicator`。Arch Linux 当前 `libayatana-appindicator` 包提供 `/usr/lib/libayatana-appindicator3.so.1`。
- **修改文件：** `cc-switch/build_cc-switch.sh`、本 README。
- **修复内容：** 仅在现有 `quick-sharun` 输入中显式加入 `/usr/lib/libayatana-appindicator3.so.1`；未改变主程序、IBus module、依赖安装顺序、版本解析或发布逻辑。
- **提交：** 本条记录与修复代码位于同一提交。
- **验证状态：** 已完成脚本语法检查和依赖路径核对；提交后按仓库规则不主动监控 Actions，因此新产物构建及真实 Linux 运行效果仍待实际结果确认。

### 2026-10-30：按标准直接下载 DEB 并统一版本与中文环境

- 按批准的 69 行草稿重写构建脚本，保留全部原依赖覆盖和托盘库修复；应用程序改为独立下载并校验的官方 DEB，公共下载、解包、版本读取和保存各自只保留一条调用。
- 原安装版本解析改为读取同一下载资产的版本文本；补齐 Fcitx5 GTK 模块和包内中文 locale。已确认当前 quick-sharun 会自动收集 GTK 输入模块，并根据实际 ELF 的 WebKitGTK 依赖设置部署参数，故不重复传入 IBus 模块或添加额外开关。
- 同步更新本 README，新增固定配置及模板差异说明，并将本项目加入 Tauri / GTK 直接下载安装包分类。原有修复记录完整保留，公共脚本和工作流保持不变。
- 提交前检查批准草稿逐字一致性、69 行结构和空行、依赖覆盖、公共接口、Bash 语法、文档链接及完整 diff；本次未安装应用、重新构建 AppImage 或进行真实图形、托盘、输入法和协议回调验证。
