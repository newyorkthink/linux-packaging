# OBS Studio 写死的路径

这些路径写死，是因为它们不会从 `/usr/bin/obs` 的动态库依赖里被收进来。

## `/usr/lib/obs-modules`

- 为什么写死：OBS 33 已经没有 `/usr/lib/obs-plugins`。模块在这个目录，例如 `core/obs-browser.so`。
- 写死的内容：`/usr/lib/obs-modules`
- 作用：和主程序同一次交给 `quick-sharun`。
- 当初报错全文：

```text
'/usr/lib/obs-plugins' is NOT present!
Process completed with exit code 1.
```

当时检测到的版本是 OBS Studio 33.0.0。

## `/usr/share/obs`

- 为什么写死：模块的语言、浏览器页面和主题在这个数据目录。
- 写死的内容：`/usr/share/obs`
- 作用：把这些数据一起收进包。
- 当初报错：同上。旧脚本还写了 `/usr/lib/cef`。OBS 33.0.0 的官方包文件列表里没有这个路径。

## `/usr/bin/obs-ffmpeg-mux`

- 为什么写死：这是 OBS 录制时自己拉起的程序。
- 写死的内容：`/usr/bin/obs-ffmpeg-mux`
- 作用：和主程序一起进包。
- 当初报错：同上。构建停在不存在的插件目录，还没有跑到缺这个程序。
