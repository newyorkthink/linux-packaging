#!/usr/bin/env python3
"""Linux 补丁：窗口图标固定为 resources/gemini.png。

任务切换器主要认 desktop。这里仍覆盖 BrowserWindow 的 icon，
避免上游留下的 Windows 图标路径让 _NET_WM_ICON 继续是 Electron 原子图。
不改尺寸、背景色或其它选项。上游变成 ESM，或主入口已有标记时，构建停止。
"""

import json
import sys
from pathlib import Path

MARKER = "linux-packaging-gemini-window-icon"
SNIPPET = r"""/* linux-packaging-gemini-window-icon */
;(() => {
  try {
    const electron = require("electron");
    const fs = require("fs");
    const path = require("path");
    const candidates = [];
    if (process.env.GEMINI_ICON_PATH) candidates.push(process.env.GEMINI_ICON_PATH);
    candidates.push(
      path.join(process.resourcesPath, "gemini.png"),
      path.join(path.dirname(process.execPath), "resources", "gemini.png"),
      path.join(path.dirname(process.execPath), "..", "bin", "resources", "gemini.png"),
    );
    let icon = electron.nativeImage.createEmpty();
    for (const candidate of candidates) {
      if (!candidate || !path.isAbsolute(candidate) || !fs.existsSync(candidate)) continue;
      const loaded = electron.nativeImage.createFromPath(candidate);
      if (!loaded.isEmpty()) {
        icon = loaded;
        break;
      }
    }
    if (icon.isEmpty()) return;
    const apply = (window) => {
      try { window.setIcon(icon); } catch (error) {}
    };
    const wrap = (name) => {
      const Original = electron[name];
      if (typeof Original !== "function") return;
      function Wrapped(options, ...rest) {
        const opts = options && typeof options === "object" ? { ...options, icon } : { icon };
        return new Original(opts, ...rest);
      }
      Wrapped.prototype = Original.prototype;
      Object.setPrototypeOf(Wrapped, Original);
      for (const key of Object.getOwnPropertyNames(Original)) {
        if (key === "prototype" || key === "length" || key === "name") continue;
        const desc = Object.getOwnPropertyDescriptor(Original, key);
        if (desc) Object.defineProperty(Wrapped, key, desc);
      }
      const current = Object.getOwnPropertyDescriptor(electron, name);
      try {
        if (current && current.configurable) {
          Object.defineProperty(electron, name, {
            configurable: true,
            enumerable: current.enumerable !== false,
            get: () => Wrapped,
          });
        } else {
          electron[name] = Wrapped;
        }
      } catch (error) {}
    };
    wrap("BaseWindow");
    wrap("BrowserWindow");
    if (electron.app && typeof electron.app.on === "function") {
      electron.app.on("browser-window-created", (_event, window) => apply(window));
    }
    setInterval(() => {
      const lists = [electron.BaseWindow, electron.BrowserWindow];
      for (const ctor of lists) {
        if (!ctor || typeof ctor.getAllWindows !== "function") continue;
        for (const window of ctor.getAllWindows()) apply(window);
      }
    }, 500);
  } catch (error) {}
})();
"""

if len(sys.argv) != 2:
    raise SystemExit(f"用法：{sys.argv[0]} <已提取的 app.asar 目录>")

root = Path(sys.argv[1]).resolve()
package_path = root / "package.json"
if not package_path.is_file():
    raise SystemExit("Gemini app.asar 里没有 package.json")

package = json.loads(package_path.read_text(encoding="utf-8"))
if package.get("type") == "module":
    raise SystemExit("Gemini 主入口已改成 ESM，当前图标补丁不能注入")

main = package.get("main")
if not isinstance(main, str) or not main.strip():
    raise SystemExit("Gemini package.json 没有 main")

entry = (root / main).resolve()
if not entry.is_relative_to(root):
    raise SystemExit(f"Gemini main 路径超出 app.asar：{main}")
if not entry.is_file():
    raise SystemExit(f"找不到 Gemini 主入口：{main}")
if entry.suffix.lower() not in {".js", ".cjs"}:
    raise SystemExit(f"Gemini 主入口不是 CommonJS：{main}")

text = entry.read_text(encoding="utf-8")
if MARKER in text:
    raise SystemExit("Gemini 主入口已经有窗口图标补丁")

icon_choice = "Su.existsSync(e)?e:t"
if icon_choice not in text:
    raise SystemExit("Gemini 主入口没有原来的 icon.ico 选择，不能改成包外 PNG")
text = text.replace(icon_choice, "process.env.GEMINI_ICON_PATH||t", 1)

entry.write_text(SNIPPET + text, encoding="utf-8")
print(f"Patched Gemini window icon into {main}")
