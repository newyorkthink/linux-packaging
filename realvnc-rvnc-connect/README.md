# RealVNC Connect AppImage

## 用途与产物

本目录将官方最新稳定版 x64 DEB 中的 RealVNC Connect Flutter bundle 重新封装，Release 资产固定为 `rvncconnect.AppImage`，版本写入 `dist/version.txt`。

## 技术栈与打包方式

直接在 Ubuntu 24.04 runner 构建。沿用本仓库 linuxdeploy 标准：空 AppDir 初始化，公共入口下载、核对官方 SHA-256、安装并解包同一份 DEB，写完整根 AppRun，再运行 GTK3 linuxdeploy 生成中间 AppImage，最后由官方 appimagetool 与明确的 Type 2 runtime 封装发布产物。SVG 图标的 PNG 转换由现有公共封装链路处理。

版本和摘要动态解析自 [RealVNC 官方校验页面](https://help.realvnc.com/hc/en-us/articles/27252822630301-SHA256-checksums-for-RealVNC-Connect-v8)，下载来自 `downloads.realvnc.com`；不经过 AUR，也不固定某个应用版本。统一清单键仍为 `realvnc_connect`。

## 运行

```bash
./rvncconnect.AppImage
```

主入口直接执行包内 `usr/lib/rvncconnect/rvncconnect`，保留相邻 `lib`、`data`、Flutter AOT 和官方辅助程序。默认保持 GTK 深色主题与 Fcitx5 输入；已有 `APPIMAGE_GTK_THEME`、`GTK_IM_MODULE` 和 `XMODIFIERS` 可覆盖对应默认值。输入法服务由宿主机提供。

当前未确认产品提供中文界面，沿用宿主语言，不强制中文 locale。输入中文与界面翻译分别处理，不能通过生成 locale 增加产品翻译。

浏览器隔离保留在本项目 `patches/prepare_runtime.sh` 生成的 `usr/bin/xdg-open` 中：恢复宿主 PATH、共享数据和原有库路径，清除包内 GTK/GIO 等变量。以后确认其他程序有相同需求，再考虑公共化；当前不新增公共隔离脚本。

完整布局、依赖取舍及专属处理见 [标准模板差异](docs/template-deviations.md)。Ubuntu 24.04 的依赖不再承诺旧 Ubuntu 22.04 / GLIBC 2.35 基线。包内保留上游服务及 PAM 文件不代表运行 AppImage 会安装系统服务或完成远程控制服务配置。

## 验证状态

已用官方 DEB 验证 bundle 保存与恢复、桌面文件处理、隔离入口及参数传递，并检查脚本和 workflow。启动与浏览器环境使用替身验证，未执行完整应用构建、真实 GUI、登录或远程连接测试；后续 Actions 和实际运行结果另行确认。

## 变更记录

### 2026-11-02：对齐 linuxdeploy 标准

移除 Arch/AUR 与 Ubuntu 容器流程，改用 Ubuntu 24.04 专用 job 和官方 DEB 公共入口。根 AppRun 直接运行原始 Flutter 程序，两个专属 patches 保留 bundle 恢复、宿主浏览器隔离及既有 glibc/GPU 排除规则。构建阶段使用 `NO_STRIP=1`，避免破坏 Flutter AOT；最终封装与版本保存复用公共入口。

此前失败出在最终 appimagetool 拒收指向 SVG 的 `.DirIcon`，报错为 `appimagetool: no AppImage was created because .DirIcon is not valid.`。现在复用已修正的公共 PNG 处理链路，不在本项目重复下载工具或另写图标转换逻辑；本次完整构建结果尚待确认。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据和发布映射，不改动现有 Flutter bundle、Ubuntu 22.04、GLIBC、Fcitx5、GTK 或 xdg-open 稳定逻辑。
