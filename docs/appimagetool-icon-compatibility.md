# appimagetool 图标检查与 SVG 兼容处理

## 上游变更与适用范围

本说明针对官方 appimagetool 最终封装阶段的根图标处理。应用自身的 SVG 图标可以继续保留，不需要全部替换为 PNG。

[上游提交 b082d2e](https://github.com/AppImage/appimagetool/commit/b082d2ecf7fed993f672b297e168de182a7c7437) 修改了 `src/appimagetool.c` 的图标选择和检查逻辑：

| 项目 | 变更前 | 变更后 |
| --- | --- | --- |
| 根据 desktop 的 `Icon` 字段选择根图标 | 依次检查同名 PNG、SVG、XPM | 优先 PNG，其次 XPM，不再主动选择 SVG |
| 已有 `.DirIcon` | 存在检查和链接处理没有保证最终目标有效 | 保留已有普通文件；可用 PNG / XPM 替换已有链接；没有可选根图标时回退到已有 `.DirIcon` |
| 最终有效性检查 | 未执行新增的完整检查 | `.DirIcon` 缺失、链接失效或最终目标不是普通文件时终止封装 |

[对应源码](https://github.com/AppImage/appimagetool/blob/b082d2ecf7fed993f672b297e168de182a7c7437/src/appimagetool.c#L944) 说明：SVG 难以解析，文件管理器和缩略图工具不能可靠处理，因此优先使用 PNG，XPM 作为最后选择。[AppDir 官方规范](https://docs.appimage.org/reference/appdir.html) 也将 `.DirIcon` 定义为 PNG，同时允许应用图标使用 SVG。

准确结论是：新版加强了 `.DirIcon` 的有效性检查，并取消了从 SVG 自动生成 `.DirIcon` 的选择分支。这不等于禁止 AppDir 包含 SVG，也不等于所有只有 SVG 的 AppDir 都必然封装失败；上游仍会接受已有且最终指向普通文件的有效 `.DirIcon`。检查链接目标是否为普通文件，不代表检查了图像格式或实际显示效果。

以上固定 commit 仅用于定位本次核实的变更和源码，不用于锁定构建工具。构建仍通过现有公共下载入口动态取得官方 continuous 资产。

## 仓库公共处理

`common/linuxdeploy/package_appimage.sh` 在原有 appimagetool 命令之前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`。直接使用 appimagetool 的项目也可以复用这个准备入口。

准备入口只接收一个 AppDir 路径，保持现有处理顺序：

1. 检查传入目录，只对该 AppDir 执行既有权限处理，不沿软链接修改包外文件。
2. 根据根目录主 desktop 的 `Icon` 字段确定图标名称；名称必须能对应 AppDir 根目录中的文件，绝对路径等不合法名称会报错。
3. 根目录已有同名 PNG 或 XPM 时直接保留，不覆盖图标。
4. 否则优先复制包内同名 PNG；没有 PNG 时，再将包内同名 SVG 转为 256 × 256 的 PNG，放入 AppDir 根目录。
5. 保留原 SVG；转换工具不可用、转换失败或结果不是 PNG 时明确失败。

这是仓库为适配上游图标选择和桌面显示而采用的兼容处理。准备入口不自行创建或改写 `.DirIcon`，由随后执行的 appimagetool 按自身规则选择或保留它。既有 `.DirIcon` 若是普通文件，上游仍会保留该文件，不能把补入 PNG 描述为必然覆盖已有 `.DirIcon`。

已有根 PNG / XPM 或可复制的包内 PNG 时不需要 SVG 转换工具。只有实际进入 SVG 转换分支时才需要相应工具。

## Ubuntu 构建依赖

Ubuntu 的 [librsvg2-bin 软件包](https://packages.ubuntu.com/en/noble/graphics/librsvg2-bin) 提供 `rsvg-convert`。需要从 SVG 补 PNG 的 Ubuntu 项目，应在应用自己的 `common/apt/install_packages.sh` 调用中追加 `librsvg2-bin`。

转换工具按现有实现依次选择 `rsvg-convert`、`magick`、`convert`，任意一个可用即可；不要求同时安装三套工具。依赖由应用构建脚本安装，公共图标准备入口不自动安装软件包，也不修改统一基础包。

转换发生在构建环境中，不要求最终使用者安装这些转换工具，也不需要把转换程序额外复制进 AppDir。

## 中间产物与最终产物

linuxdeploy 的 AppImage 输出插件与最终独立调用的 appimagetool 属于两个封装阶段，使用的工具版本可以不同。中间 AppImage 生成成功，不能代替最终封装成功。

日志出现以下错误时，表示仓库公共准备入口已进入 SVG 转换分支，但构建环境没有可用的转换工具：

```text
错误：没有可用的 SVG 转 PNG 工具，需要 rsvg-convert、magick 或 convert；Ubuntu 构建环境可安装 librsvg2-bin（提供 rsvg-convert）。
```

这是公共准备入口的缺包提示，不是 appimagetool 本体发出的错误。应补齐当前构建环境的转换依赖，保留已确认的 SVG、AppRun、linuxdeploy 命令和最终封装命令，不通过发布中间产物绕过最终封装。
