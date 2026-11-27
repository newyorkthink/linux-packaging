#!/usr/bin/env python3
from pathlib import Path
import hashlib
import sys

# 修补 5：Linux/X11/i3 Overlay 稳定修复。
# 这里故意校验固定汉化版 window.rs 的 SHA256；以后升级上游时如果该文件变化，
# 构建会在编译前停止，避免把旧 Overlay 逻辑强行覆盖到新源码。
root = Path(sys.argv[1])
path = root / "src-tauri/src/app/window.rs"
text = path.read_text()

expected_sha256 = "86565b3651f08b411ca61c439ba89978b824686d8172c9d91012dc637d15e670"
actual_sha256 = hashlib.sha256(text.encode()).hexdigest()
if actual_sha256 != expected_sha256:
    raise SystemExit(
        "错误：05_linux_overlay.py 检测到 window.rs 已变化，请先核对新版源码再更新补丁。"
    )

patched = '''pub fn config_window(window: &tauri::WebviewWindow) {
    #[cfg(not(target_os = "linux"))]
    window
        .set_ignore_cursor_events(true)
        .expect("Failed to set ignore cursor events");

    #[cfg(target_os = "windows")]
    {
        use windows::Win32::Foundation::HWND;
        use windows::Win32::UI::WindowsAndMessaging::{
            SetWindowPos, HWND_TOPMOST, SWP_NOMOVE, SWP_NOSIZE,
        };

        let hwnd = HWND(window.hwnd().unwrap().0 as isize);
        unsafe {
            let _ = SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
        }
    }

    #[cfg(target_os = "macos")]
    {
        if let Ok(Some(monitor)) = window.primary_monitor() {
            let position = monitor.position();
            let size = monitor.size();

            window
                .set_position(tauri::PhysicalPosition {
                    x: position.x,
                    y: position.y,
                })
                .unwrap();
            window
                .set_size(tauri::PhysicalSize {
                    width: size.width,
                    height: size.height,
                })
                .unwrap();
        }

        use cocoa::appkit::{NSWindow, NSWindowCollectionBehavior};
        use cocoa::base::id;

        unsafe {
            let ns_window = window.ns_window().unwrap() as id;
            ns_window.setLevel_(1000);

            ns_window.setCollectionBehavior_(
                NSWindowCollectionBehavior::NSWindowCollectionBehaviorCanJoinAllSpaces,
            );
        }
    }

    #[cfg(target_os = "linux")]
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
    }
}
'''

path.write_text(patched)
