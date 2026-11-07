# File Roller AppImage

## 用途与产物

本目录在 Ubuntu 24.04 构建 File Roller（文件压缩器）AppImage，固定产物为 `dist/file-roller.AppImage`。构建时从 Ubuntu 24.04 官方 APT 仓库获取当前 `file-roller`，应用版本不固定。当前 noble 包为 44.1，依赖 GTK 4 和 libadwaita。

## 技术栈与打包方式

File Roller 44 为 GTK 4 / libadwaita 应用。构建脚本以 [GTK Ubuntu 仓库模板](../templates/appimage/linuxdeploy-gtk-apt.sh) 生成。模板把 `DEPLOY_GTK_VERSION` 写成 3，生成后只把这一处改为 4。公共 APT 入口解包已安装版本的 `file-roller`，并把同为 Depends 的 `bzip2`、`unzip`、`zip` 解进 AppDir。linuxdeploy 通过 GTK 插件部署资源，公共封装入口生成最终 AppImage。差异见 [模板差异](./docs/template-deviations.md)。

## 运行

```bash
./dist/file-roller.AppImage
```

压缩命令优先使用包内 `usr/bin` 的 `bzip2`、`unzip` 和 `zip`。7z 不是该包的 Depends，仍按宿主环境查找。

## 版本元数据

公共 APT 解包入口返回实际主包版本，公共封装入口将它写入 `dist/version.txt`。GitHub Actions 在构建脚本成功退出后使用该文件上传版本元数据。

## 实机验证

尚未实机验证。正式构建结果以 Ubuntu 24.04 Job 为准。

## 变更记录

### 2026-11-07：按 GTK APT 模板新增

用仓库生成器从 GTK Ubuntu 仓库模板生成 `build_file-roller.sh`，随后只将 `DEPLOY_GTK_VERSION` 从 3 改为 4。验证范围是生成器退出码和 `bash -n`，没有在本机安装 Ubuntu 24.04 的 file-roller，也没有打出 AppImage。

### 2026-11-07：安装 GTK 4 开发包

[Build File Roller](https://github.com/newyorkthink/linux-packaging/actions/runs/42346868442/job/128326446164) 在第二次 linuxdeploy 调用 GTK 插件时失败。插件查询 `gtk4` 的 `libdir`，构建环境没有 `gtk4.pc`。重新生成时加入 `libgtk-4-dev`，`DEPLOY_GTK_VERSION` 仍为 4。这次只核对了生成结果和 `bash -n`，没有在本机重跑构建。

### 2026-11-07：深色主题、简体中文和 fcitx

实机是浅色英文，并提示没有匹配 `GTK_IM_MODULE=fcitx` 的模块。中文只按其他 linuxdeploy 脚本写：`prepare_locale.sh` 生成 `zh_CN.UTF-8`，AppRun 设置 `LOCPATH`、`LANG` 和 `LANGUAGE`。不改 ELF 里的 locale 路径。深色主题用 `GTK_THEME=Adwaita-dark`。GTK4 的 fcitx 模块写入 `giomodule.cache`。

### 2026-11-07：修正中文 locale 目录名

实机启动提示 `Locale not supported by C library`，界面退回 C，所以仍是英文。包内目录是 `zh_CN.UTF-8`，glibc 通过 `LOCPATH` 查找的是 `zh_CN.utf8`。生成目录改为 `zh_CN.utf8`。`LANG` 仍是 `zh_CN.UTF-8`。

### 2026-11-07：去掉 locale 路径补丁

[Build File Roller](https://github.com/newyorkthink/linux-packaging/actions/runs/42348331620) 在复制 `libfcitx5gclient.so*` 时失败，Ubuntu 上的文件名是 `libFcitx5GClient.so.2`。同时删除 `patches/relocate_locale_paths.py`，不再把 `/usr/share/locale` 改成相对路径。
