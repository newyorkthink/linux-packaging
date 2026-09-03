
## 修复记录

### 2026-09-02：改为直接复用官方 tar 包内 desktop / icon

- 官方 tar 本身已经包含完整的 `moderncsv.desktop`、`moderncsv.png`、主程序、`lib/`、`plugins/` 和 `qt.conf`。
- 直接复用官方 desktop、icon 和真实主程序，不额外生成替代文件。

### 2026-09-02：隔离官方 Qt6 runtime，修复 GNU_PROPERTY 启动错误

- 不再安装 Arch 当前 `qt6-base`、`qt6-5compat`、`fcitx5-qt` 后与官方 Qt runtime 混装。
- 只保留官方 Qt runtime 所需的非 Qt 系统依赖。

### 2026-09-03：简化为 AppDir/bin 直接打包

- 删除 `/usr/lib/moderncsv`、`$PWD/moderncsv-source` 等额外 staging 路径。
- 官方 tar 去掉最外层目录后直接完整解压到 `AppDir/bin/`。
- 删除 `QT_LOCATION`，直接执行 `quick-sharun ./AppDir/bin/moderncsv`。

### 2026-09-03：移除测试代码

- 删除构建脚本中的 `xvfb-run`、`timeout`、`SMOKE_RC` 和 smoke log 判断代码。
- Modern CSV 构建脚本只保留实际打包所需步骤，最后直接执行 `quick-sharun --make-appimage`。

### 2026-09-03：修正官方 tar staging 到 AppDir/shared/bin

- 实际运行旧产物时，Qt 从 `bin/plugins/` 加载 plugin，出现 `Plugin uses incompatible Qt library (5.12.0)`，并伴随 `No functional TLS backend was found`。
- 根因是完整官方目录被直接放入 `AppDir/bin/`，与 quick-sharun 将 `AppDir/bin/` 用作 sharun 启动入口、将真实程序放入 `AppDir/shared/bin/` 的布局发生冲突。
- `build_moderncsv.sh` 现将官方 tar 完整解压到 `AppDir/shared/bin/`，并改为执行 `quick-sharun ./AppDir/shared/bin/moderncsv`；官方 `lib/`、`plugins/`、`qt.conf` 与真实程序继续保持同级相对关系。
- 当前已完成脚本与目录结构修正；新产物的实际运行结果以本次构建完成后的实机反馈为准。

### 2026-09-03：校准 quick-sharun 通用基础环境

- `build_moderncsv.sh` 将原先拆分的最小依赖改为仓库 quick-sharun 通用基础依赖集合，并保持单条 `yay -S --noconfirm ...` 安装命令。
- 基础环境补齐 Qt6、GTK3/GTK4、Fcitx5/IBus、Fcitx5 Rime、IBus Rime、TLS/OpenSSL、X11/XCB、Wayland、OpenGL、字体、图标、SVG/QML/Multimedia、打印和主题插件相关包。
- 官方 Modern CSV 的 `lib/`、`plugins/`、`qt.conf` 目录布局不改；本次只校准构建期依赖环境，不新增测试代码。

### 2026-09-03：固定通用基线与项目额外依赖分离

- `build_moderncsv.sh` 的 Qt6 通用基础命令改为仓库统一基线，并按约每 10 个包换行，避免依赖列表挤成单行。
- 通用基线补齐 `glycin`、`libheif`、`ca-certificates-utils`、`egl-wayland`、`libice`、`libsm`、`libinput`、`qt6-translations`、`fcitx5-gtk` 等组件，并移除 `ibus` / `ibus-rime`。
- 当前 Modern CSV 没有基线之外的额外软件包；后续项目特有依赖必须单独使用独立 `yay` 命令，不得改写或混入通用基础命令。
- 官方 Modern CSV 的 `lib/`、`plugins/`、`qt.conf` 布局和现有 quick-sharun 打包主线保持不变。

### 2026-09-03：精简 Qt6 通用基线中的兼容/开发组件

- 从 quick-sharun Qt6 通用基础环境中先移除 `qca-qt6`、`qt6-5compat`、`qt6-tools`；其余 Qt6 基线暂不调整。
