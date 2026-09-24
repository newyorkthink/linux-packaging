# AppImage 直接运行时自定义协议不会登记

直接运行 AppImage 时，包内 `.desktop` 不会进入宿主的 `applications` 目录。登录、OAuth 或其它深度链接如果要用自定义协议把浏览器交回程序，系统就找不到处理程序，回调回不到程序。这是直接运行 AppImage 的限制，不是「程序写死了某个浏览器」。

后续应用碰到同类回调前先读本文，再读 [common/desktop/write_scheme_hook.sh](../common/desktop/write_scheme_hook.sh)。某个应用已经发生过什么，以该应用目录的 `README.md` 为准，不要抄进本文。

## 现象

程序打开登录页时，走的是系统默认网页浏览器。这是正常流程。不要改成在打包脚本里写死 Chromium、Firefox 或其它浏览器，也不要把「打开哪个浏览器」做成公共代码。

授权结束后，浏览器拿到 `协议名://...`。包内 desktop 即使已经写了 `MimeType=x-scheme-handler/<协议>` 和 `Exec=... %U`，只要宿主搜索不到这个文件，协议就没有登记。浏览器可能把地址当成搜索，或只弹出交给 `xdg-open`。回调不会进入 AppImage。

## 不要这样做

- 不要写死 AppImage 路径，包括下载目录、`/usr/local/bin` 或某次挂载目录。用户会移动或更换文件。
- 不要只改打进 AppImage 的 desktop，就认为宿主已经登记。
- 不要只调用 `xdg-mime default`。有的桌面环境没有实现自定义协议的默认处理程序设置。
- `Exec` 必须使用 `%U` 才能收到 URI。`%F` 只接收本地文件。
- 只登记应用自己的自定义协议。不要改 `mailto`、`http`、`https` 的现有默认程序。
- 协议名从上游 desktop 的 `MimeType` 读取。不要凭应用名编造。
- 某个程序自己的参数形状，例如浏览器把双斜杠收成单斜杠，留在该应用的启动参数 hook 里。不要放进公共登记脚本。

## 现用做法

公共入口是 `common/desktop/write_scheme_hook.sh`。构建脚本调用它，写出 `AppDir/bin/20-<应用>-protocol.hook`。quick-sharun 生成的 AppRun 会在 `set -e` 下 source 这个 hook，因此 hook 必须遵守：

- 不修改 `"$@"`。
- 失败不阻止启动。登记放在子 shell 里，并 `set +e`。
- 每次启动使用当时的 `$APPIMAGE`。可以 `readlink -f` 时，用解析后的实际文件。路径不写死。
- 将该路径写成用户级 desktop：`$XDG_DATA_HOME/applications/<文件名>.desktop`，未设置 `XDG_DATA_HOME` 时用 `~/.local/share/applications/`。`Exec` 是带引号的路径，后接 `%U`。
- 只在 `mimeapps.list` 的 `[Default Applications]` 中设置调用方传入的协议。
- 导出 `CHROME_DESKTOP`，让 Electron 的协议登记指向这个用户级 desktop，而不是挂载目录里的临时文件。

调用方传入 desktop 文件名、显示名、说明、图标名、窗口类、分类和协议。没有自定义协议的应用不要调用。

登记之后，回调是否真的回到程序，以实机为准。构建成功不算验证完成。
