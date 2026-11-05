# Webcamoid 运行时多余后端

这亞不是构建失败。构建已经成功，问题出在启动后的插件和编码器探测。

## 硬件编码器和 Dummy loopback

报错原文：

- `Testing video codec: av1_nvenc`、`h264_nvenc`：`Driver does not support the required nvenc API version. Required: 13.1 Found: 12.2`
- `av1_qsv`、`h264_qsv`、`vp9_qsv`：`Error creating a MFX session: -9`
- `av1_amf`、`h264_amf`：`DLL libamfrt64.so.1 failed to open`
- `vaapi`、`vulkan`：`Specified pixel format yuv420p is not supported`
- `h264_v4l2m2m`、`hevc_v4l2m2m`、`vp8_v4l2m2m`：`Using device /dev/video0`，`Dummy video device`，`VIDIOC_REQBUFS failed: 无效的参数`

发生阶段：程序启动后枚举 FFmpeg 编码器。

触发条件：打包了 Arch 的完整 FFmpeg。Webcamoid 对每个编码器调用 `avcodec_open2`。

原因：这些编码器依赖本机 NVIDIA、Intel Media SDK、AMD AMF 或可用的 loopback 设备。当前环境没有。软件编码 libx264、SVT-AV1、libvpx 可用。

处理：在 `videoencoderffmpegelement.cpp` 的探测入口跳过名称含 `nvenc`、`qsv`、`amf`、`vaapi`、`vulkan`、`v4l2m2m` 的编码器。cmake 增加 `-DNOLIBAVDEVICE=ON`，避免再用 libavdevice 打开 `/dev/video0`。摄像头仍走 V4L2。

## 桌面捕获 PipeWire 和 wlroots

报错原文：

- `Can't load plugin: libDesktopCapture_pipewire.so`
- `Can't load plugin: libDesktopCapture_wlroots.so`

发生阶段：启动加载插件。

原因：这两个桌面捕获插件编进来了，运行时缺库或会话条件不满足。Xlib 和 Qt 屏幕捕获可以加载。音频 PipeWire 可以加载，所以不能用 `NOPIPEWIRE` 一起关掉。

处理：`-DNOWLROOTS=ON`。安装后删除 `libDesktopCapture_pipewire.so` 和 `libDesktopCapture_wlroots.so`。不关闭音频 PipeWire。

## GStreamer

报错原文：

- `MultimediaSource/MultiSrc/Impl/* -> MultimediaSource/MultiSrc/Impl/GStreamer`
- 构建参数 `DEPLOY_GSTREAMER=0`，没有带 GStreamer 运行库

发生阶段：启动注册播放后端。

原因：源码默认会编 GStreamer 后端，打包却不带它的运行库。

处理：`-DNOGSTREAMER=ON`，并删除安装结果里名称含 gstreamer 的插件。

处理状态：已改 `webcamoid/build_webcamoid.sh`。这次改动尚未重新构建。
