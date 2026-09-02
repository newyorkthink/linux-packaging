# GitKraken AppImage

## 用途与产物

本目录将 GitKraken Desktop 官方 Linux 稳定版重新封装为 AppImage，稳定产物名为：

```text
gitkraken.AppImage
```

GitKraken Desktop 是基于 Electron / Chromium 的图形化 Git 客户端。本项目只处理 Linux AppImage 封装、运行依赖和中文 UTF-8 / 输入法兼容，不修改 GitKraken 的授权机制、账户状态、订阅限制或应用功能。

上游来源：

- 官方网站：`https://www.gitkraken.com/`
- 官方 production release 元数据：`https://api.gitkraken.dev/releases/production/linux/x64/RELEASES`
- 官方 Linux x64 tar.gz：根据上述元数据动态解析当前稳定版后，从 GitKraken 官方 production API 下载。
- AUR `gitkraken`：仅用于核对官方 tar.gz 的目录布局、运行依赖、desktop 语义和 `chrome-sandbox` 权限，不作为二进制来源。

## 技术栈

GitKraken Desktop Linux 版采用 Electron / Chromium 技术栈。官方 Linux tar.gz 包含 GitKraken 主程序、Electron / Chromium 组件、`resources`、官方 launcher、`chrome-sandbox` 和应用图标。

当前 AppImage 目标架构为 `x86_64`。AUR 当前主要运行依赖为 GTK3、NSS、libsecret 和 libxkbfile；本项目在此基础上补齐 Electron / Chromium 常见运行库以及 GTK3 输入法模块。

## 打包方式

`build_gitkraken.sh` 采用官方 tar.gz + quick-sharun 的方式，不重新编译 GitKraken：

1. 读取 GitKraken 官方 production `RELEASES` 元数据中的当前稳定版版本号，不在仓库中锁定应用版本。
2. 校验版本格式和官方下载地址后，下载对应版本的 `gitkraken-amd64.tar.gz`，并记录实际下载文件的 SHA-256。
3. 检查归档路径安全性，要求全部文件位于官方 `gitkraken/` 顶层目录下。
4. 原样保留官方应用目录内容，仅将其放入 AppImage 的应用目录；不修改 GitKraken 的 JS / Electron 资源和授权逻辑。
5. 保留上游 `chrome-sandbox` 的 `4755` 文件模式。正式启动不会强制添加 `--no-sandbox`；只有 GitHub Actions 的 root 图形冒烟测试临时使用该参数。
6. 扫描官方应用目录中的全部 ELF，并由 quick-sharun 收集运行依赖，同时带入 GTK3 的 IBus 与 Fcitx5 input method module。
7. 根据上游 desktop 语义生成 AppImage desktop 入口并使用官方图标，最终输出 `dist/gitkraken.AppImage`。

## 中文环境与输入法

AppImage 启动 wrapper 固定以下中文 UTF-8 locale：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
```

同时 AppImage 构建中加入：

```text
/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so
/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
```

wrapper 不强制覆盖宿主已经配置的 `GTK_IM_MODULE`，因此宿主正在使用 Fcitx5 或 IBus 时仍按现有输入法会话工作。正常输入中文仍要求宿主已经启动并配置相应中文输入法；中文字符字形显示也取决于宿主可用的 CJK 字体。

这里的“中文环境”是中文 UTF-8 locale、中文字符处理和 GTK 输入法兼容，不是非官方界面翻译。GitKraken Desktop 当前没有官方中文 UI 语言包，因此本项目不会修改 Electron / JS 资源去注入第三方中文界面；应用界面语言仍由 GitKraken 官方版本本身决定。

## 构建

正式构建由仓库统一 `.github/workflows/build.yml` 执行，GitKraken 对应脚本为：

```text
gitkraken/build_gitkraken.sh
```

构建输出：

```text
dist/gitkraken.AppImage
dist/gitkraken.AppImage.sha256
dist/version.txt
dist/source.sha256
```

## 运行

在 AppImage 所在目录执行：

```bash
./gitkraken.AppImage
```

如需中文输入，宿主的 Fcitx5 或 IBus 需要已经正常运行并完成中文输入法配置。

## 验证

构建脚本会执行以下检查：

- 官方 production release 元数据能够解析出严格的稳定版版本号，且下载地址必须属于预期 GitKraken production x64 路径。
- 官方 tar.gz 可正常读取，全部归档内容位于 `gitkraken/` 顶层目录且不存在绝对路径或 `..` 路径穿越。
- 官方包包含 x86_64 GitKraken 主程序、launcher、PNG 图标和 `chrome-sandbox`。
- 打包前扫描官方应用目录全部 ELF，逐项检查 `ldd` 不存在 `not found`。
- desktop 文件通过 `desktop-file-validate`。
- 最终 AppImage 能重新提取，并确认 GitKraken 主程序、官方 launcher、图标、desktop、`chrome-sandbox`、`zh_CN.UTF-8` / `zh_CN:zh` 设置以及 IBus / Fcitx5 GTK3 输入模块真实存在。
- 最终主程序再次检查动态库依赖。
- 使用隔离 HOME / XDG 目录和 Xvfb 进行非交互 GUI 冒烟测试；只在 root CI 的测试命令中关闭 Chromium sandbox，不改变正式 AppImage 启动参数。
- 生成最终 AppImage SHA-256 供审计。

## 变更记录

### 2026-09-02：首次加入 GitKraken AppImage 与中文环境

- 新增 `gitkraken/build_gitkraken.sh` 和本 README。
- 以 GitKraken 官方 production release 为唯一应用二进制来源，版本动态获取，不锁定当前版本。
- 参照 AUR `gitkraken` 核对官方 tar.gz 布局、GTK3 / NSS / libsecret / libxkbfile 依赖和 `chrome-sandbox` 权限。
- 加入 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并带入 GTK3 的 Fcitx5 / IBus 输入模块；不覆盖宿主输入法选择。
- 明确不注入第三方中文 UI，不修改 GitKraken 授权或订阅逻辑。
- 接入仓库统一 `build.yml`，并增加归档安全、ELF / `ldd`、desktop、最终 AppImage 提取和隔离 Xvfb 冒烟检查。
