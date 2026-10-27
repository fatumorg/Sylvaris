#include "stack.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QJSValueIterator>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

namespace stack {

ShellScreen::ShellScreen(QScreen *screen, QObject *parent)
    : QObject(parent)
    , m_screen(screen)
    , m_name(screen->name())
{
    connect(screen, &QScreen::geometryChanged, this, &ShellScreen::geometryChanged);
    connect(screen, &QScreen::physicalDotsPerInchChanged, this, &ShellScreen::geometryChanged);
}

QString ShellScreen::name() const { return m_name; }
QString ShellScreen::model() const { return m_screen ? m_screen->model() : QString(); }
QString ShellScreen::manufacturer() const { return m_screen ? m_screen->manufacturer() : QString(); }
QString ShellScreen::serialNumber() const { return m_screen ? m_screen->serialNumber() : QString(); }
int ShellScreen::x() const { return m_screen ? m_screen->geometry().x() : 0; }
int ShellScreen::y() const { return m_screen ? m_screen->geometry().y() : 0; }
int ShellScreen::width() const { return m_screen ? m_screen->geometry().width() : 0; }
int ShellScreen::height() const { return m_screen ? m_screen->geometry().height() : 0; }
qreal ShellScreen::devicePixelRatio() const { return m_screen ? m_screen->devicePixelRatio() : 1; }

namespace {

QString gtkIconTheme()
{
    const QString file = QStandardPaths::locate(QStandardPaths::GenericConfigLocation, QStringLiteral("gtk-3.0/settings.ini"));
    if (file.isEmpty())
        return {};
    QSettings ini(file, QSettings::IniFormat);
    return ini.value(QStringLiteral("Settings/gtk-icon-theme-name")).toString();
}

void setupIcons()
{
    QString theme = qEnvironmentVariable("SYLVARIS_ICON_THEME");
    if (theme.isEmpty())
        theme = qEnvironmentVariable("QS_ICON_THEME");
    if (theme.isEmpty() && (QIcon::themeName().isEmpty() || QIcon::themeName() == QStringLiteral("hicolor")))
        theme = gtkIconTheme();
    if (!theme.isEmpty())
        QIcon::setThemeName(theme);
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));
    QStringList pixmaps;
    for (const QString &dir : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        pixmaps << dir + QStringLiteral("/pixmaps");
    QIcon::setFallbackSearchPaths(pixmaps);
}

}

Stack::Stack(QObject *parent)
    : QObject(parent)
{
    setupIcons();
    for (QScreen *s : QGuiApplication::screens())
        addScreen(s);
    connect(qApp, &QGuiApplication::screenAdded, this, &Stack::addScreen);
    connect(qApp, &QGuiApplication::screenRemoved, this, &Stack::removeScreen);
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &Stack::clipboardTextChanged);
}

Stack *Stack::instance()
{
    static Stack *self = new Stack(qApp);
    return self;
}

Stack *Stack::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

void Stack::addScreen(QScreen *screen)
{
    m_screens.append(new ShellScreen(screen, this));
    emit screensChanged();
}

void Stack::removeScreen(QScreen *screen)
{
    for (int i = 0; i < m_screens.size(); i++) {
        if (m_screens[i]->screen() == screen) {
            ShellScreen *gone = m_screens.takeAt(i);
            emit screensChanged();
            gone->deleteLater();
            return;
        }
    }
}

QVariantList Stack::screens() const
{
    QVariantList out;
    out.reserve(m_screens.size());
    for (ShellScreen *s : m_screens)
        out.append(QVariant::fromValue(s));
    return out;
}

ShellScreen *Stack::screenFor(QScreen *screen) const
{
    for (ShellScreen *s : m_screens) {
        if (s->screen() == screen)
            return s;
    }
    return nullptr;
}

QString Stack::clipboardText() const
{
    return QGuiApplication::clipboard()->text();
}

void Stack::setClipboardText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

qint64 Stack::processId() const
{
    return QCoreApplication::applicationPid();
}

void Stack::whenReady(QObject *context, std::function<void()> fn)
{
    if (m_ready)
        fn();
    else
        m_pending.append({QPointer<QObject>(context), std::move(fn)});
}

void Stack::setReady(bool ready)
{
    m_ready = ready;
    if (!ready) {
        m_pending.clear();
        return;
    }
    while (!m_pending.isEmpty()) {
        auto next = m_pending.takeFirst();
        if (next.first)
            next.second();
    }
}

QVariant Stack::env(const QString &name) const
{
    const QByteArray key = name.toLocal8Bit();
    if (!qEnvironmentVariableIsSet(key.constData()))
        return {};
    return qEnvironmentVariable(key.constData());
}

void Stack::execDetached(const QJSValue &command) const
{
    QStringList words;
    QString dir;
    QJSValue env;
    bool clear = false;
    QJSValue list = command;
    if (!command.isArray() && command.isObject()) {
        list = command.property(QStringLiteral("command"));
        dir = command.property(QStringLiteral("workingDirectory")).toString();
        if (command.property(QStringLiteral("workingDirectory")).isUndefined())
            dir.clear();
        env = command.property(QStringLiteral("environment"));
        clear = command.property(QStringLiteral("clearEnvironment")).toBool();
    }
    const int n = list.property(QStringLiteral("length")).toInt();
    for (int i = 0; i < n; i++)
        words << list.property(i).toString();
    if (words.isEmpty() || words.first().isEmpty()) {
        qWarning("sylstack: execDetached needs a command");
        return;
    }
    QProcess p;
    p.setProgram(words.takeFirst());
    p.setArguments(words);
    if (!dir.isEmpty())
        p.setWorkingDirectory(dir);
    if (clear || env.isObject()) {
        QProcessEnvironment e = clear ? QProcessEnvironment() : QProcessEnvironment::systemEnvironment();
        if (env.isObject()) {
            QJSValueIterator it(env);
            while (it.hasNext()) {
                it.next();
                if (it.value().isNull() || it.value().isUndefined())
                    e.remove(it.name());
                else
                    e.insert(it.name(), it.value().toString());
            }
        }
        p.setProcessEnvironment(e);
    }
    p.setStandardInputFile(QProcess::nullDevice());
    p.setStandardOutputFile(QProcess::nullDevice());
    p.setStandardErrorFile(QProcess::nullDevice());
    if (!p.startDetached())
        qWarning("sylstack: could not start %s", qPrintable(p.program()));
}

QString Stack::iconPath(const QString &name, bool check) const
{
    if (name.isEmpty())
        return {};
    if (name.startsWith(QLatin1Char('/')))
        return check && !QFileInfo::exists(name) ? QString() : QUrl::fromLocalFile(name).toString();
    if (name.startsWith(QStringLiteral("file://"))) {
        const QString local = QUrl(name).toLocalFile();
        return check && !QFileInfo::exists(local) ? QString() : name;
    }
    if (name.startsWith(QStringLiteral("image://")) || name.startsWith(QStringLiteral("qrc:")))
        return name;
    if (name.contains(QStringLiteral("://")))
        return {};
    if (check && !QIcon::hasThemeIcon(name)) {
        bool found = false;
        for (const QString &dir : QIcon::fallbackSearchPaths()) {
            for (const char *ext : {".png", ".svg", ".xpm"}) {
                if (QFileInfo::exists(dir + QLatin1Char('/') + name + QLatin1String(ext))) {
                    found = true;
                    break;
                }
            }
        }
        if (!found)
            return {};
    }
    return QStringLiteral("image://icon/") + name;
}

void Stack::reload(bool)
{
    emit reloadRequested();
}

}
