# Webcamoid 模板差异与注释核对

## 当前流程与依据

核对基线为 [d1b4475](https://github.com/newyorkthink/linux-packaging/blob/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552/webcamoid/build_webcamoid.sh)。实际运行结果统一见 [README 实机验证](../README.md#实机验证)。

当前是 Arch 构建环境中的源码专用流程：公共入口取得最新稳定 Release 标签与源码，应用四个补丁，CMake + Ninja 安装到 `work/stage`，再由 quick-sharun 收集依赖、生成启动入口并封装。应用清单中的 `kind: standard` 表示使用统一 Arch matrix 调度，不代表本脚本逐字符合某份构建模板。

[qt-installed.sh](../../templates/quick-sharun/qt-installed.sh) 使用系统已安装程序，[qt-deb.sh](../../templates/quick-sharun/qt-deb.sh) 使用独立下载的官方 DEB；两者均不包含当前源码适配和暂存安装流程。本文登记现有实现，不新增模板，不改变二进制优先或构建脚本生成规则。

## 相对模板保留的处理

| 阶段 | 实际处理 | 用途与影响 |
| --- | --- | --- |
| 准备依赖 | 存在 ffmpeg-mini 时先移除，再通过公共 Arch 入口安装基础包和列明的运行、编译依赖。 | 使用完整 FFmpeg；这些操作发生在 CI 构建容器。 |
| 准备工作区 | 调用 prepare_x86_64_workspace.sh，清理 AppDir、work、dist，并重建 work 与 dist。 | x86_64 检查及目录清理由公共入口负责。 |
| 取得版本与源码 | download_latest_stable_release_source.sh 返回标签到 VERSION，源码放入 work/source。 | 动态跟随官方正式 Release，不递归获取 ExtraPlugins。 |
| 源码适配 | 执行 patches/ 下四个 Python 补丁。 | 作用见下一节，不能当作通用 Qt 步骤复制。 |
| 编译与安装 | CMake + Ninja 安装到 work/stage，关闭 GStreamer、libavdevice 和 wlroots。 | 现有源码路线的专属阶段；桌面捕获插件按既有清单移除，音频 PipeWire 保留。 |
| 桌面资源 | 在 work 中生成 desktop，从源码主题选择官方图标。 | 未从系统安装的 webcamoid 包取得桌面文件；图标使用源码资源。 |
| 依赖收集 | 一次传入主程序、ffmpeg、ffprobe、v4l2-ctl、暂存插件、选定 Qt 插件和私有库。 | 明确保留实际扫描目标；不等同于 pkgforge 的系统入口收集命令。 |
| 安装资源补入 | 复制暂存 lib/share、multimedia/styles/platformthemes 插件及选中的私有库。 | 保留动态加载插件的相对布局；随后执行 AppDir/sharun -g 重新生成路径。 |
| 图形与运行环境 | 删除列明的图形库和驱动目录，追加既有 .env 配置。 | 实际取值及影响见 [固定配置](./hardcoded.md)。 |
| 封装与版本保存 | quick-sharun --make-appimage 后调用 save_appimage_version.sh。 | 最终产物非空后才写 dist/version.txt；保持既有顺序。 |

## 四个源码补丁

| 文件 | 实际行为 | 影响 |
| --- | --- | --- |
| [default_dark_theme.py](../patches/default_dark_theme.py) | 将配色默认值设为 Adwaita Dark，并在 WEBCAMOID_FORCE_DARK 非零时写入 QSettings。 | 开关启用时会在启动阶段写入主题设置，不只是改变首次启动的默认值。 |
| [disable_single_instance.py](../patches/disable_single_instance.py) | 将 isSecondInstance() 改为始终返回 false。 | 关闭这项单实例检测。 |
| [prefer_real_camera.py](../patches/prefer_real_camera.py) | 从 V4L2 输入列表过滤 Dummy、loopback、v4l2loopback；已保存设备不在列表时转到首个可用设备。 | 实际是过滤虚拟输入，而非仅调整设备排序。 |
| [skip_hardware_encoders.py](../patches/skip_hardware_encoders.py) | 名称含 nvenc、qsv、amf、vaapi、vulkan、v4l2m2m 时直接返回不可用。 | 对应编码器不会进入可用列表；软件编码器保留。 |

上述补丁来自本仓库现有实现，不标为 pkgforge 官方原样代码。补丁均在匹配预期源码后替换；源文本或配色替换数量不匹配时会退出，避免静默套用到不同源码。

## 注释核对

严格模式、工作目录、基础包、版本读取、ARCH、OUTPATH、OUTNAME、STARTUPWMCLASS、依赖收集、最终封装和版本保存等通用注释，与 [固定注释标准](../../docs/quick-sharun-comments.md) 中对应原文一致。专属兼容步骤使用现有 `# 本仓库兼容处理：` 来源标注。

主构建脚本仍有以下说明与实际操作需要分开理解：

- 补丁调用前的总注释没有提到关闭单实例检测，实际仍执行该补丁。
- DEPLOY_GSTREAMER=0 的注释保留“插件编了，运行库没带”的旧现象；当前实际同时使用 NOGSTREAMER=ON 并移除对应安装插件。
- NO_STRIP=1 的确定作用是不剥离符号；现有材料没有对应剥离操作导致插件加载失败的原始日志，不把注释理由补写成已证实根因。
- DEPLOY_OPENGL=1 先用于工具部署，后续还有按清单删除图形库和驱动目录的步骤，最终内容应以完整执行链说明。

本次只补充四个 Python 补丁的中文用途注释。主构建脚本的既有注释与命令一起保留；其后续修改仍须通过仓库生成器，不手工改写。

## 上游打包关系

pkgforge 当前的系统包、ffmpeg-mini、GStreamer、自更新及 zsync 配置与本仓库流程不同。源码原文、采用与未启用项见 [pkgforge 打包差异](./pkgforge-differences.md)，不因补写文档恢复这些处理。
