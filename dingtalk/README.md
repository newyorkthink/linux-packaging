# DingTalk AppImage 稳定基线

## 基线状态

- 状态：稳定基线
- 基线日期：2026-08-06
- 架构：x86_64
- 构建环境：Ubuntu 24.04 GitHub Actions
- 上游来源：AUR `dingtalk-bin`
- 本次实测上游版本：`8.1.0.6021101-1`
- 输出文件：`DingTalk.AppImage`

工作流默认从 AUR 获取当前 `dingtalk-bin`。本基线记录的是 2026-08-06 在真实 Arch Linux + i3wm 环境完成验证的构建方案。

## 已确认功能

- AppImage 正常启动
- 扫码登录正常
- 登录后主界面正常
- 会话、消息和图片显示正常
- 文档、工作台等内嵌网页正常
- 视频会议窗口正常
- 摄像头和麦克风正常
- 退出后可以再次启动

## 稳定基线包含的关键处理

1. 使用 Arch Linux 容器从 AUR 生成并提取完整 `dingtalk-bin` 包。
2. 保留以下已经验证有效的 AUR 构建命令：

   ```bash
   su - builduser -c "cd /tmp/dingtalk-bin && makepkg --nodeps --noconfirm"
   ```

3. 保留钉钉官方运行目录结构，不拆分 Qt、CEF 和私有组件。
4. 将 `plugins/dtwebview` 加入运行库搜索路径，并预加载内置 `libcef.so`。
5. 清除钉钉 ELF 文件的可执行栈标记，兼容较新的内核和 glibc。
6. 递归收集主程序、插件、会议组件和私有库的外部动态库。
7. 打包同一 Ubuntu 软件包版本的完整 NSS 运行组件，避免 `libsoftokn3.so` 与 `libnssutil3.so` 符号版本冲突。
8. 仅从临时 AppImage 源目录移除不参与主程序运行、且依赖旧 `libpangox` 的诊断组件。
9. 修正 AUR desktop 文件中的重复键，再交给 `appimagetool`。
10. 构建前检查全部 ELF 动态库，构建后分别执行 AppDir 和最终 AppImage 图形启动测试。
11. 生成 SHA-256 校验文件和版本说明文件，并上传到日期 Release。

## 基线保护项

以下内容已经实际验证有效，后续没有明确故障时不要改写、替换或删除：

- AUR 的 `makepkg --nodeps --noconfirm` 命令及执行顺序
- `CEF_LIB_DIR`、`LD_LIBRARY_PATH` 和 `LD_PRELOAD` 处理
- 完整 NSS 运行组件复制步骤
- ELF 可执行栈清理步骤
- 动态库递归收集和缺失依赖检查
- desktop 重复键净化
- AppDir 与最终 AppImage 两阶段启动测试
- `ARCH=x86_64 appimagetool "$APPDIR" "$OUTFILE"` 打包命令

修改这些部分前，应先完整检查工作流、构建脚本和历史故障原因，避免通过多次 Actions 运行试错。

## 生成文件

```text
DingTalk.AppImage
DingTalk.AppImage.sha256
dingtalk-version.txt
```

校验：

```bash
sha256sum -c DingTalk.AppImage.sha256
```

运行：

```bash
chmod +x DingTalk.AppImage
./DingTalk.AppImage
```

## 日志说明

下列日志在程序继续正常工作的情况下属于非致命信息，不应单独作为重新打包依据：

```text
The resource ... was preloaded ... but not used
Failed to set crash key
rpc request fail ... timeout
```

出现以下内容时才应按致命运行错误处理：

```text
error while loading shared libraries
symbol lookup error
NSSUTIL_* not found
Segmentation fault
Illegal instruction
Could not load the Qt platform plugin
```

## 相关文件

```text
.github/workflows/build_dingtalk.yml
dingtalk/build_dingtalk.sh
dingtalk/README.md
```
