# 微信 AppImage

## 用途与产物

本目录从微信官方 Linux x86_64 DEB 动态取得程序并重新封装为 `wechat.AppImage`。正式构建入口为 [build_wechat.sh](./build_wechat.sh)，由 `.github/workflows/build.yml` 的 `Build WeChat` Job 在 Ubuntu 24.04 runner 上直接执行。

## 上游来源与打包方式

以现有 [linuxdeploy GTK DEB 模板](../Templates/appimage/linuxdeploy-gtk-deb.sh) 为底稿，少量桌面资源和依赖部署命令直接写在主构建脚本的对应分区。公共入口从[微信官方动态地址](https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb)下载同一份 DEB，核对包身份和架构、安装后按原布局解包，版本读取 control 的完整 `Version`，不固定软件版本。

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

当前采用既有 linuxdeploy 流程和官方 SquashFS runtime。首次正式构建的 desktop 绝对 `Icon` 路径问题已修正，必要命令直接内联主脚本。用户已确认当前包运行稳定，Linux 实机通过结果见 [实机验证](#实机验证)。

## 维护说明

- 继续使用官网动态 DEB 和完整 control 版本，不手工固定旧版本。
- 少量 desktop、NSS/NSPR 和主程序依赖部署命令直接写在 `build_wechat.sh`，不另设 `prepare/finalize` 脚本；公共机制继续调用 `common/`。版本直接沿用官方 DEB 公共入口的返回值。
- 后续修改以实际故障为依据，不把旧版 sharun 的模块权限、路径覆盖或扫描整个私有目录的处理自动迁回标准脚本。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 不修改现有微信打包脚本。
- 构建脚本直接输出标准 `dist/version.txt`，workflow 只负责上传并接入统一版本清单。

### 2026-10-13：忽略官方隐藏的 WeChatAppEx desktop

- 现象：官方 4.1.13.26 deb 在 `usr/share/applications` 中同时有 `wechat.desktop` 和 `com.tencent.wechatappex.desktop`。后者 `NoDisplay=true`，`Exec` 指向 `RadiumWMPF/runtime/WeChatAppEx`。构建停在「应且只能找到一个 WeChat desktop 文件，实际为 2」。
- 根因：查找条件是 `*wechat*.desktop`，`wechatappex` 也被算进去。
- 修改：`wechat/build_wechat.sh` 跳过 `NoDisplay=true`，只把剩下的唯一可显示 desktop 当作主入口。
- 结果：主入口选择已调整，后续通过结果见 [实机验证](#实机验证)。

### 2026-11-18：迁移到标准 linuxdeploy 与官方 SquashFS 封装

- 原样备份旧脚本，通过统一生成器采用现有 GTK DEB 模板，主程序保持在官方 `opt/wechat/wechat`。
- 原样复用工作区、APT、官方包下载与解包、工具准备、NSS/NSPR、最终封装和版本发布公共入口；只在应用阶段准备桌面资源及明确的依赖。
- 从通用 Arch matrix 调度迁到 Ubuntu 24.04 原生 Job，继续沿用原发布名、软件 key 和版本清单。
- 针对用户反馈的 DwarFS 挂载进程持续占用 CPU，更换最终文件系统与 runtime；迁移后的通过结果见 [实机验证](#实机验证)。

### 2026-11-18：修正 linuxdeploy 重新部署 desktop 后的绝对图标路径

- 现象：[首次正式构建](https://github.com/newyorkthink/linux-packaging/actions/runs/44136394716/job/134227063762) 停在中间 AppImage 的图标准备，提示 `Icon 名无法放到 AppDir 根目录：/usr/share/icons/hicolor/512x512/apps/wechat`。当时尚未执行 `finalize`。
- 原因：准备阶段只规范了根 `wechat.desktop`，linuxdeploy 随后从 `usr/share/applications/wechat.desktop` 重新部署根文件，覆盖了已修改的 `Icon`。
- 修改：先在 AppDir 内规范实际输入 desktop 的 `Exec` 和 `Icon`；根 desktop 和图标交给 linuxdeploy 部署，删除重复的根文件复制及 PNG 遍历。原始 DEB、生成器输出和公共工具保持原样。
- 当时仍通过 `prepare` / `finalize` 调用保留必要操作；后续已将命令内联并删除独立脚本，见下一条记录。后续通过结果见 [实机验证](#实机验证)。

### 2026-11-18：将少量准备命令直接内联到主构建脚本

- 删除 `patches/prepare_wechat_appdir.sh` 及两个阶段调用，不保留参数分派、入口检查或重复的 DEB 版本读取。
- 解包后直接规范实际 desktop，并调用公共 NSS/NSPR 入口；GTK 部署后直接执行主 ELF 和 PulseAudio 依赖收集，先后顺序保持原样。
- 保留标准公共阶段和完整内联 AppRun，桌面与图标仍由 linuxdeploy 部署；当前实现及依据见 [模板差异](./docs/template-deviations.md)。后续通过结果见 [实机验证](#实机验证)。

### 2026-11-18：实机验证后确认构建配置

- 用户确认当前包运行稳定。
- 正式构建中的 `MULTIARCH`、主程序 `--deploy-deps-only` 和两个 PulseAudio 库部署命令保持原样。

### 2026-11-18：固定 linuxdeploy 的微信主桌面入口

- [失败构建](https://github.com/newyorkthink/linux-packaging/actions/runs/44240228763/job/134586089679) 自动选中了隐藏的 WeChatAppEx 桌面入口。中间 AppImage 封装因该入口缺少 `Categories` 中止。

```text
WARNING: No desktop file specified, using first desktop file found: AppDir/usr/share/applications/com.tencent.wechatappex.desktop
[appimage/stderr] Categories entry not found in desktop file
[appimage/stderr] ::error::.desktop file is missing a Categories= key
```

- [成功构建](https://github.com/newyorkthink/linux-packaging/actions/runs/44139808896/job/134239292899) 使用相同的 DEB 4.1.13.26、linuxdeploy 和 appimagetool，当时两次均自动选中了 `wechat.desktop`。
- GTK 封装和后续主程序依赖部署均显式指定 `wechat.desktop`。辅助桌面文件和 WeChatAppEx 程序随包保留。

## 实机验证

### 2026-11-18：用户实机验证通过

用户已确认 WeChat AppImage 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 启动与主界面 | 程序正常启动，登录后的主界面和会话列表正常显示。 |
| 中文输入 | 中文输入候选框正常显示，输入框能够输入中文。 |
| 深色界面 | 主界面及相关页面正常显示深色样式。 |
| 小程序页面与视频画面 | 小程序页面正常显示，视频窗口能够显示视频画面。 |
| 运行稳定性与进程负载 | 用户确认当前包运行稳定；两张进程监控截图中，wechat 与 WeChatAppEx 的 CPU 读数均为 0.0%。 |

#### 运行观察

- 启动输出可见 IBus surrounding-text 能力提示，同次实测中文候选与中文输入正常。
- 进程监控中旧 memfd:dwarfs 的跟踪栏显示 Dead，当前微信使用包内 opt/wechat 主程序。
