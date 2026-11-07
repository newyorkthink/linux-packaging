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

### 2026-11-07：用户实机验证通过

用户执行 `software_update update file-roller -f`，覆盖安装 44.3 后在 Linux 实机确认。对应构建是 [Build AppImages #42349990943](https://github.com/newyorkthink/linux-packaging/actions/runs/42349990943)，提交 [6992f04](https://github.com/newyorkthink/linux-packaging/commit/6992f04)。

| 实测项目 | 通过结果 |
| --- | --- |
| 深色主题 | 主窗口和文件选择对话框都是深色。 |
| 简体中文界面 | 标题为“文件压缩器”，按钮为“提取”。文件选择框显示“最近使用”“主目录”“桌面”“取消”“打开”。 |
| 中文输入 | 文件选择搜索框弹出 Fcitx5 候选，并显示中文。 |

启动日志仍有 `Error creating IO channel for /proc/self/mountinfo: 权限不够`。这次确认没有把它当作界面、主题或输入失败。终端启动是中文，rofi 启动是英文。

### 2026-11-07：rofi 和终端都退回英文

`LC_ALL=zh_CN.UTF-8` 在这台机器上触发 `Locale not supported by C library`，GTK 退回 C 后不再读中文译文。改成 `C.UTF-8` 后没有这行警告，界面仍然是英文。现恢复终端里已经显示中文的设置：`LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并在启动时清掉继承来的 `LC_ALL` 和 `LC_MESSAGES`，避免 rofi 把界面盖回英文。

## 变更记录

### 2026-11-07：按 GTK APT 模板新增

用仓库生成器从 GTK Ubuntu 仓库模板生成 `build_file-roller.sh`，随后只将 `DEPLOY_GTK_VERSION` 从 3 改为 4。验证范围是生成器退出码和 `bash -n`，没有在本机安装 Ubuntu 24.04 的 file-roller，也没有打出 AppImage。

### 2026-11-07：安装 GTK 4 开发包

[Build File Roller](https://github.com/newyorkthink/linux-packaging/actions/runs/42346868442/job/128326446164) 在第二次 linuxdeploy 调用 GTK 插件时失败。插件查询 `gtk4` 的 `libdir`，构建环境没有 `gtk4.pc`。重新生成时加入 `libgtk-4-dev`，`DEPLOY_GTK_VERSION` 仍为 4。这次只核对了生成结果和 `bash -n`，没有在本机重跑构建。

### 2026-11-07：深色主题、简体中文和 fcitx

实机是浅色英文，并提示没有匹配 `GTK_IM_MODULE=fcitx` 的模块。中文只按其他 linuxdeploy 脚本写：`prepare_locale.sh` 生成 `zh_CN.UTF-8`，AppRun 设置 `LOCPATH`、`LANG` 和 `LANGUAGE`。不改 ELF 里的 locale 路径。深色主题用 `GTK_THEME=Adwaita-dark`。GTK4 的 fcitx 模块写入 `giomodule.cache`。

### 2026-11-07：放入简体中文译文

只设置 `LANG` 时界面仍是英文。file-roller、GTK 和 libadwaita 的译文路径是绝对的 `/usr/share/locale`，这台机器上没有这些 `.mo`。按 dconf-editor 的做法复制 Ubuntu 简体中文语言包，并把 ELF 中的路径改成相对路径。仍然不设置 `LOCPATH`。

[c233926](https://github.com/newyorkthink/linux-packaging/commit/c233926) 把目录改成 `zh_CN.utf8` 后，实机仍提示 `Locale not supported by C library`。这台机器的 C 库加载不了 Ubuntu 24.04 生成的 locale 数据，而 `LOCPATH` 会挡住系统自己的 `zh_CN.UTF-8`。现去掉 `LOCPATH` 和包内 locale，只保留 `LANG=zh_CN.UTF-8` 与 `LANGUAGE=zh_CN:zh`。

### 2026-11-07：去掉 locale 路径补丁

[Build File Roller](https://github.com/newyorkthink/linux-packaging/actions/runs/42348331620) 在复制 `libfcitx5gclient.so*` 时失败，Ubuntu 上的文件名是 `libFcitx5GClient.so.2`。同时删除 `patches/relocate_locale_paths.py`，不再把 `/usr/share/locale` 改成相对路径。
