#!/usr/bin/env python3
from pathlib import Path
import sys

# 修补 5：为官方 window.rs 补充 Linux/X11/i3 Overlay 窗口处理。
# 仅对 config_window 中确切锚点做唯一匹配替换，保留上游 Windows 与 macOS 逻辑；
# 若上游已新增 Linux 分支或改动对应调用，会在编译前主动报错并停止。
root = Path(sys.argv[1])
path = root / "src-tauri/src/app/window.rs"
text = path.read_text()

if '#[cfg(target_os = "linux")]' in text:
    raise SystemExit(
        "错误：05_linux_overlay.py 检测到 window.rs 已包含 Linux 分支，请先人工核对新版源码。"
    )

old_top = '''    window
        .set_always_on_top(true)
        .expect("Failed to set always on top");

    window
        .set_ignore_cursor_events(true)
        .expect("Failed to set ignore cursor events");'''

new_top = '''    #[cfg(not(target_os = "linux"))]
    window
        .set_always_on_top(true)
        .expect("Failed to set always on top");

    #[cfg(not(target_os = "linux"))]
    window
        .set_ignore_cursor_events(true)
        .expect("Failed to set ignore cursor events");'''

old_show = '    window.show().expect("Failed to show window");'

new_show = '''    #[cfg(target_os = "linux")]
    {
        use gtk::prelude::*;

        if let Ok(Some(monitor)) = window.primary_monitor() {
            let position = monitor.position();
            let size = monitor.size();

            window
                .set_position(tauri::PhysicalPosition {
                    x: position.x,
                    y: position.y,
                })
                .expect("Failed to set Linux overlay position");
            window
                .set_size(tauri::PhysicalSize {
                    width: size.width,
                    height: size.height,
                })
                .expect("Failed to set Linux overlay size");
        }

        // Tauri 与 GTK 两层都禁止覆盖层获取键盘焦点。
        window
            .set_focusable(false)
            .expect("Failed to make Linux overlay non-focusable");

        let gtk_window = window
            .gtk_window()
            .expect("Failed to get GTK window for Linux overlay");
        gtk_window.set_accept_focus(false);
        gtk_window.set_focus_on_map(false);

        // 主窗口初始 visible=false。先 realize 取得 GdkWindow，再在 map 前设置
        // override-redirect，使 i3/X11 WM 不接管覆盖层，也不会生成可聚焦的平铺/浮动容器。
        gtk_window.realize();
        let gdk_window = gtk_window
            .window()
            .expect("Failed to realize GDK window for Linux overlay");
        gdk_window.set_accept_focus(false);
        gdk_window.set_focus_on_map(false);
        gdk_window.set_override_redirect(true);
    }

    window.show().expect("Failed to show window");

    #[cfg(target_os = "linux")]
    {
        use gtk::prelude::*;

        // 必须在 show/map 之后应用。Tauri/tao 的 Linux 实现会设置 GDK input shape，
        // 让鼠标点击直接落到下面的终端、浏览器等真实窗口。
        window
            .set_ignore_cursor_events(true)
            .expect("Failed to enable Linux click-through");

        let gtk_window = window
            .gtk_window()
            .expect("Failed to get GTK window after show");
        let gdk_window = gtk_window
            .window()
            .expect("Failed to get GDK window after show");

        // unmanaged 覆盖层保持在最上层；点击穿透由 Tauri input shape 单独负责。
        gdk_window.raise();
    }'''

if text.count(old_top) != 1 or text.count(old_show) != 1:
    raise SystemExit(
        "错误：05_linux_overlay.py 与当前 Keyviz window.rs 不匹配，请先检查新版源码差异。"
    )

text = text.replace(old_top, new_top, 1)
text = text.replace(old_show, new_show, 1)
path.write_text(text)
