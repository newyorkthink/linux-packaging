# WeChat 标准模板参数与应用阶段

## 标准入口

正式脚本使用现有 [linuxdeploy-gtk-deb.sh](../../templates/appimage/linuxdeploy-gtk-deb.sh)，由[统一远端生成器](../../scripts/build/generate_build_script.md#统一远端生成入口)输出，未手写改动生成结果。

本次生成来源为提交 `12d34a822bc9300a1c4d746202eab7b0a7c7e305`，[运行 44135140439 / 1](https://github.com/newyorkthink/linux-packaging/actions/runs/44135140439)，输出 SHA-256 为 `33a5474dcc03999ca8a2c5a78bcd8480fc96120d41724aaf0da58bf2f1b214b0`。

| 参数或位置 | 本应用取值与原因 |
| --- | --- |
| 来源 | 官网动态 x86_64 DEB；公共下载入口接收官方 HTTPS URL，并在构建时核对预期包名 `wechat` 和架构 `amd64`。 |
| 官方摘要 | 当前调用未提供官方独立 SHA-256；公共入口记录本次下载摘要，不将自算摘要写成官方认证。 |
| 版本 | 同一份 DEB 的完整 control `Version`，不固定应用版本、不去掉发行版修订号。 |
| 目录 | 完整保留 `opt/wechat`，主程序为 `opt/wechat/wechat`，不再移到 `AppDir/bin`。 |
| GTK | 沿用本应用已有 GTK3 运行资源需求；使用 gtk 插件和 `DEPLOY_GTK_VERSION=3`，不据此声称微信全部组件都是 GTK，也不猜测其私有 Qt 主版本。 |
| AppRun | 原样使用模板中的完整内联 AppRun，真实程序目录在 `PATH` 与 `LD_LIBRARY_PATH` 前部；保留 `usr/bin`、`usr/lib`、`usr/share` 及标准 schemas/GIO 路径，直接执行主程序并传递参数。 |
| 构建 | Ubuntu 24.04 原生 runner；正式产物、软件 key 和版本清单入口沿用既有发布流程。 |
| 最终封装 | 公共入口使用官方 `AppImage/appimagetool` 和 `AppImage/type2-runtime`，生成 SquashFS Type 2 包；中间 AppImage 不发布。 |

## 应用阶段

[prepare_wechat_appdir.sh](../patches/prepare_wechat_appdir.sh) 接入生成器已有的 `APPLICATION_PREPARE` 和 `APPLICATION_FINALIZE`，不增加模板、AppRun 或手造 hook。

| 阶段 | 处理与依据 |
| --- | --- |
| prepare：桌面入口 | 取官方 `usr/share/applications/wechat.desktop`，保留原文件，只在根副本设置 `Exec=wechat %U`、`Icon=wechat`。不把 `NoDisplay=true` 的 WeChatAppEx 辅助入口当作主程序，保留 2026-10-13 故障对应的取舍。 |
| prepare：图标 | 从官方 `usr/share/icons` 中选取文件体积最大的 `wechat.png` 复制到根目录，不绘制替代图标。最终 PNG 和权限整理仍交给公共入口。 |
| prepare：NSS/NSPR | 复用 `common/linuxdeploy/copy_nss_runtime.sh --with-nspr`，部署同一构建环境的核心库、动态加载模块和配套校验文件，在 linuxdeploy 扫描前准备完整集合。 |
| prepare：返回值 | stdout 只返回同一份 DEB 的完整版本，准备日志写入 stderr，符合标准阶段接口。 |
| finalize：依赖 | 模板已生成真实 AppRun 并完成 GTK 部署后，再用 `--deploy-deps-only` 明确处理 `opt/wechat/wechat`，并传入 `libpulse.so.0`、`libpulse-simple.so.0` 两项已有缺库依据的输入；传递依赖交给 linuxdeploy。 |

官方 linuxdeploy 默认扫描 `usr/bin`，并跳过软链接，不能靠 desktop 的绝对 `Exec` 或一个软链接替代 `opt/wechat` 主 ELF 的依赖部署。采用 `--deploy-deps-only` 可保留真实入口位置，避免为填充 `usr/bin` 复制另一份主程序；其设置的 RPATH 保留 `$ORIGIN` 并指向包内 `usr/lib`。[官方扫描逻辑](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/core/appdir.cpp#L793)、[官方参数实现](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/main.cpp#L168)。

依赖部署放在 finalize，是为了让这次 linuxdeploy 调用沿用已经存在的真实 AppRun，避免在入口尚未创建时按 `/opt/...` 的 desktop 字段选择失败。最终封装读取的是此次补齐后的同一 AppDir，不发布先前的中间包。

## 私有组件与迁移边界

WMPF、WeChatAppEx、VLC、ffmpeg 和原生模块按官方相邻目录保留，不遍历全部私有 ELF 后交给工具扁平化，也不把多个不同用途的 `libffmpeg.so` 当成一份公共库。主 ELF 依赖收集仍可能复制其解析到的私有依赖，不能将本处理描述成“完全不复制私有库”。

旧 quick-sharun 的 `.node` 执行权限调整用于避免 sharun 包装原生模块；新流程没有 sharun，不自动恢复这一处理。旧版 `SHARUN_*`、强制 X11、Qt 缩放和 VLC 路径覆盖不混入标准 AppRun；完整历史仍保存在 `build_wechat_old.sh`。当前流程没有应用源码补丁，`patches/` 中的脚本只负责本应用的资源准备与依赖部署。

用户反馈及新包验收状态见 [README](../README.md#当前迁移与验证状态)。旧包退出后 DwarFS 挂载进程持续占用 CPU 的现象，是本次更换封装与 runtime 的依据；没有将某个 DwarFS 参数认定为已证实根因，也未把新运行结果记为通过。
