# Webcamoid 固定配置

本文记录当前 [构建脚本](../build_webcamoid.sh) 和 [源码补丁](../patches/) 已使用的具体值；本次不新增或调整运行配置。当前实现基线为 d1b4475，实机结果统一见 [README](../README.md#实机验证)。

## 目录、资源与产物

| 固定内容 | 用途与依据 |
| --- | --- |
| webcamoid/webcamoid；work/source | 官方正式 Release 源码与本项目源码目录。版本由公共入口动态返回到 VERSION，不固定版本号。 |
| work/build；work/stage | 当前 CMake 构建目录与安装前缀，后续依赖收集和资源复制使用同一暂存目录。 |
| work/webcamoid.desktop；webcamoid | 构建时生成的 desktop 文件及 Exec、Icon、StartupWMClass 使用的应用标识。 |
| StandAlone/share/themes/WebcamoidTheme/icons/hicolor/256x256/webcamoid.png | 当前源码中的优先图标；缺失时在该主题目录选择同名 PNG/SVG。 |
| /usr/lib/qt6/bin/qmake、lrelease、lupdate | 当前 Qt 6 构建工具路径；qmake 优先使用 command -v qmake6 的结果。 |
| dist/webcamoid.AppImage；dist/version.txt | 已登记的稳定产物名与公共版本元数据接口。 |

## 编译、部署与兼容开关

| 固定内容 | 作用 | 记录依据 |
| --- | --- | --- |
| CMAKE_BUILD_TYPE=Release；DAILY_BUILD=OFF；NOCHECKUPDATES=ON | 正式构建并关闭应用更新检查。 | 当前 CMake 调用。 |
| NOFFMPEG=OFF；NOLIBUVC=OFF；NOPIPEWIRE=OFF；NOQTCAMERA=OFF；NOV4L2=OFF；NOV4LUTILS=OFF | 保留相应已安装后端。 | 当前 CMake 调用及实机日志中的插件注册。 |
| NOGSTREAMER=ON；NOLIBAVDEVICE=ON；NOWLROOTS=ON | 关闭历史记录涉及的后端。 | [原有错误与处理记录](./error.md)。 |
| 移除 DesktopCapture 的 PipeWire/wlroots 插件及名称含 GStreamer 的安装插件 | 与上述后端处理配套，不关闭音频 PipeWire。 | [桌面捕获及 GStreamer 记录](./error.md#桌面捕获-pipewire-和-wlroots)。 |
| DEPLOY_QT=1；DEPLOY_QML=1；DEPLOY_PIPEWIRE=1；DEPLOY_PULSE=1；DEPLOY_OPENGL=1；DEPLOY_GSTREAMER=0 | 配置 quick-sharun 的依赖部署。 | 当前脚本；OpenGL 还需结合下文的部署后移除步骤理解。 |
| NO_STRIP=1 | 保留未剥离符号的文件。 | 当前脚本已有设置；历史材料没有保存对应 strip 故障原文，不据此推断插件失败根因。 |

依赖扫描前的 LD_LIBRARY_PATH 优先加入 work/stage/lib，并保留已有值。额外收集当前暂存库、Qt 的 multimedia/styles/platformthemes，以及 libpulsecommon、libpxbackend 私有库；复制后执行 sharun -g。实际命令与阶段见 [模板差异](./template-deviations.md)。

## .env 中的运行配置

这些是当前应用的具体配置，不是供其他程序直接照抄的通用示例。

| 配置 | 当前值 | 实际用途 |
| --- | --- | --- |
| LANG | zh_CN.UTF-8 | 设置运行时语言环境。 |
| LANGUAGE | zh_CN:zh | 设置翻译语言顺序。 |
| WEBCAMOID_FORCE_DARK | 1 | 启动时触发源码补丁，将 QSettings 配色写为 Adwaita Dark。 |
| QT_STYLE_OVERRIDE | Adwaita-Dark | 指定 Qt 控件样式。 |
| QT_MEDIA_BACKEND | ffmpeg | 指定 Qt Multimedia 的 FFmpeg 后端。 |
| QT_QUICK_BACKEND | rhi | 指定 Qt Quick 使用 RHI 后端。 |
| QSG_RHI_BACKEND | opengl | 指定 RHI 使用 OpenGL。 |
| QSG_RENDER_LOOP | basic | 指定 Qt Quick 基本渲染循环。 |
| QT_OPENGL | desktop | 请求桌面 OpenGL 实现。 |
| LIBGL_DRIVERS_PATH、LIBVA_DRIVERS_PATH、VDPAU_DRIVER_PATH | 空值 | 清空继承的相关驱动路径。 |
| __EGL_VENDOR_LIBRARY_DIRS、__EGL_VENDOR_LIBRARY_FILENAMES | 空值 | 清空继承的 EGL vendor 路径覆盖。 |
| VK_DRIVER_FILES、VK_ICD_FILENAMES | 空值 | 清空继承的 Vulkan ICD 文件覆盖。 |

脚本在依赖收集后还移除 libEGL、libGL、libGLX、libGLdispatch、libOpenGL、libgbm、libdrm、libvulkan 对应文件，以及 dri、glvnd/egl_vendor.d、vulkan/icd.d 目录。这是当前应用的精确移除清单，不等于声明包内没有任何图形组件，也不作为其他应用的默认处理。

现有脚本没有生成包内中文 locale 或设置 LOCPATH 的命令；本文只记录其实际 LANG/LANGUAGE 配置，不把它描述为已经完成标准模板的包内 locale 生成步骤。

## 源码替换与历史材料

四个补丁的目标文件、预期原文和替换行为由 [补丁文件](../patches/) 保存，作用与影响见 [模板差异](./template-deviations.md#四个源码补丁)。硬件编码器筛选和后端关闭的既有报错片段完整保留在 [error.md](./error.md)，正常运行结果保留在 README。缺少的旧故障全文不以提交标题、正常日志或推断补造。
