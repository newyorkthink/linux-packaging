# dconf Editor 写死项记录

## AppRun 深色主题

`GTK_THEME=Adwaita-dark` 固定 dconf Editor AppImage 使用 Adwaita 深色主题。此前 AppImage 可启动且中文界面正常，但窗口显示为浅色。按用户要求沿用 [Joplin 的主题设置](../../joplin/build_joplin.sh)，构建时随包部署对应 GTK 主题和图标资源。该设置仅作用于此 AppImage 的启动环境。
