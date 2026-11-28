# Zotero 模板差异

Zotero 采用 Arch Linux x86_64 和 quick-sharun。Arch Extra 已提供 `zotero`，可用于准备构建系统的程序和依赖。生成 AppImage 所用的程序、桌面资源及版本来自另行下载的官网 tar 包。现有 [Arch 原生模板](../../Templates/quick-sharun/arch-native.sh) 扫描系统安装的程序并读取 pacman 版本，固定 DEB 模板也不覆盖此 tar 包的 Mozilla 启动器及版本布局。当前流程复用公共安装、下载、解包和版本入口。 [Zotero 安装说明](https://www.zotero.org/support/installation#official_tarball) · [Arch Extra 软件包](https://archlinux.org/packages/extra/x86_64/zotero/)

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 通过公共 Arch 安装入口安装 `zotero` 及运行依赖，再用公共下载和解包入口取得官网正式版 Linux x86_64 tar 包。 [构建位置](../build_zotero.sh#L13-L24) |
| 程序与桌面资源 | 将完整的 `Zotero_linux-x86_64` 目录复制到 `AppDir/bin/`，从该程序目录取得官方 desktop 与图标。沿用 `Exec=zotero -url %U`，由官方启动器向 `zotero-bin` 传递应用配置与命令行参数。 [构建位置](../build_zotero.sh#L27-L33) · [官方 Linux 启动器](https://github.com/zotero/zotero/blob/main/app/linux/zotero) |
| 依赖部署 | quick-sharun 扫描 `zotero-bin`、`hostname`、NSS、PKCS#11 及 GTK3 的 IBus 和 Fcitx5 输入模块，保留 OpenGL 部署，并在包内生成中文 locale。 [构建位置](../build_zotero.sh#L50-L71) |
| 版本 | 从同一份归档的 `app/application.ini` 读取 `Version`，交给公共版本入口。成品成功生成后保存至 `dist/version.txt`。 [版本读取](../build_zotero.sh#L55-L58) · [版本保存](../build_zotero.sh#L77) |

路径及参数见[固定配置](./hardcoded.md)，产物与使用方式见[应用说明](../README.md)，实测结果见[实机验证](../README.md#实机验证)。
