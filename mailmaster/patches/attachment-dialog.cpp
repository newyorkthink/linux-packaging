#include <QDir>
#include <QFileDialog>
#include <QObject>

// 只为从包内工作目录打开的附件选择窗口补上起始目录。
extern "C" QStringList mailmaster_open_files(QWidget *parent, const QString &title,
    const QString &directory, const QString &filter, QString *selectedFilter,
    QFileDialog::Options options)
{
    const QString appDir = qEnvironmentVariable("APPDIR");
    if (directory.isEmpty() && title == QObject::tr("选择附件") &&
        !appDir.isEmpty() && QDir::currentPath() == QDir(appDir).filePath("bin")) {
        return QFileDialog::getOpenFileNames(parent, title, QDir::homePath(),
                                             filter, selectedFilter, options);
    }
    return QFileDialog::getOpenFileNames(parent, title, directory,
                                         filter, selectedFilter, options);
}
