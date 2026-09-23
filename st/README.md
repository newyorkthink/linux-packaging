# st AppImage

独立构建 siduck/st（基于 suckless st）的 AppImage；不改已有的 Rofi、Alacritty 或 i3 配置。构建时读取上游默认分支当前提交，产物为 dist/st.AppImage，version.txt 包含提交短 SHA。使用图形 X11 会话运行 st.AppImage 即可。

## 字体修改入口

只改本目录的 font-config.sh：ST_FONT_PRIMARY 是首选字体，ST_FONT_FALLBACKS 是按英文逗号分隔的后备字体，ST_FONT_PIXELS 是像素字号。默认首选 MonoLisa，中文用 WenQuanYi Zen Hei Mono 回退；这两个字体要由使用者自行安装，AppImage 不包含字体文件。以后加入其他字体时，将字体名称追加到 ST_FONT_FALLBACKS，再重新构建。安装后可用 fc-match 'MonoLisa' 和 fc-match 'WenQuanYi Zen Hei Mono' 检查字体是否存在；没有安装时 fontconfig 可能选别的字体。

构建后的主字体也可通过宿主机的 Xresources 覆盖：在 ~/.Xresources 中设置 st.font: MonoLisa:pixelsize=15，运行 xrdb -merge ~/.Xresources 后重开 st。此设置优先于构建默认值；改变字体回退列表或构建默认字号要改 font-config.sh 并重新构建。请注意旧的 st.font 配置可能会盖过新构建的默认字体。无需也不可向公开仓库提交 MonoLisa 字体文件。

## 运行和构建

图形会话运行 dist/st.AppImage；需要打开文件时可以显式执行 st.AppImage -e nvim /path/to/file，和原有 Rofi 搜索脚本互不依赖。构建脚本由仓库的标准 AppImage 工作流在 Arch 环境调用，使用 quick-sharun 打包，并包含 st-256color 的 terminfo。上游复制输出、处理 URL 的快捷键还会调用宿主机的 dmenu、xclip 等工具，使用这些快捷键前需要在宿主机安装相应程序。上游项目地址：https://github.com/siduck/st 。
