#include "desktop.h"

#include <QBuffer>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QImageReader>
#include <QLocale>
#include <QMutex>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>

namespace stack {

namespace {

QString unescape(const QString &v)
{
    QString out;
    out.reserve(v.size());
    for (int i = 0; i < v.size(); i++) {
        if (v[i] == QLatin1Char('\\') && i + 1 < v.size()) {
            const QChar c = v[++i];
            if (c == QLatin1Char('s'))
                out += QLatin1Char(' ');
            else if (c == QLatin1Char('n'))
                out += QLatin1Char('\n');
            else if (c == QLatin1Char('t'))
                out += QLatin1Char('\t');
            else if (c == QLatin1Char('r'))
                out += QLatin1Char('\r');
            else if (c == QLatin1Char('\\'))
                out += QLatin1Char('\\');
            else {
                out += QLatin1Char('\\');
                out += c;
            }
        } else {
            out += v[i];
        }
    }
    return out;
}

QStringList splitList(const QString &v)
{
    QStringList out;
    for (const QString &part : v.split(QLatin1Char(';'), Qt::SkipEmptyParts)) {
        const QString t = part.trimmed();
        if (!t.isEmpty())
            out << t;
    }
    return out;
}

bool onPath(const QString &program)
{
    if (program.contains(QLatin1Char('/')))
        return QFileInfo(program).isExecutable();
    return !QStandardPaths::findExecutable(program).isEmpty();
}

QStringList desktops()
{
    QStringList out;
    for (const QString &d : qEnvironmentVariable("XDG_CURRENT_DESKTOP").split(QLatin1Char(':'), Qt::SkipEmptyParts))
        out << d.toLower();
    return out;
}

DesktopEntry *parse(const QString &path, const QString &id, QObject *parent)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return nullptr;
    QTextStream in(&file);
    QHash<QString, QString> values;
    bool inEntry = false;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        if (line.startsWith(QLatin1Char('['))) {
            if (inEntry)
                break;
            inEntry = line == QStringLiteral("[Desktop Entry]");
            continue;
        }
        if (!inEntry)
            continue;
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;
        const QString key = line.left(eq).trimmed();
        if (!values.contains(key))
            values.insert(key, line.mid(eq + 1).trimmed());
    }
    if (values.value(QStringLiteral("Type")) != QStringLiteral("Application"))
        return nullptr;
    if (values.value(QStringLiteral("Hidden")) == QStringLiteral("true"))
        return nullptr;
    const QString tryExec = unescape(values.value(QStringLiteral("TryExec")));
    if (!tryExec.isEmpty() && !onPath(tryExec))
        return nullptr;
    const QString locale = QLocale::system().name();
    const QString lang = locale.section(QLatin1Char('_'), 0, 0);
    auto localized = [&](const QString &key) {
        for (const QString &k : {key + QLatin1Char('[') + locale + QLatin1Char(']'), key + QLatin1Char('[') + lang + QLatin1Char(']'), key}) {
            if (values.contains(k))
                return unescape(values.value(k));
        }
        return QString();
    };
    auto *e = new DesktopEntry(parent);
    e->id = id;
    e->name = localized(QStringLiteral("Name"));
    e->genericName = localized(QStringLiteral("GenericName"));
    e->comment = localized(QStringLiteral("Comment"));
    e->icon = unescape(values.value(QStringLiteral("Icon")));
    e->execString = unescape(values.value(QStringLiteral("Exec")));
    e->command = DesktopEntries::splitExec(e->execString);
    e->workingDirectory = unescape(values.value(QStringLiteral("Path")));
    e->keywords = splitList(localized(QStringLiteral("Keywords")));
    e->categories = splitList(values.value(QStringLiteral("Categories")));
    e->startupClass = unescape(values.value(QStringLiteral("StartupWMClass")));
    e->noDisplay = values.value(QStringLiteral("NoDisplay")) == QStringLiteral("true");
    e->runInTerminal = values.value(QStringLiteral("Terminal")) == QStringLiteral("true");
    const QStringList current = desktops();
    const QStringList only = splitList(values.value(QStringLiteral("OnlyShowIn")));
    const QStringList not_ = splitList(values.value(QStringLiteral("NotShowIn")));
    if (!only.isEmpty() && std::none_of(only.begin(), only.end(), [&](const QString &d) { return current.contains(d.toLower()); }))
        e->noDisplay = true;
    if (std::any_of(not_.begin(), not_.end(), [&](const QString &d) { return current.contains(d.toLower()); }))
        e->noDisplay = true;
    if (e->name.isEmpty())
        e->name = id;
    return e;
}

}

void DesktopEntry::execute() const
{
    if (command.isEmpty())
        return;
    QProcess p;
    QStringList args = command;
    p.setProgram(args.takeFirst());
    p.setArguments(args);
    if (!workingDirectory.isEmpty() && QFileInfo(workingDirectory).isDir())
        p.setWorkingDirectory(workingDirectory);
    else
        p.setWorkingDirectory(QDir::homePath());
    p.setStandardInputFile(QProcess::nullDevice());
    p.setStandardOutputFile(QProcess::nullDevice());
    p.setStandardErrorFile(QProcess::nullDevice());
    if (!p.startDetached())
        qWarning("sylstack: could not start %s", qPrintable(id));
}

QStringList DesktopEntries::splitExec(const QString &exec)
{
    QStringList words;
    QString cur;
    bool quoted = false;
    bool have = false;
    for (int i = 0; i < exec.size(); i++) {
        const QChar c = exec[i];
        if (quoted) {
            if (c == QLatin1Char('\\') && i + 1 < exec.size()) {
                cur += exec[++i];
            } else if (c == QLatin1Char('"')) {
                quoted = false;
            } else {
                cur += c;
            }
        } else if (c == QLatin1Char('"')) {
            quoted = true;
            have = true;
        } else if (c.isSpace()) {
            if (have || !cur.isEmpty())
                words << cur;
            cur.clear();
            have = false;
        } else {
            cur += c;
        }
    }
    if (have || !cur.isEmpty())
        words << cur;
    QStringList out;
    for (const QString &w : words) {
        if (w.size() == 2 && w[0] == QLatin1Char('%') && QStringLiteral("fFuUdDnNickvm").contains(w[1]))
            continue;
        QString clean;
        for (int i = 0; i < w.size(); i++) {
            if (w[i] == QLatin1Char('%') && i + 1 < w.size()) {
                const QChar code = w[++i];
                if (code == QLatin1Char('%'))
                    clean += QLatin1Char('%');
            } else {
                clean += w[i];
            }
        }
        if (!clean.isEmpty())
            out << clean;
    }
    return out;
}

DesktopEntries::DesktopEntries()
    : m_model(new ObjectModel(this))
{
    m_rescan.setSingleShot(true);
    m_rescan.setInterval(500);
    connect(&m_rescan, &QTimer::timeout, this, &DesktopEntries::scan);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_rescan, qOverload<>(&QTimer::start));
}

DesktopEntries *DesktopEntries::create(QQmlEngine *, QJSEngine *)
{
    static DesktopEntries *self = new DesktopEntries();
    QJSEngine::setObjectOwnership(self, QJSEngine::CppOwnership);
    return self;
}

ObjectModel *DesktopEntries::applications()
{
    if (!m_scanned)
        scan();
    return m_model;
}

DesktopEntry *DesktopEntries::byId(const QString &id)
{
    if (!m_scanned)
        scan();
    QString key = id;
    if (key.endsWith(QStringLiteral(".desktop")))
        key.chop(8);
    if (auto *e = m_byId.value(key))
        return e;
    for (auto it = m_byId.cbegin(); it != m_byId.cend(); ++it) {
        if (it.key().compare(key, Qt::CaseInsensitive) == 0)
            return it.value();
    }
    return nullptr;
}

DesktopEntry *DesktopEntries::heuristicLookup(const QString &name)
{
    if (auto *e = byId(name))
        return e;
    for (auto *e : std::as_const(m_byId)) {
        if (!e->startupClass.isEmpty() && e->startupClass == name)
            return e;
    }
    for (auto *e : std::as_const(m_byId)) {
        if (!e->startupClass.isEmpty() && e->startupClass.compare(name, Qt::CaseInsensitive) == 0)
            return e;
    }
    for (auto it = m_byId.cbegin(); it != m_byId.cend(); ++it) {
        if (it.key().section(QLatin1Char('.'), -1).compare(name, Qt::CaseInsensitive) == 0)
            return it.value();
    }
    return nullptr;
}

void DesktopEntries::scan()
{
    m_scanned = true;
    QStringList dirs;
    for (const QString &d : QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation)) {
        if (!dirs.contains(d))
            dirs << d;
    }
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());
    QHash<QString, DesktopEntry *> next;
    for (const QString &dir : dirs) {
        if (!QFileInfo(dir).isDir())
            continue;
        m_watcher.addPath(dir);
        QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
        while (it.hasNext()) {
            const QString path = it.next();
            QString id = path.mid(dir.size() + 1);
            id.chop(8);
            id.replace(QLatin1Char('/'), QLatin1Char('-'));
            if (next.contains(id))
                continue;
            if (auto *e = parse(path, id, this))
                next.insert(id, e);
            else
                next.insert(id, nullptr);
        }
    }
    QList<QObject *> list;
    for (auto it = next.begin(); it != next.end();) {
        if (!it.value()) {
            it = next.erase(it);
            continue;
        }
        list << it.value();
        ++it;
    }
    std::sort(list.begin(), list.end(), [](QObject *a, QObject *b) {
        return static_cast<DesktopEntry *>(a)->id < static_cast<DesktopEntry *>(b)->id;
    });
    const auto old = m_byId;
    m_byId = next;
    m_model->replace(list);
    for (auto *e : old)
        e->deleteLater();
}

namespace {

QMutex storeLock;
QHash<QString, QImage> store;
quint64 storeRevision = 0;

}

ImageStore::ImageStore()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage ImageStore::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QString key = id;
    const int q = key.indexOf(QLatin1Char('?'));
    if (q >= 0)
        key.truncate(q);
    QImage img;
    {
        QMutexLocker lock(&storeLock);
        img = store.value(key);
    }
    if (!img.isNull() && requestedSize.isValid() && requestedSize.width() > 0 && requestedSize.height() > 0)
        img = img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    if (size)
        *size = img.size();
    return img;
}

QString ImageStore::put(const QString &key, const QImage &image)
{
    QMutexLocker lock(&storeLock);
    store.insert(key, image);
    return QStringLiteral("image://sylstack/") + key + QStringLiteral("?") + QString::number(++storeRevision);
}

QImage ImageStore::decode(const QByteArray &data, int maxSide)
{
    QBuffer buffer;
    buffer.setData(data);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    const QSize size = reader.size();
    if (!size.isValid() || size.width() > maxSide || size.height() > maxSide)
        return {};
    return reader.read();
}

void ImageStore::drop(const QString &key)
{
    QMutexLocker lock(&storeLock);
    store.remove(key);
}

IconProvider::IconProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    QString name = id;
    const int q = name.indexOf(QLatin1Char('?'));
    if (q >= 0)
        name.truncate(q);
    QSize want = requestedSize.isValid() && requestedSize.width() > 0 ? requestedSize : QSize(64, 64);
    if (want.height() <= 0)
        want.setHeight(want.width());
    QIcon icon = QIcon::fromTheme(name);
    if (icon.isNull()) {
        for (const QString &dir : QIcon::fallbackSearchPaths()) {
            for (const char *ext : {".png", ".svg", ".xpm"}) {
                const QString file = dir + QLatin1Char('/') + name + QLatin1String(ext);
                if (QFileInfo::exists(file)) {
                    icon = QIcon(file);
                    break;
                }
            }
            if (!icon.isNull())
                break;
        }
    }
    const QPixmap pm = icon.isNull() ? QPixmap() : icon.pixmap(want);
    if (size)
        *size = pm.size();
    return pm;
}

}
