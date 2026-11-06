# st AppImage

独立构建 siduck/st（基于 suckless st）的 AppImage；不改已有的 Rofi、Alacritty 或 i3 配置。构建时读取上游默认分支当前提交，产物为 dist/st.AppImage，version.txt 包含提交短 SHA。使用图形 X11 会话运行 st.AppImage 即可。

## 字体修改入口

只改本目录的 font-config.sh：ST_FONT_PRIMARY 是首选字体，ST_FONT_FALLBACKS 是按英文逗号分隔的后备字体，ST_FONT_PIXELS 是像素字号。默认首选 MonoLisa，中文用 WenQuanYi Zen Hei Mono 回退；这两个字体要由使用者自行安装，AppImage 不包含字体文件。以后加入其他字体时，将字体名称追加到 ST_FONT_FALLBACKS，再重新构建。安装后可用 fc-match 'MonoLisa' 和 fc-match 'WenQuanYi Zen Hei Mono' 检查字体是否存在；没有安装时 fontconfig 可能选别的字体。

构建后的主字体也可通过宿主机的 Xresources 覆盖：在 ~/.Xresources 中设置 st.font: MonoLisa:pixelsize=15，运行 xrdb -merge ~/.Xresources 后重开 st。此设置优先于构建默认值；改变字体回退列表或构建默认字号要改 font-config.sh 并重新构建。请注意旧的 st.font 配置可能会盖过新构建的默认字体。无需也不可向公开仓库提交 MonoLisa 字体文件。

## 源码默认主题

默认采用赛博朋克 2077 风格配色：深蓝黑背景、冷白蓝文字、霓虹青、荧光粉和赛博黄 ANSI 颜色，透明度为 1.0。修改 `patches/theme-config.sh` 后重新构建，`patches/apply_theme_config.py` 会在字体配置生成后将主题写入 `config.h`。该主题只改变 st 自身的默认颜色，不修改 lf、tmux 的配置，也不会生成截图中的发光边框。宿主机已加载的 `st.background`、`st.foreground`、`st.cursorColor`、`st.color0` 至 `st.color15` 等 Xresources 值仍可覆盖源码默认色。

## 运行和构建

图形会话运行 dist/st.AppImage；需要打开文件时可以显式执行 st.AppImage -e nvim /path/to/file，和原有 Rofi 搜索脚本互不依赖。构建脚本由仓库的统一 AppImage 工作流在 Arch 环境调用，从 siduck/st 默认分支获取当前源码，读取 font-config.sh 的字体设置，并由 patches/apply_font_config.py 生成 config.h，再由 patches/apply_theme_config.py 写入源码默认主题；随后通过 make 安装、quick-sharun 打包，同时封装 st-256color 的 terminfo。专用打包流程及与标准模板的差异见 docs/template-deviations.md。上游复制输出、处理 URL 的快捷键还会调用宿主机的 dmenu、xclip 等工具，使用这些快捷键前需要在宿主机安装相应程序。上游项目地址：https://github.com/siduck/st 。

## 2026-09-24：实机确认能打开并输入

Linux 图形会话运行当时的 `st.AppImage`，终端窗口可以打开，shell 提示符正常，能输入。拼音输入时出现了中文候选框。

## 实机验证

### 2026-11-06：用户实机验证通过

用户已确认 st.AppImage 在 Linux 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 终端启动与 shell | 终端窗口、shell 提示符及命令输入正常。 |
| 目录列表 | ls 列表与目录名称的青色显示正常。 |
| 主题配色 | 深蓝黑背景及青、粉、黄高亮显示正常。 |
| lf | 三栏目录界面、当前项高亮和底部信息栏显示正常。 |
| tmux | zsh 窗口及底部状态栏显示正常。 |

本次核对的构建基线：[专用流程整理](https://github.com/newyorkthink/linux-packaging/commit/05357af0ac4a02b6bf0c4a3292987bf42e83e60c)、[源码默认主题](https://github.com/newyorkthink/linux-packaging/commit/e1e198cd2019f549a5a85836c0c55235e4524a7c)、[ANSI 配色调整](https://github.com/newyorkthink/linux-packaging/commit/c86a61e1278122c3af8a4091888b93806f746b6f)。对应 [Actions #1316](https://github.com/newyorkthink/linux-packaging/actions/runs/42221291483) 首次运行成功，Build st 的构建、发布和版本清单写入均已完成。
