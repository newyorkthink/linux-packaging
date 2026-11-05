from pathlib import Path
import sys

root = Path(sys.argv[1])

palette_files = [
    root / "libAvKys/Lib/src/qml/akpalette.cpp",
    root / "libAvKys/Lib/src/qml/akpalettegroup.cpp",
]
replacements = (
    (
        'config.value("paletteName", "System").toString()',
        'config.value("paletteName", "Adwaita Dark").toString()',
    ),
    (
        'config.value("paletteName").toString()',
        'config.value("paletteName", "Adwaita Dark").toString()',
    ),
)
replaced = 0
for path in palette_files:
    text = path.read_text()
    for old, new in replacements:
        count = text.count(old)
        text = text.replace(old, new)
        replaced += count
    path.write_text(text)
if replaced != 3:
    raise SystemExit(f"默认深色配色补丁数量异常：{replaced}，预期为 3")

main_path = root / "StandAlone/src/main.cpp"
text = main_path.read_text()
old_include = "#include <QMutex>\n#include <QSysInfo>"
new_include = "#include <QMutex>\n#include <QSettings>\n#include <QSysInfo>"
if old_include not in text:
    raise SystemExit("main.cpp 中找不到 QSettings 插入位置")
text = text.replace(old_include, new_include, 1)
old_app = "    QApplication app(argc, argv);\n    CliOptions cliOptions;"
new_app = '''    QApplication app(argc, argv);

    if (qEnvironmentVariableIntValue("WEBCAMOID_FORCE_DARK") != 0) {
        QSettings settings;
        settings.beginGroup("ThemeConfigs");
        settings.setValue("paletteName", "Adwaita Dark");
        settings.endGroup();
        settings.sync();
    }

    CliOptions cliOptions;'''
if old_app not in text:
    raise SystemExit("main.cpp 中找不到应用初始化位置")
main_path.write_text(text.replace(old_app, new_app, 1))
