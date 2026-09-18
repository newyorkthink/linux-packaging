# poppler-utils AppImage

## 用途与产物

本目录把 Arch Linux 官方 `poppler` 软件包中的 PDF 命令行工具打包为 `poppler-utils.AppImage`。一个 AppImage 提供整套入口，用法与 `android-tools` / `picom` 相同：按链接名或第一个参数分派命令。

包含的命令：

- `pdfattach`
- `pdfdetach`
- `pdffonts`
- `pdfimages`
- `pdfinfo`
- `pdfseparate`
- `pdfsig`
- `pdftocairo`
- `pdftohtml`
- `pdftoppm`
- `pdftops`
- `pdftotext`
- `pdfunite`

上游软件来源：

- Arch extra 仓库 `poppler`（工具本体）
- Arch extra 仓库 `poppler-data`（CMap / 编码数据，供文字提取使用）
- 上游项目：<https://poppler.freedesktop.org/>

正式构建由 `.github/workflows/build.yml` 的标准 matrix Job 完成，固定发布资产为 `poppler-utils.AppImage`。

## 技术栈

- 上游为 Poppler 的 C / C++ 命令行工具，不是桌面 GUI。
- 目标架构：当前构建环境的 `uname -m`（正式构建为 x86_64）。
- 打包工具：Arch Linux 容器中的 quick-sharun / sharun，runtime 为 uruntime。
- 官方包没有 desktop / 图标，构建使用 `DESKTOP=DUMMY`，默认主程序为 `pdftotext`。ICON 使用构建环境 Adwaita 的 `x-office-document.svg`（Adwaita 50 已无 `application-pdf`），不自绘品牌图。
- 不安装 udev、不请求额外系统权限。

## 打包方式

沿用仓库已验证的 Arch 官方包 + quick-sharun 最短链路，参考 `newsboat`、`picom`、`qemu` 的多命令收集方式。上游是发行版 `/usr/bin` 工具，不是 zip / `/opt` 布局，因此不套用 `android-tools` 的 `AppDir/bin` 预拷贝。

1. 安装 AGENTS.md 规定的 quick-sharun 最小基础包，不预装 GTK / Qt / Mesa。
2. 单独安装 `poppler` 与 `poppler-data`，由包管理器拉入真实运行依赖。
3. 从本次安装的 `poppler` 包读取版本，去掉 epoch / pkgrel，不写死版本号。
4. 确认 13 个 `/usr/bin` 入口存在后，一次性交给 `quick-sharun`；若存在 `/usr/share/poppler` 则一并收集。
5. `quick-sharun --make-appimage` 生成 `dist/poppler-utils.AppImage`。
6. 写入 `dist/version.txt`。

workflow 入口：`poppler-utils/build_poppler-utils.sh`，`SOFTWARE_KEY=poppler-utils`。成功后由当前 Job 立即写入 `latest` Release 的 `software_versions.json`。

## 运行与兼容说明

把同一个 AppImage 按命令名做符号链接后，quick-sharun 会按链接名分派对应程序：

```bash
ln -sf ./poppler-utils.AppImage ./pdftotext
ln -sf ./poppler-utils.AppImage ./pdfinfo
ln -sf ./poppler-utils.AppImage ./pdffonts
ln -sf ./poppler-utils.AppImage ./pdfimages
ln -sf ./poppler-utils.AppImage ./pdfattach
ln -sf ./poppler-utils.AppImage ./pdfdetach
ln -sf ./poppler-utils.AppImage ./pdfseparate
ln -sf ./poppler-utils.AppImage ./pdfsig
ln -sf ./poppler-utils.AppImage ./pdftocairo
ln -sf ./poppler-utils.AppImage ./pdftohtml
ln -sf ./poppler-utils.AppImage ./pdftoppm
ln -sf ./poppler-utils.AppImage ./pdftops
ln -sf ./poppler-utils.AppImage ./pdfunite
./pdftotext -v
```

也可以不建链接，直接把命令名当作第一个参数：

```bash
./poppler-utils.AppImage pdftotext -v
./poppler-utils.AppImage pdfinfo 文档.pdf
```

直接运行 `./poppler-utils.AppImage`（不带命令名）时走默认主程序 `pdftotext`。

当前已确认：

- Arch extra `poppler` 文件列表包含上述 13 个 `/usr/bin` 入口，无官方 desktop / 图标。
- 本仓库同类多命令 quick-sharun 基线：`newsboat`（`newsboat` + `podboat`）、`picom`（多入口）、`qemu`（`qemu-*`）。

构建及实机运行结果在提交后按仓库规则不监控 Actions，待正式构建产物后再验证。

## 修复记录

### 2026-09-18：新增 poppler-utils AppImage

- 日期：2026-09-18
- 现象：需要不安装发行版系统包即可使用整套 Poppler PDF 命令行工具。
- 根因：Poppler 官方不发布 Linux 独立二进制；发行版 `poppler` / `poppler-utils` 提供整套命令，需要重打包才能不依赖宿主安装该软件包。
- 修改文件：新增 `poppler-utils/` 目录；在 `.github/appimage-apps.json` 增加标准应用记录。
- 具体内容：按 Arch 官方 `poppler` / `poppler-data` + quick-sharun 最短链路打包 13 个命令；版本从本次安装的软件包动态读取。
- 已知结果：已提交正式构建入口，未监控 Actions，构建及运行结果未验证。

### 2026-09-18：补上 DUMMY desktop 仍缺少的 ICON

- 日期：2026-09-18
- 现象：[run 35349847442](https://github.com/newyorkthink/linux-packaging/actions/runs/35349847442) 的 `Build poppler-utils` 失败。日志：`ERROR: Missing AppDir/.DirIcon`，并提示 `Set ICON env variable`。
- 根因：`DESKTOP=DUMMY` 只会生成空 desktop，quick-sharun 仍要求图标。官方 `poppler` 包没有 desktop / 图标。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：在收集依赖前从构建环境的 Adwaita / hicolor 中选取已有的 `application-pdf` MIME 图标并 `export ICON`。不自绘品牌图，不改命令收集范围。
- 已知结果：已提交修复，未监控 Actions，构建结果待验证。

### 2026-09-18：Adwaita 50 没有 application-pdf 图标

- 日期：2026-09-18
- 现象：[run 35350625229](https://github.com/newyorkthink/linux-packaging/actions/runs/35350625229) 失败。日志：`找不到 application-pdf 图标`。
- 根因：Adwaita 50 的 MIME 图标没有 `application-pdf`，只有 `x-office-document` 等。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：ICON 改为明确路径 `/usr/share/icons/Adwaita/scalable/mimetypes/x-office-document.svg`。
- 已知结果：已提交，未监控 Actions。
