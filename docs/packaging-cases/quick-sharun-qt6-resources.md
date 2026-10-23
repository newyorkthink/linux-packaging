# quick-sharun 与 Qt6 的资源路径：翻译存在但界面找不到

记录日期：2026-10-23。关键词：KeePassXC、Qt5、Qt6、quick-sharun、sharun、中文界面、Language、System default、shared/bin、AT_EXECFN、`.env`。

本文记录一次有实际 AppImage 对照的资源路径问题，供后续人和 AI 检索。应用当前实现、修复历史和验证状态以 [KeePassXC README](../../keepassxc/README.md) 为准；其他应用须核对自己的资源查找逻辑，不能看到 Qt6 就套用本方案。

## 现象与产物证据

KeePassXC 更新到 2.8.0 / Qt6 后，界面没有中文，语言选择只剩系统默认。中文输入正常。故障包内实际存在 `share/keepassxc/translations/keepassxc_zh_CN.qm`，共有 48 个应用翻译文件，因此“没打包中文翻译”不是本次原因。

| 对照项 | 旧版正常包 | 本次故障包 |
| --- | --- | --- |
| KeePassXC / Qt | 2.7.12 / 5.15.19 | 2.8.0 / 6.12.0 |
| AppImage 字节数 | 110184767 | 114371590 |
| 真实程序 | `AppDir/shared/bin/keepassxc` | `AppDir/shared/bin/keepassxc` |
| sharun 启动入口 | `AppDir/bin/keepassxc` | `AppDir/bin/keepassxc` |
| 中文翻译 | 顶层 `share/keepassxc/translations/`，231350 字节 | 同一相对位置，243765 字节 |
| `shared/share` | 不存在 | 不存在 |
| 原 `.env` | 只有 `CROSS_LIBC_DLOPEN_ROOT=${SHARUN_DIR}` | 与旧版逐字相同 |

旧版 AppImage 的 SHA-256 为 `1afcebfcba4e6961f7390c3c374d049c6f76b6ac32aa820b09a5767eff529f55`。故障 AppImage 的 SHA-256 为 `0156ccadf69fbbe33b41c23443083e782ac076aa6ec00bfd7f8e389f18a112d6`，来自 [KeePassXC 构建任务](https://github.com/newyorkthink/linux-packaging/actions/runs/39886798034/job/120196791017) 对应的 `latest/keepassxc.AppImage`。`latest` 会更新，后续核对以哈希和实际文件为准，不能把本文观察扩大到所有新版产物。

## 为什么旧 Qt5 不需要额外链接

sharun 的普通 ELF64 启动方式使用 userland-execve，在当前进程内加载动态加载器和真实程序。此时进程的 `/proc/<pid>/exe` 仍指向 sharun 入口，而加载器设置的 `AT_EXECFN` 指向真实程序，两条路径不同。

| 获取程序路径的方式 | 本次实际得到的路径 | KeePassXC 的相对资源路径 |
| --- | --- | --- |
| 旧 Qt5 从 `/proc/<pid>/exe` 读取 | `AppDir/bin/keepassxc` | `AppDir/bin/../share/keepassxc`，存在 |
| 本次 Qt6 优先从 `getauxval(AT_EXECFN)` 读取绝对路径 | `AppDir/shared/bin/keepassxc` | `AppDir/shared/bin/../share/keepassxc`，缺失 |

Qt6 在本次路径判断中走了不同的分支，但 KeePassXC 2.7.12 和 2.8.0 的 `Resources::Resources()` 查找逻辑相同。它先尝试编译时数据目录 `share/keepassxc`，再尝试程序目录下的 `../share/keepassxc` 和安装前缀路径；失败后还会尝试 `../share`、`../../share`。

故障包最终找到顶层 `AppDir/share`，却把它当成应用数据根目录，随后查找 `AppDir/share/translations`；真正的翻译在 `AppDir/share/keepassxc/translations`。`Translator::availableLanguages()` 扫描错误目录，只能留下代码预置的系统默认选项。词表等同属该应用数据目录，也会受路径选择影响。

所以本次是 quick-sharun 布局与当前 Qt6 程序路径判断之间的适配问题；没有据此认定 Qt 上游存在 Bug，也没有修改 Qt、KeePassXC 源码或二进制。旧 Qt5 得到的是 `bin` 入口，不是加载器所在的 `lib` 目录。

## 修复：资源路径与默认语言分别处理

在首次 quick-sharun 生成 AppDir 后、`quick-sharun --make-appimage` 前增加相对链接：

```text
AppDir/shared/share -> ../share
```

这样 `shared/bin/../share/keepassxc` 会访问现有的顶层应用资源，无须复制翻译、改变工作目录或重写 AppRun。尤其不要通过启动时 `cd` 到 AppDir 来掩盖查找问题，否则可能改变用户传入的相对数据库路径含义。

链接解决“能否找到翻译”。默认选中文则按 [仓库 GUI 规则](../../anylinux_projects.md) 在包内生成 `lib/locale/zh_CN.utf8`，再追加以下内容到既有 `.env`：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
```

必须保留 quick-sharun 原有 `.env` 内容，保持 `${SHARUN_DIR}` 为运行时相对定位，不写构建机绝对路径，不设置 `LC_ALL`。已有应用语言配置仍由 KeePassXC 处理。仅补环境变量不能修复本次错误的翻译目录；旧包的中文能用也不代表它已自行配置这些变量。中文输入法是另一个链路，本次用户已确认正常，没有改其选择和部署逻辑。

## 临时对照检查与验证边界

在云端隔离临时目录使用原始旧包、原始故障包和修复副本，从 AppDir 外部启动。使用 offscreen Qt 平台、独立 HOME / XDG / 配置目录，不打开数据库，每次限定 5 秒后结束进程。

环境禁止 `strace` 的 ptrace 调用，外部读取进程映射也受限，因此没有把这些失败尝试记为通过。实际对照使用仓库外临时文件访问探针，借 sharun 的 `SHARUN_ALLOW_LD_PRELOAD=1` 仅在检查进程中记录 `statx` / `open64` 和程序路径；探针不改变文件访问结果。没有把探针、该环境变量、测试文件或日志写入正式打包脚本和仓库。

| 检查 | 实际结果 |
| --- | --- |
| 旧 Qt5 包，配置 `Language=zh_CN` | 从 `bin/../share/keepassxc` 找到数据，成功打开 `keepassxc_zh_CN.qm` |
| 故障 Qt6 包，相同语言配置 | `shared/bin/../share/keepassxc` 不存在，尝试错误的 `share/translations`，未打开中文翻译 |
| 修复副本，相同语言配置 | 通过资源链接找到应用数据，成功打开中文翻译及词表 |
| 修复副本，配置 `Language=system`，外部初始语言为英文 | `.env` 在应用进程中展开为包内中文环境和 locale 路径，成功打开中文翻译 |
| 资源与 `.env` 静态核对 | 链接可访问全部 48 个应用翻译文件；原 `.env` 内容保留 |
| 提交前检查 | 构建脚本语法、完整 diff、文档相对链接通过；临时检查内容不入仓库 |

定时结束返回 124 表示检查时间到，不是“构建成功”；翻译判断依据是实际文件访问结果。以上只验证已有 AppImage 临时副本中的资源访问和默认语言选择，没有验收新构建产物、可见语言下拉框、完整桌面交互或实机输入法。提交后未监控 Actions，新构建及实机运行结果未验证。

## 后续遇到类似问题时

先核对翻译是否存在、Qt 实际版本、真实程序与 sharun 入口位置，以及应用自己的资源查找源码。工作目录下恰好存在资源，或宿主安装了 `/usr/share/keepassxc`，可能掩盖本次问题；不能仅凭在构建环境里能启动就下结论。

只有确认应用确实按真实程序目录查找、现有顶层资源完整且目标位置缺失时，才考虑本例的相对链接。不要批量修改其他 Qt 应用、固定旧 Qt 或默认设置更多环境变量；具体方案仍须遵守 AGENTS.md 的逐次授权要求。

## 上游依据

- [Qt5 QCoreApplication 源码](https://github.com/qt/qtbase/blob/v5.15.2/src/corelib/kernel/qcoreapplication.cpp)：程序路径读取逻辑；本次 Qt 5.15.19 实际二进制也核对了相同方向的调用。
- [Qt 6.12.0 QCoreApplication 源码](https://github.com/qt/qtbase/blob/v6.12.0/src/corelib/kernel/qcoreapplication.cpp)：绝对 `AT_EXECFN` 优先，之后才回退到 `/proc/self/exe`。
- [sharun 启动实现](https://github.com/VHSgunzo/sharun/blob/main/src/main.rs) 与 [说明](https://github.com/VHSgunzo/sharun/blob/main/README.md)：普通 ELF64 使用 userland-execve，以及真实程序路径、加载器参数的构造。
- [glibc 动态加载器源码](https://github.com/bminor/glibc/blob/master/elf/rtld.c)：按实际程序参数调整 `AT_EXECFN`。
- [KeePassXC 2.7.12 Resources.cpp](https://github.com/keepassxreboot/keepassxc/blob/2.7.12/src/core/Resources.cpp) 与 [2.8.0 Resources.cpp](https://github.com/keepassxreboot/keepassxc/blob/2.8.0/src/core/Resources.cpp)：相同的应用数据目录查找逻辑。
- [KeePassXC 2.8.0 Translator.cpp](https://github.com/keepassxreboot/keepassxc/blob/2.8.0/src/core/Translator.cpp)：翻译加载与语言列表来自应用数据目录下的 `translations`。

上游 `main` / `master` 链接会变化，后续排查须结合当时产物和对应版本重新核对。

## 2026-10-23：用户实机验收通过

用户实机运行 [ba30a16](https://github.com/newyorkthink/linux-packaging/commit/ba30a160db2d46615257f8379bb4d23f5fe1c9f8) 修复后的 KeePassXC 2.8.0，提供中文界面和中文输入法候选截图，确认中文界面、中文输入正常，反馈使用没有发现问题，本次修复测试通过。

前文“新构建及实机运行结果未验证”是修复提交时的记录，本条追加后续用户验收结论，不覆盖此前的产物对照、排查过程和检查边界。当前实现作为已验证稳定基线保留，具体确认范围与维护要求见 [KeePassXC README](../../keepassxc/README.md)。
