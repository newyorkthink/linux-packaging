# 腾讯会议 AppImage

## 用途与产物

本目录从腾讯会议官方 Linux x86_64 DEB 重封装为 `wemeet.AppImage`。正式构建入口为 `.github/workflows/build.yml` 通过 `.github/appimage-apps.json` 调度的标准 matrix Job。

## 技术栈与打包方式

腾讯会议为自带 Qt5 的闭源视频会议客户端。构建脚本读取 AUR `wemeet-bin` 的当前 `pkgver` 与 CDN MD5，下载官方 DEB，保留官方 `opt/wemeet/bin` 与厂商 Qt / 私有库，编译 AUR `wrap.c` 得到 `libwemeetwrap.so`，再用 quick-sharun 补齐 PulseAudio、X11 等外部系统库。

不把 AUR 包本身当作二进制来源；也不使用 AUR 启动脚本中的 bubblewrap 沙箱。

## 运行

```bash
./wemeet.AppImage
```

默认走 XCB / XWayland（与 AUR `wemeet` 包装脚本一致）。可用 `QT_QPA_PLATFORM` 覆盖。

NVIDIA 黑屏时可仅对该进程设置：

```bash
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json ./wemeet.AppImage
```

## 版本元数据

版本优先取官方 DEB `control` 中的 `Version`，否则使用 AUR `pkgver`，写入 `wemeet/dist/version.txt`。workflow 使用 `SOFTWARE_KEY=wemeet` 接入统一清单。

## 维护说明

- 继续通过 AUR `wemeet-bin` 动态发现官方 DEB 地址，不在仓库写死版本或 CDN 哈希。
- 最终 Release 资产名固定为 `wemeet.AppImage`。
- 保留厂商 Qt 与 `libwemeetwrap.so`，不要改成只用 Arch 系统 Qt。

## 变更记录

### 2026-09-17：新增腾讯会议 AppImage

- 来源：官方 DEB + AUR `wemeet-bin` 元数据 / `wrap.c`。
- 参考：https://aur.archlinux.org/packages/wemeet-bin
- 未加入冒烟测试或测试 workflow。
