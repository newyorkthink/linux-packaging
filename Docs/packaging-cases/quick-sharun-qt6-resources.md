# quick-sharun 下 Qt5 转 Qt6 的程序路径变化

本文说明一种可复用的打包问题：在采用 sharun 的 AppDir 中，Qt 获取程序路径的方式变化后，应用按程序目录查找资源或辅助程序，可能落到不同位置。本页只保留通用机制、适用条件和排查方法。具体应用的产物证据、修复历史和验收状态记录在其自身目录。

## 通用机制与适用条件

以下是一种布局示例，目标 AppDir 必须以实际解包结果为准；`<程序>`、`<应用>` 等占位符需按实际环境替换：

| 作用 | 路径示例 |
| --- | --- |
| 建立包内加载环境的启动入口 | `AppDir/bin/<程序>`，可能是 sharun 的硬链接 |
| 被启动器加载的原始 ELF | `AppDir/shared/bin/<程序>` |
| 包内依赖库 | `AppDir/lib/`；也可能通过 `shared/lib` 相对链接访问 |
| 应用数据 | `AppDir/share/<应用>/` |

sharun 的普通 ELF64 启动链使用 userland-execve：在当前进程中加载解释器和程序。这样 `/proc/<pid>/exe` 可以仍指向 `bin` 下的启动器，而加载器给出的 `AT_EXECFN` 指向 `shared/bin` 下的真实 ELF。Qt 如果改用后一条路径，`applicationFilePath()` 和 `applicationDirPath()` 的结果就会变化。

路径策略取决于 Qt 的具体版本、平台和构建选项。不能只看“Qt5 / Qt6”标签就认定不同应用的查找行为相同，必须核对目标程序实际使用的路径。复用本页结论需要同时满足：

1. 应用经过 sharun 启动，启动入口与真实程序位于不同目录。
2. 当前 Qt 实际报告的程序目录与旧版不同。
3. 应用源码确实用该程序目录拼接资源目录或辅助程序路径。
4. 目标位置、文件类型或启动方式与应用的实际需要不匹配。

## 两类常见后果

| 受影响对象 | 路径变化后的问题 | 处理方向 |
| --- | --- | --- |
| 翻译、词表、图标等资源 | 按新程序目录拼接的相对路径不存在，或回退到错误的数据根目录 | 对照应用源码和现有数据位置，补足相符的相对目录映射 |
| 浏览器代理等辅助程序 | 外部程序直接启动 `shared/bin` 中的原始 ELF，绕过包内加载器和依赖路径 | 在应用登记的位置提供经过原 sharun 启动器的入口，并保持原程序和通信接口 |

资源适配不能代替辅助程序适配。`LANG`、`LANGUAGE`、`LOCPATH` 用于语言环境，也不会改变 Qt 所报告的程序目录，或替外部浏览器建立代理的库加载环境。

资源映射只在路径关系确实相符时采用。例如实际数据位于顶层 `share`，而应用确实需要从 `shared/bin/../share` 访问时，才适用 `shared/share -> ../share` 这样的相对链接。辅助程序适配则应核对调用位置和加载链，保留原二进制，通过 `exec` 原样传递参数及标准输入输出；原生消息标准输出不能混入日志。

sharun 入口可能共享同一个硬链接 inode。需要改成转发脚本时，必须先改名保留原入口，再在原路径新建文件；不得直接用重定向覆盖硬链接。外部浏览器直接执行原始 ELF 时，不会自动经过默认 AppRun 或 hook，也不会读取 sharun 的 `.env`，因此单改这些配置不能修复该调用链。

## 后续应用的排查顺序

1. 完整阅读对应应用 README、打包脚本和相关源码，确认已验证稳定基线。
2. 核对成品的 Qt 版本、入口与真实程序的位置、资源目录，以及外部程序实际登记的路径。
3. 分清文件缺失、资源根目录错误和绕过启动器三种情况，再提出针对该应用的最小适配清单；不批量改动其他 Qt 应用。
4. 分别验证文件定位、真实程序启动、参数和标准输入输出、实际通信及实机使用。某一层通过不能代替后续层的验证。

## 上游依据

- [Qt5 QCoreApplication 源码](https://github.com/qt/qtbase/blob/v5.15.2/src/corelib/kernel/qcoreapplication.cpp)：该版本的程序路径读取逻辑。
- [Qt 6.12.0 QCoreApplication 源码](https://github.com/qt/qtbase/blob/v6.12.0/src/corelib/kernel/qcoreapplication.cpp)：绝对 `AT_EXECFN` 优先，之后才回退到 `/proc/self/exe`。
- [sharun 启动实现](https://github.com/VHSgunzo/sharun/blob/main/src/main.rs) 与 [说明](https://github.com/VHSgunzo/sharun/blob/main/README.md)：普通 ELF64 使用 userland-execve，以及真实程序路径、加载器参数的构造。
- [glibc 动态加载器源码](https://github.com/bminor/glibc/blob/master/elf/rtld.c)：按实际程序参数调整 `AT_EXECFN`。

源码链接说明相应版本或分支的实现，不能代替对目标程序实际 Qt 版本和启动行为的核对。上游 `main` / `master` 会变化，后续排查须重新核实。
