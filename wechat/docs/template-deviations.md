# WeChat 标准模板参数与内联处理

## 标准入口

正式脚本以现有 [linuxdeploy-gtk-deb.sh](../../templates/appimage/linuxdeploy-gtk-deb.sh) 为底稿。按本次明确要求，少量 desktop、NSS/NSPR 和主程序依赖命令直接写在 [build_wechat.sh](../build_wechat.sh) 的对应分区，已删除独立准备脚本和 `prepare/finalize` 调用。

初始底稿生成记录：提交 `12d34a822bc9300a1c4d746202eab7b0a7c7e305`，[运行 44135140439 / 1](https://github.com/newyorkthink/linux-packaging/actions/runs/44135140439)。该次原始输出 SHA-256 为 `33a5474dcc03999ca8a2c5a78bcd8480fc96120d41724aaf0da58bf2f1b214b0`，仅作为内联整理前的历史依据。

| 参数或位置 | 本应用取值与原因 |
| --- | --- |
| 来源 | 官网动态 x86_64 DEB；公共下载入口接收官方 HTTPS URL，并在构建时核对预期包名 `wechat` 和架构 `amd64`。 |
| 官方摘要 | 当前调用未提供官方独立 SHA-256；公共入口记录本次下载摘要，不将自算摘要写成官方认证。 |
| 版本 | 直接沿用公共下载入口返回的完整 control `Version`，不再重复读取 DEB，不固定应用版本或去掉修订号。 |
| 目录 | 完整保留 `opt/wechat`，主程序为 `opt/wechat/wechat`，不再移到 `AppDir/bin`。 |
| GTK | 沿用本应用已有 GTK3 运行资源需求；使用 gtk 插件和 `DEPLOY_GTK_VERSION=3`，不据此声称微信全部组件都是 GTK，也不猜测其私有 Qt 主版本。 |
| AppRun | 保留模板中的完整内联 AppRun，真实程序目录在 `PATH` 与 `LD_LIBRARY_PATH` 前部；保留 `usr/bin`、`usr/lib`、`usr/share` 及标准 schemas/GIO 路径，直接执行主程序并传递参数。 |
| 构建 | Ubuntu 24.04 原生 runner；正式产物、软件 key 和版本清单入口沿用既有发布流程。 |
| 最终封装 | 公共入口使用官方 `AppImage/appimagetool` 和 `AppImage/type2-runtime`，生成 SquashFS Type 2 包；中间 AppImage 不发布。 |

## 主脚本中的必要处理

| 位置 | 处理与依据 |
| --- | --- |
| 下载并准备应用：desktop | 在解包后的 AppDir 内，将 `usr/share/applications/wechat.desktop` 设置为 `Exec=wechat %U`、`Icon=wechat`。linuxdeploy 从这份包内 desktop 部署根入口，只修改根副本会被覆盖。只规范主 desktop，官方原始 DEB 不变。 |
| 根 desktop 与图标 | 由 linuxdeploy 按包内 desktop 选择官方 `usr/share/icons` 中的 `wechat.png`，部署根 desktop 和图标；不额外复制根文件或遍历 PNG。最终 PNG 和权限整理继续交给公共入口。 |
| 下载并准备应用：NSS/NSPR | 直接调用 `common/linuxdeploy/copy_nss_runtime.sh` 并传入目标目录及 `--with-nspr`，在 linuxdeploy 扫描前准备同一构建环境的完整集合。 |
| 整理产物：依赖 | 真实 AppRun 和 GTK 部署完成后，直接用 `--deploy-deps-only` 处理 `opt/wechat/wechat`，并传入 `libpulse.so.0`、`libpulse-simple.so.0` 两项已有缺库依据的输入；传递依赖交给 linuxdeploy。 |

官方 linuxdeploy 默认扫描 `usr/bin`，并跳过软链接，不能靠 desktop 的绝对 `Exec` 或一个软链接替代 `opt/wechat` 主 ELF 的依赖部署。采用 `--deploy-deps-only` 可保留真实入口位置，避免复制另一份主程序；其设置的 RPATH 保留 `$ORIGIN` 并指向包内 `usr/lib`。[官方扫描逻辑](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/core/appdir.cpp#L793)、[官方参数实现](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/main.cpp#L168)。

依赖收集保留在 GTK 部署之后，沿用已生成的真实 AppRun。最终封装读取的是此次补齐后的同一 AppDir，不发布先前的中间包。以上少量命令已直接内联，独立 helper、阶段分派及重复版本读取均已删除。

## 私有组件与迁移边界

WMPF、WeChatAppEx、VLC、ffmpeg 和原生模块按官方相邻目录保留，不遍历全部私有 ELF 后交给工具扁平化，也不把多个不同用途的 `libffmpeg.so` 当成一份公共库。主 ELF 依赖收集仍可能复制其解析到的私有依赖，不能将本处理描述成“完全不复制私有库”。

旧 quick-sharun 的 `.node` 执行权限调整用于避免 sharun 包装原生模块；新流程没有 sharun，不自动恢复这一处理。旧版 `SHARUN_*`、强制 X11、Qt 缩放和 VLC 路径覆盖不混入标准 AppRun；完整历史仍保存在 `build_wechat_old.sh`。当前流程没有应用源码补丁。

用户反馈及新包验收状态见 [README](../README.md#当前迁移与验证状态)。
