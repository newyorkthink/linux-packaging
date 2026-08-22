#include <QApplication>
#include <QCloseEvent>
#include <QCoreApplication>
#include <QColor>
#include <QDialog>
#include <QDir>
#include <QFileInfo>
#include <QFont>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QLocale>
#include <QMessageBox>
#include <QPalette>
#include <QProcess>
#include <QProcessEnvironment>
#include <QPushButton>
#include <QSet>
#include <QSettings>
#include <QSizePolicy>
#include <QStandardPaths>
#include <QStringList>
#include <QSize>
#include <QStyle>
#include <QToolButton>
#include <QVBoxLayout>
#include <QVector>

#include <algorithm>

namespace {

struct AppEntry {
    int order = 0;
    QString name;
    QString description;
    QString command;
    QString iconName;
};

QLocale preferredLocale()
{
    const char *variables[] = {
        "LANGUAGE",
        "LC_ALL",
        "LC_MESSAGES",
        "LANG",
    };

    for (const char *variable : variables) {
        QString value = qEnvironmentVariable(variable).section(QLatin1Char(':'), 0, 0);
        value = value.section(QLatin1Char('.'), 0, 0).section(QLatin1Char('@'), 0, 0).trimmed();
        if (value.isEmpty() || value == QStringLiteral("C") || value == QStringLiteral("POSIX")) {
            continue;
        }

        const QLocale locale(value);
        if (locale.language() != QLocale::C) {
            return locale;
        }
    }

    return QLocale::system();
}

bool isChineseLocale(const QLocale &locale)
{
    return locale.language() == QLocale::Chinese;
}

QString localizedValue(QSettings &settings, const QString &key, const QLocale &locale)
{
    const QString localeKey = key + QStringLiteral("[") + locale.name() + QStringLiteral("]");
    const QString localeValue = settings.value(localeKey).toString().trimmed();
    if (!localeValue.isEmpty()) {
        return localeValue;
    }

    if (isChineseLocale(locale)) {
        const QString chineseValue = settings.value(key + QStringLiteral("[zh_CN]")).toString().trimmed();
        if (!chineseValue.isEmpty()) {
            return chineseValue;
        }
    }

    return settings.value(key).toString().trimmed();
}

QPalette lightPalette()
{
    QPalette palette;
    palette.setColor(QPalette::Window, QColor(245, 245, 245));
    palette.setColor(QPalette::WindowText, QColor(35, 38, 41));
    palette.setColor(QPalette::Base, QColor(255, 255, 255));
    palette.setColor(QPalette::AlternateBase, QColor(238, 238, 238));
    palette.setColor(QPalette::ToolTipBase, QColor(255, 255, 255));
    palette.setColor(QPalette::ToolTipText, QColor(35, 38, 41));
    palette.setColor(QPalette::Text, QColor(35, 38, 41));
    palette.setColor(QPalette::Button, QColor(250, 250, 250));
    palette.setColor(QPalette::ButtonText, QColor(35, 38, 41));
    palette.setColor(QPalette::BrightText, QColor(255, 255, 255));
    palette.setColor(QPalette::Highlight, QColor(61, 174, 233));
    palette.setColor(QPalette::HighlightedText, QColor(255, 255, 255));
    palette.setColor(QPalette::PlaceholderText, QColor(110, 110, 110));
    return palette;
}

QPalette darkPalette()
{
    QPalette palette;
    palette.setColor(QPalette::Window, QColor(35, 38, 41));
    palette.setColor(QPalette::WindowText, QColor(239, 240, 241));
    palette.setColor(QPalette::Base, QColor(27, 30, 32));
    palette.setColor(QPalette::AlternateBase, QColor(49, 54, 59));
    palette.setColor(QPalette::ToolTipBase, QColor(49, 54, 59));
    palette.setColor(QPalette::ToolTipText, QColor(239, 240, 241));
    palette.setColor(QPalette::Text, QColor(239, 240, 241));
    palette.setColor(QPalette::Button, QColor(49, 54, 59));
    palette.setColor(QPalette::ButtonText, QColor(239, 240, 241));
    palette.setColor(QPalette::BrightText, QColor(255, 255, 255));
    palette.setColor(QPalette::Highlight, QColor(61, 174, 233));
    palette.setColor(QPalette::HighlightedText, QColor(255, 255, 255));
    palette.setColor(QPalette::PlaceholderText, QColor(170, 170, 170));
    return palette;
}

QString appDirPath()
{
    const QString fromEnvironment = qEnvironmentVariable("APPDIR");
    if (!fromEnvironment.isEmpty()) {
        return QDir::cleanPath(fromEnvironment);
    }

    return QDir::cleanPath(QCoreApplication::applicationDirPath() + QStringLiteral("/.."));
}

} // namespace

class LauncherWindow final : public QDialog {
public:
    LauncherWindow()
        : locale_(preferredLocale()),
          chinese_(isChineseLocale(locale_)),
          appDir_(appDirPath()),
          preferences_(preferenceFilePath(), QSettings::IniFormat)
    {
        const bool systemDark = QApplication::palette().color(QPalette::Window).lightness() < 128;
        darkMode_ = preferences_.value(QStringLiteral("darkMode"), systemDark).toBool();

        configureIconTheme();
        loadConfiguration();
        buildInterface();
        applyTheme();
    }

protected:
    void closeEvent(QCloseEvent *event) override
    {
        if (!activeProcesses_.isEmpty()) {
            QMessageBox::information(
                this,
                chinese_ ? QStringLiteral("KDE 应用套件") : QStringLiteral("KDE Suite"),
                chinese_
                    ? QStringLiteral("仍有从此 AppImage 启动的程序正在运行。请先关闭这些程序，再关闭启动器，以保持同一个挂载可用。")
                    : QStringLiteral("Applications launched from this AppImage are still running. Close them before closing the launcher so the shared mount remains available."));
            event->ignore();
            return;
        }

        QDialog::closeEvent(event);
    }

private:
    QString preferenceFilePath() const
    {
        const QString directory = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
            + QStringLiteral("/kde-suite");
        QDir().mkpath(directory);
        return directory + QStringLiteral("/launcher.ini");
    }

    void configureIconTheme()
    {
        QStringList searchPaths = QIcon::themeSearchPaths();
        const QString bundledIcons = appDir_ + QStringLiteral("/share/icons");
        if (!searchPaths.contains(bundledIcons)) {
            searchPaths.prepend(bundledIcons);
        }
        QIcon::setThemeSearchPaths(searchPaths);
    }

    void loadConfiguration()
    {
        QSettings settings(appDir_ + QStringLiteral("/share/kde-suite/apps.ini"), QSettings::IniFormat);

        settings.beginGroup(QStringLiteral("Launcher"));
        title_ = localizedValue(settings, QStringLiteral("Title"), locale_);
        subtitle_ = localizedValue(settings, QStringLiteral("Subtitle"), locale_);
        settings.endGroup();

        const QStringList groups = settings.childGroups();
        for (const QString &group : groups) {
            if (group == QStringLiteral("Launcher")) {
                continue;
            }

            settings.beginGroup(group);
            AppEntry entry;
            entry.order = settings.value(QStringLiteral("Order"), 0).toInt();
            entry.name = localizedValue(settings, QStringLiteral("Name"), locale_);
            entry.description = localizedValue(settings, QStringLiteral("Description"), locale_);
            entry.command = settings.value(QStringLiteral("Exec")).toString().trimmed();
            entry.iconName = settings.value(QStringLiteral("Icon")).toString().trimmed();
            settings.endGroup();

            if (!entry.name.isEmpty() && !entry.command.isEmpty()) {
                entries_.append(entry);
            }
        }

        std::sort(entries_.begin(), entries_.end(), [](const AppEntry &left, const AppEntry &right) {
            if (left.order != right.order) {
                return left.order < right.order;
            }
            return left.name.localeAwareCompare(right.name) < 0;
        });

        if (title_.isEmpty()) {
            title_ = chinese_ ? QStringLiteral("KDE 应用套件") : QStringLiteral("KDE Suite");
        }
        if (subtitle_.isEmpty()) {
            subtitle_ = chinese_
                ? QStringLiteral("从同一个 AppImage 挂载中启动应用")
                : QStringLiteral("Launch applications from one shared AppImage mount");
        }

        if (entries_.isEmpty()) {
            entries_ = {
                {10, QStringLiteral("KDE Connect"), chinese_ ? QStringLiteral("设备连接与文件传输") : QStringLiteral("Device connection and file transfer"), QStringLiteral("kdeconnect-app"), QStringLiteral("kdeconnect")},
                {20, QStringLiteral("Dolphin"), chinese_ ? QStringLiteral("文件管理器") : QStringLiteral("File manager"), QStringLiteral("dolphin"), QStringLiteral("org.kde.dolphin")},
                {30, QStringLiteral("Konsole"), chinese_ ? QStringLiteral("终端") : QStringLiteral("Terminal"), QStringLiteral("konsole"), QStringLiteral("utilities-terminal")},
                {40, QStringLiteral("Filelight"), chinese_ ? QStringLiteral("磁盘空间分析") : QStringLiteral("Disk usage analyzer"), QStringLiteral("filelight"), QStringLiteral("filelight")},
            };
        }
    }

    void buildInterface()
    {
        setWindowTitle(title_);
        setWindowIcon(QIcon(appDir_ + QStringLiteral("/kde-suite.svg")));
        setMinimumWidth(640);

        auto *mainLayout = new QVBoxLayout(this);
        mainLayout->setContentsMargins(24, 20, 24, 20);
        mainLayout->setSpacing(18);

        auto *headerLayout = new QHBoxLayout;
        auto *headingLayout = new QVBoxLayout;

        titleLabel_ = new QLabel(title_, this);
        QFont titleFont = titleLabel_->font();
        titleFont.setPointSize(titleFont.pointSize() + 6);
        titleFont.setBold(true);
        titleLabel_->setFont(titleFont);

        subtitleLabel_ = new QLabel(subtitle_, this);
        subtitleLabel_->setWordWrap(true);

        headingLayout->addWidget(titleLabel_);
        headingLayout->addWidget(subtitleLabel_);
        headerLayout->addLayout(headingLayout, 1);

        themeButton_ = new QPushButton(this);
        themeButton_->setMinimumWidth(108);
        connect(themeButton_, &QPushButton::clicked, this, [this] {
            darkMode_ = !darkMode_;
            preferences_.setValue(QStringLiteral("darkMode"), darkMode_);
            preferences_.sync();
            applyTheme();
        });
        headerLayout->addWidget(themeButton_, 0, Qt::AlignTop);
        mainLayout->addLayout(headerLayout);

        auto *grid = new QGridLayout;
        grid->setHorizontalSpacing(16);
        grid->setVerticalSpacing(16);

        for (int index = 0; index < entries_.size(); ++index) {
            const AppEntry entry = entries_.at(index);
            auto *button = new QToolButton(this);
            button->setToolButtonStyle(Qt::ToolButtonTextUnderIcon);
            button->setIconSize(QSize(72, 72));
            button->setText(entry.description.isEmpty()
                ? entry.name
                : entry.name + QStringLiteral("\n") + entry.description);
            button->setFixedSize(180, 150);
            button->setProperty("iconName", entry.iconName);
            button->setProperty("command", entry.command);
            button->setAccessibleName(entry.name);
            button->setToolTip(entry.description);
            connect(button, &QToolButton::clicked, this, [this, entry] {
                launch(entry);
            });

            appButtons_.append(button);
            grid->addWidget(button, index / 3, index % 3);
        }

        mainLayout->addLayout(grid);

        statusLabel_ = new QLabel(
            chinese_ ? QStringLiteral("选择一个应用启动") : QStringLiteral("Select an application to launch"),
            this);
        statusLabel_->setWordWrap(true);
        mainLayout->addWidget(statusLabel_);

        resize(680, entries_.size() > 3 ? 500 : 340);
    }

    void applyTheme()
    {
        QApplication::setPalette(darkMode_ ? darkPalette() : lightPalette());
        QIcon::setThemeName(darkMode_ ? QStringLiteral("breeze-dark") : QStringLiteral("breeze"));

        themeButton_->setText(darkMode_
            ? (chinese_ ? QStringLiteral("切换浅色") : QStringLiteral("Use light theme"))
            : (chinese_ ? QStringLiteral("切换深色") : QStringLiteral("Use dark theme")));
        themeButton_->setIcon(QIcon::fromTheme(darkMode_
            ? QStringLiteral("weather-clear")
            : QStringLiteral("weather-clear-night")));

        const QPalette palette = QApplication::palette();
        const QString border = palette.color(QPalette::Mid).name();
        const QString normal = palette.color(QPalette::Button).name();
        const QString hover = palette.color(QPalette::AlternateBase).name();
        const QString pressed = palette.color(QPalette::Highlight).name();
        const QString text = palette.color(QPalette::ButtonText).name();
        const QString highlightedText = palette.color(QPalette::HighlightedText).name();

        const QString cardStyle = QStringLiteral(
            "QToolButton { border: 1px solid %1; border-radius: 12px; padding: 14px; background: %2; color: %3; }"
            "QToolButton:hover { background: %4; }"
            "QToolButton:pressed { background: %5; color: %6; }")
            .arg(border, normal, text, hover, pressed, highlightedText);

        for (QToolButton *button : appButtons_) {
            button->setStyleSheet(cardStyle);
            button->setIcon(iconFor(
                button->property("iconName").toString(),
                button->property("command").toString()));
        }
    }

    QIcon iconFor(const QString &iconName, const QString &command) const
    {
        QIcon icon = QIcon::fromTheme(iconName);
        if (!icon.isNull()) {
            return icon;
        }

        if (command.contains(QStringLiteral("dolphin"))) {
            return style()->standardIcon(QStyle::SP_DirIcon);
        }
        if (command.contains(QStringLiteral("konsole"))) {
            return style()->standardIcon(QStyle::SP_ComputerIcon);
        }
        if (command.contains(QStringLiteral("filelight"))) {
            return style()->standardIcon(QStyle::SP_DriveHDIcon);
        }
        return style()->standardIcon(QStyle::SP_DriveNetIcon);
    }

    void launch(const AppEntry &entry)
    {
        QStringList parts = QProcess::splitCommand(entry.command);
        if (parts.isEmpty()) {
            return;
        }

        QString executable = parts.takeFirst();
        if (!QDir::isAbsolutePath(executable)) {
            executable = appDir_ + QStringLiteral("/bin/") + executable;
        }

        const QFileInfo executableInfo(executable);
        if (!executableInfo.isExecutable()) {
            QMessageBox::critical(
                this,
                title_,
                chinese_
                    ? QStringLiteral("找不到可执行程序：%1").arg(executable)
                    : QStringLiteral("Executable not found: %1").arg(executable));
            return;
        }

        auto *process = new QProcess(this);
        process->setProgram(executable);
        process->setArguments(parts);
        process->setWorkingDirectory(QDir::homePath());
        process->setProcessEnvironment(QProcessEnvironment::systemEnvironment());

        activeProcesses_.insert(process);
        statusLabel_->setText(chinese_
            ? QStringLiteral("正在启动：%1").arg(entry.name)
            : QStringLiteral("Launching: %1").arg(entry.name));

        connect(process, &QProcess::started, this, [this, entry] {
            statusLabel_->setText(chinese_
                ? QStringLiteral("已启动：%1").arg(entry.name)
                : QStringLiteral("Started: %1").arg(entry.name));
        });

        connect(process, &QProcess::errorOccurred, this, [this, process, entry](QProcess::ProcessError error) {
            if (error != QProcess::FailedToStart) {
                return;
            }

            activeProcesses_.remove(process);
            QMessageBox::critical(
                this,
                title_,
                chinese_
                    ? QStringLiteral("无法启动 %1：%2").arg(entry.name, process->errorString())
                    : QStringLiteral("Could not start %1: %2").arg(entry.name, process->errorString()));
            process->deleteLater();
        });

        connect(process, static_cast<void (QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished), this,
            [this, process, entry](int, QProcess::ExitStatus) {
                if (activeProcesses_.remove(process) > 0) {
                    statusLabel_->setText(chinese_
                        ? QStringLiteral("已关闭：%1").arg(entry.name)
                        : QStringLiteral("Closed: %1").arg(entry.name));
                }
                process->deleteLater();
            });

        process->start();
    }

    const QLocale locale_;
    const bool chinese_;
    const QString appDir_;
    QSettings preferences_;
    bool darkMode_ = false;
    QString title_;
    QString subtitle_;
    QVector<AppEntry> entries_;
    QVector<QToolButton *> appButtons_;
    QSet<QProcess *> activeProcesses_;
    QLabel *titleLabel_ = nullptr;
    QLabel *subtitleLabel_ = nullptr;
    QLabel *statusLabel_ = nullptr;
    QPushButton *themeButton_ = nullptr;
};

int main(int argc, char *argv[])
{
    const QString appDir = qEnvironmentVariable("APPDIR");
    if (!appDir.isEmpty()) {
        QStringList searchPaths = QIcon::themeSearchPaths();
        const QString bundledIcons = QDir::cleanPath(appDir) + QStringLiteral("/share/icons");
        if (!searchPaths.contains(bundledIcons)) {
            searchPaths.prepend(bundledIcons);
        }
        QIcon::setThemeSearchPaths(searchPaths);
    }
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));

    QApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("kde-suite-launcher"));
    application.setOrganizationName(QStringLiteral("KDE Suite"));
    application.setDesktopFileName(QStringLiteral("org.kde.kdesuite"));
    application.setStyle(QStringLiteral("Fusion"));

    LauncherWindow window;
    window.show();
    return application.exec();
}
