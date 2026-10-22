# Dolphin 启动配色缓存方案参考（2026-10-22）

**状态：方案已撤回，仅供技术参考，不参与构建、启动、版本指纹或发布。**

本文件保存已经进行过的分析和历史实现，供后续 AI 理解问题。上游 Bug 默认保留并交由上游修复；非重大问题不主动处理。只有用户知晓上游归属后，仍明确强调要求修复并批准具体清单，才可以重新评估。不得根据本文件自动恢复插件、源码补丁或启动干预。

## 问题与上游依据

Dolphin 以深色配色启动时，“文件夹”树的隔行背景明显灰黑相间；切换到浅色再切回深色后恢复。上游 [Bug 514786](https://bugs.kde.org/show_bug.cgi?id=514786) 记录同类启动条纹和切换后恢复的现象，并归入 [Bug 467752](https://bugs.kde.org/show_bug.cgi?id=467752)。记录时后者状态为 CONFIRMED；前者的 RESOLVED DUPLICATE 只表示合并到主问题，不表示缺陷已修复。

这些 Issue 用于核实上游已有同类故障；不能只凭症状一致，声称上游已经确认本次云端分析的全部根因。

## 代码基线与撤回范围

- 保留基线：`4ac2418d271e4935055f4f662122873ff10c9ae6`，包含此前已确认有效的 KIO worker 入口、KDE 图标引擎/Kirigami Forms 依赖以及 Haruna 专用样式修复。
- 历史方案提交：`c61a90289f487808ba13ba79a9bd72312a5dc479`，已从 `main` 历史撤回；提交号仅用于说明来源，不是当前使用基线。
- 撤回后，`build_kde_suite.sh`、`deploy_activities.sh`、`deploy_suite_apps.sh` 已恢复到保留基线对应内容，`dolphin_palette_plugin.cpp`、`dolphin_palette_plugin.json` 已从正式文件集合移除。
- 下文以 Markdown 代码块保留原始实现，不能把这些代码块复制到正式构建流程或解释为用户已同意重新启用。

## 已取得的云端证据

检查对象是 SHA-256 为 `d8e2b1f5d3805111791f1c5526bdca5584e87db9c743c5c2cef5f380eecf59bb` 的既有成品，内含 Dolphin 26.08.2、Qt 6.12.0。检查使用隔离的 HOME/XDG 目录和离屏 Qt 图形后端，没有在用户真实环境试错。

Qt6ct 使用包内 darker 配色，Dolphin 选择 BreezeDark 时，控件已经取得正确深色配色，列表绘制缓存却仍保留旧颜色：

| 检查状态 | 控件 AlternateBase | 绘制缓存 AlternateBase |
| --- | --- | --- |
| 原始冷启动，BreezeDark | `#1d1f22` | `#5c5b5a` |
| 原始冷启动，BreezeLight | `#f7f7f7` | `#5c5b5a` |
| 手动切换回 BreezeDark | `#1d1f22` | `#1d1f22` |
| 加载历史插件后冷启动，BreezeDark | `#1d1f22` | `#1d1f22` |
| 加载历史插件后冷启动，BreezeLight | `#f7f7f7` | `#f7f7f7` |

Fusion/Breeze 两种 Qt6ct 样式设置的深色冷启动均复现缓存不同步；历史插件处理后，冷启动、浅色/深色切换的缓存与当前控件配色一致，实际离屏截图中的明显灰黑条纹消失。Dolphin 最终实际采用的控件样式为 Breeze，不能把 Qt6ct 设置项名称误当作最终样式检查结果。

## 历史实现原理

通过 Qt 的公开 QGenericPlugin 接口加载一个 Dolphin 专用插件。在 `KItemListContainerViewport` 的第一次 Paint 事件到达时，向其场景中的 `KItemListView` 发送一次 `PaletteChange`，促使列表使用控件当前配色刷新 `KItemListStyleOption` 绘制缓存。

方案不重新选择主题、不写死明暗颜色、不改写用户配置，也没有修改 Dolphin 上游源码或原始 ELF。它仍属于额外的本地干预，因此按用户要求撤回，避免与后续上游修复冲突。它与 README 中旧版实机无效的 LD_PRELOAD/双定时器方案不同；区别不构成恢复任一方案的许可。

## 原始实现归档

以下为当时实现的技术存档，不是当前安装或构建步骤。

### 插件源码

原文件名：`kde-suite/dolphin_palette_plugin.cpp`；Git blob：`54e27e5388f89eef8e8ca0d9650a0d25f3e3d80a`。

```cpp
// Dolphin 启动时列表缓存可能仍保留 Qt6ct 的旧配色；只在首次绘制前同步一次。
// 使用 Qt 公开插件/事件接口，不重新选择配色，也不改写用户配置。
#include <QCoreApplication>
#include <QEvent>
#include <QGenericPlugin>
#include <QGraphicsScene>
#include <QGraphicsView>
#include <QGraphicsWidget>
#include <QVariant>
#include <QWidget>

class DolphinPaletteSynchronizer : public QObject
{
public:
    DolphinPaletteSynchronizer()
    {
        QCoreApplication::instance()->installEventFilter(this);
    }

protected:
    bool eventFilter(QObject *receiver, QEvent *event) override
    {
        if (event->type() != QEvent::Paint) {
            return false;
        }

        auto *viewport = qobject_cast<QWidget *>(receiver);
        auto *view = viewport ? qobject_cast<QGraphicsView *>(viewport->parentWidget()) : nullptr;
        if (!view || view->viewport() != viewport || !view->scene()
            || !view->inherits("KItemListContainerViewport")
            || view->property("_kde_suite_palette_synced").toBool()) {
            return false;
        }

        // 首次绘制时控件已经取得当前配色。通知列表刷新其绘制缓存，
        // 避免重新应用相同配色未产生 PaletteChange、旧缓存因而继续保留。
        bool synchronized = false;
        for (QGraphicsItem *item : view->scene()->items()) {
            auto *widget = dynamic_cast<QGraphicsWidget *>(item);
            if (widget && widget->inherits("KItemListView")) {
                QEvent changed(QEvent::PaletteChange);
                QCoreApplication::sendEvent(widget, &changed);
                synchronized = true;
            }
        }
        if (synchronized) {
            view->setProperty("_kde_suite_palette_synced", true);
        }
        return false;
    }
};

class DolphinPalettePlugin : public QGenericPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QGenericPluginFactoryInterface" FILE "dolphin_palette_plugin.json")

public:
    QObject *create(const QString &key, const QString &) override
    {
        if (key == QLatin1String("kde-suite-dolphin-palette")) {
            return new DolphinPaletteSynchronizer;
        }
        return nullptr;
    }
};

#include "dolphin_palette_plugin.moc"
```

### 插件元数据

原文件名：`kde-suite/dolphin_palette_plugin.json`；Git blob：`60b90d7b89ecda8969b5c6b7418ffff8f5ca5426`。

```json
{
    "Keys": ["kde-suite-dolphin-palette"]
}
```

### 构建与部署片段

当时该片段位于 `deploy_suite_apps.sh` 全部依赖收集完成后、最终静态检查前。插件用构建环境当前 Qt6 编译，无需更换 Dolphin 原程序。该片段现已移除。

```bash
# 列表首次绘制前同步 Dolphin 的配色缓存；使用当前构建环境的 Qt6 编译公开接口插件。
# 所有 quick-sharun 收集均已完成，插件放在最终目录，其他应用不会请求加载它。
dolphin_palette_build_dir="$(mktemp -d)"
/usr/lib/qt6/moc "$SCRIPT_DIR/dolphin_palette_plugin.cpp" \
  -o "$dolphin_palette_build_dir/dolphin_palette_plugin.moc" \
  $(pkg-config --cflags Qt6Widgets)
mkdir -p AppDir/lib/qt6/plugins/generic
g++ -std=c++17 -O2 -pipe -fPIC -shared \
  "$SCRIPT_DIR/dolphin_palette_plugin.cpp" \
  -I "$dolphin_palette_build_dir" \
  -o AppDir/lib/qt6/plugins/generic/libkde-suite-dolphin-palette.so \
  $(pkg-config --cflags --libs Qt6Widgets)
rm -rf -- "$dolphin_palette_build_dir"
```

当时另在原有最终检查中增加以下存在性检查，现已移除：

```bash
# 历史检查：确认当时编译的专用插件存在
test -s AppDir/lib/qt6/plugins/generic/libkde-suite-dolphin-palette.so
```

### 启动接入与版本指纹

当时仅把 Dolphin Activities 包装中的启动行改为下面内容；`"$@"` 完整传入原参数，Activities 服务管理与退出状态处理保持原样。当前已恢复未附加插件的原启动行。

```bash
# 历史启动接入：Qt 在解析 Dolphin 参数前加载专用插件
"$APPDIR/libexec/kde-suite/dolphin" -plugin kde-suite-dolphin-palette "$@"
```

当时 `KDE_SUITE_BUILD_FILES` 额外包含 `dolphin_palette_plugin.cpp` 和 `dolphin_palette_plugin.json`，插件源码变化参与既有版本指纹；撤回时这两项一并移除。本 Markdown 不在功能文件指纹清单中。

## 已验证范围与限制

- 基于既有成品、匹配 Qt6 头文件和运行库，完成 moc/g++ 编译、元数据加载及动态依赖检查；历史插件只新增对包内已有 Qt6/C++ 运行库的依赖。
- 检查修前/修后的冷启动和明暗切换，测量列表控件及绘制缓存的颜色并查看离屏渲染截图。
- 通过实际 AppRun 和 Dolphin 包装检查版本、BreezeDark/BreezeLight/默认配色启动，以及保存深色后的再次启动；`--version` 返回 0，显示 `dolphin 26.08.2`。
- 中文、空格、URL、空参数、选项分隔符的参数传递及退出状态保留检查通过；部署脚本和生成包装的语法、完整 diff、稳定内容保留及版本指纹引用已核对。
- 未把云端组件与离屏检查描述为新 AppImage 完整构建成功或真实 Linux 环境验收通过；新成品的完整构建与实机效果没有取得验证结果，提交后未监控 Actions。
- 方案依赖 Dolphin 内部列表对象的类型名；上游结构或缓存机制变化后不能直接沿用。重新采用前必须先核对当前上游是否已修复、当前版本是否仍复现，以及是否仍确有必要，并重新取得用户的明确修复授权。
