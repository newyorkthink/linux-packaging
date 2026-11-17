# 微信 AppImage

## 用途与产物

本目录从微信官方 Linux x86_64 DEB 动态取得程序并重新封装为 `wechat.AppImage`。正式构建入口为 [build_wechat.sh](./build_wechat.sh)，由 `.github/workflows/build.yml` 的 `Build WeChat` Job 在 Ubuntu 24.04 runner 上直接执行。

## 上游来源与打包方式

采用现有 [linuxdeploy GTK DEB 模板](../templates/appimage/linuxdeploy-gtk-deb.sh)，由仓库统一远端生成器原样生成构建脚本。公共入口从[微信官方动态地址](https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb)下载同一份 DEB，核对包身份和架构、安装后按原布局解包，版本读取 control 的完整 `Version`，不固定软件版本。

完整保留 `opt/wechat` 以及 WMPF、VLC、ffmpeg 等相邻私有资源。使用官方可显示的 `wechat.desktop` 和 PNG 图标，GTK3 插件部署运行资源；主 ELF 的依赖通过 `--deploy-deps-only` 明确收集，既有 PulseAudio 缺库处理继续保留。最终使用官方 `AppImage/appimagetool` 与 `AppImage/type2-runtime` 封装 SquashFS Type 2 AppImage，发布最终包。

程序专属的桌面资源、NSS/NSPR 和依赖准备见 [模板差异](./docs/template-deviations.md)。公共阶段、固定注释及内联 AppRun 遵循 [linuxdeploy 规范](../linuxdeploy_projects.md)。

## 运行

下载 Release 中的 `wechat.AppImage` 后赋予执行权限并直接运行：

```bash
./wechat.AppImage
```

界面语言、输入法和显示环境沿用程序及用户会话，不强制中文 locale、X11 或 Qt 缩放参数。此次迁移不改动微信上游源码。

## 版本元数据

最终封装成功后，公共入口统一写入 `wechat/dist/version.txt`。workflow 上传该文件为 `software-version-wechat`，发布 `latest/wechat.AppImage`，并通过既有公共 Action 增量更新 `latest/software_versions.json`。软件 key 和 Release 资产名保持为 `wechat`、`wechat.AppImage`。

## 当前迁移与验证状态

2026-11-18，用户反馈旧 quick-sharun / DwarFS 包启动后挂载进程持续占用 CPU，退出微信后仍未停止，手动结束对应 `memfd:dwarfs` 后系统负载下降。该现象支持更换此包的挂载与封装路线，但不能仅据此认定 DwarFS 的某个参数就是根因，也不能断言全部系统负载都来自微信。

本次已改用既有 linuxdeploy 流程和官方 SquashFS runtime，正式链路不再使用该 DwarFS 挂载进程。统一生成器已成功输出脚本；新包的启动、退出后负载、登录、消息、音视频和输入法尚未完成实机验证。生成成功不代表正式打包或运行验收成功。

## 维护说明

- 继续使用官网动态 DEB 和完整 control 版本，不手工固定旧版本。
- `build_wechat_old.sh` 是迁移前的逐字节备份，只供查阅历史；构建清单和正式 workflow 不调用它。
- 程序专属处理放在 `patches/`；可复用机制继续调用 `common/`，不复制下载、安装、封装和版本发布逻辑。
- 后续修改以实际故障为依据，不把旧版 sharun 的模块权限、路径覆盖或扫描整个私有目录的处理自动迁回标准脚本。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 不修改现有微信打包脚本。
- 构建脚本直接输出标准 `dist/version.txt`，workflow 只负责上传并接入统一版本清单。

### 2026-10-13：忽略官方隐藏的 WeChatAppEx desktop

- 现象：官方 4.1.13.26 deb 在 `usr/share/applications` 中同时有 `wechat.desktop` 和 `com.tencent.wechatappex.desktop`。后者 `NoDisplay=true`，`Exec` 指向 `RadiumWMPF/runtime/WeChatAppEx`。构建停在「应且只能找到一个 WeChat desktop 文件，实际为 2」。
- 根因：查找条件是 `*wechat*.desktop`，`wechatappex` 也被算进去。
- 修改：`wechat/build_wechat.sh` 跳过 `NoDisplay=true`，只把剩下的唯一可显示 desktop 当作主入口。
- 结果：已提交。构建和实机运行尚未验证。

### 2026-11-18：迁移到标准 linuxdeploy 与官方 SquashFS 封装

- 原样备份旧脚本，通过统一生成器采用现有 GTK DEB 模板，主程序保持在官方 `opt/wechat/wechat`。
- 原样复用工作区、APT、官方包下载与解包、工具准备、NSS/NSPR、最终封装和版本发布公共入口；只在应用阶段准备桌面资源及明确的依赖。
- 从通用 Arch matrix 调度迁到 Ubuntu 24.04 原生 Job，继续沿用原发布名、软件 key 和版本清单。
- 针对用户反馈的 DwarFS 挂载进程持续占用 CPU，更换最终文件系统与 runtime；当前验收边界见上文。
