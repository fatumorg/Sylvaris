#include "tray.h"

#include "desktop.h"
#include "stack.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QFileInfo>
#include <QImage>
#include <QUrl>
#include <QtEndian>

namespace stack {

namespace {

const QString ItemIface = QStringLiteral("org.kde.StatusNotifierItem");
const QString WatcherService = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString WatcherPath = QStringLiteral("/StatusNotifierWatcher");
const QString MenuIface = QStringLiteral("com.canonical.dbusmenu");
const QString PropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

QObject *watcherObject = nullptr;

QImage pixmapImage(const QVariant &value)
{
    if (value.userType() != qMetaTypeId<QDBusArgument>())
        return {};
    const QDBusArgument arg = value.value<QDBusArgument>();
    QImage best;
    arg.beginArray();
    while (!arg.atEnd()) {
        int w = 0;
        int h = 0;
        QByteArray bytes;
        arg.beginStructure();
        arg >> w >> h >> bytes;
        arg.endStructure();
        if (w <= 0 || h <= 0 || w > 512 || h > 512 || bytes.size() != static_cast<qsizetype>(w) * h * 4)
            continue;
        if (!best.isNull() && w * h <= best.width() * best.height())
            continue;
        QImage img(w, h, QImage::Format_ARGB32);
        const auto *src = reinterpret_cast<const quint32 *>(bytes.constData());
        for (int y = 0; y < h; y++) {
            auto *line = reinterpret_cast<quint32 *>(img.scanLine(y));
            for (int x = 0; x < w; x++)
                line[x] = qFromBigEndian(src[y * w + x]);
        }
        best = img;
    }
    arg.endArray();
    return best;
}

QString iconFor(const QString &name, const QString &themePath)
{
    if (name.isEmpty())
        return {};
    if (name.startsWith(QLatin1Char('/')))
        return QFileInfo::exists(name) ? QUrl::fromLocalFile(name).toString() : QString();
    if (!themePath.isEmpty()) {
        for (const char *ext : {".png", ".svg", ".xpm"}) {
            const QString file = themePath + QLatin1Char('/') + name + QLatin1String(ext);
            if (QFileInfo::exists(file))
                return QUrl::fromLocalFile(file).toString();
        }
    }
    return Stack::instance()->iconPath(name, false);
}

}

MenuEntry::MenuEntry(int id, DBusMenu *menu)
    : QObject(menu)
    , m_id(id)
    , m_menu(menu)
    , m_children(new ObjectModel(this))
{
}

MenuEntry::~MenuEntry()
{
    ImageStore::drop(iconKey());
}

QString MenuEntry::iconKey() const
{
    return QStringLiteral("menu-") + QString::number(reinterpret_cast<quintptr>(this), 16);
}

void MenuEntry::setProps(const QVariantMap &props)
{
    m_text = props.value(QStringLiteral("label")).toString();
    m_enabled = props.value(QStringLiteral("enabled"), true).toBool();
    m_visible = props.value(QStringLiteral("visible"), true).toBool();
    m_separator = props.value(QStringLiteral("type")).toString() == QStringLiteral("separator");
    m_icon.clear();
    const QByteArray data = props.value(QStringLiteral("icon-data")).toByteArray();
    const QImage img = data.isEmpty() ? QImage() : ImageStore::decode(data, 512);
    if (!img.isNull())
        m_icon = ImageStore::put(iconKey(), img);
    else
        ImageStore::drop(iconKey());
    if (m_icon.isEmpty())
        m_icon = Stack::instance()->iconPath(props.value(QStringLiteral("icon-name")).toString(), true);
    const QString toggle = props.value(QStringLiteral("toggle-type")).toString();
    m_buttonType = toggle == QStringLiteral("checkmark") ? QsMenuButtonType::CheckBox : toggle == QStringLiteral("radio") ? QsMenuButtonType::RadioButton : QsMenuButtonType::None;
    const int state = props.value(QStringLiteral("toggle-state"), 0).toInt();
    m_checkState = state == 1 ? Qt::Checked : state == 0 ? Qt::Unchecked : Qt::PartiallyChecked;
    if (props.value(QStringLiteral("children-display")).toString() == QStringLiteral("submenu"))
        m_hasChildren = true;
    emit changed();
}

void MenuEntry::setHasChildren(bool has)
{
    if (has && !m_hasChildren) {
        m_hasChildren = true;
        emit changed();
    }
}

void MenuEntry::triggered()
{
    m_menu->click(m_id);
}

void MenuEntry::load()
{
    m_menu->load(this);
}

DBusMenu::DBusMenu(const QString &service, const QString &path, QObject *parent)
    : QObject(parent)
    , m_service(service)
    , m_path(path)
    , m_root(new MenuEntry(0, this))
{
    m_entries.insert(0, m_root);
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(service, path, MenuIface, QStringLiteral("LayoutUpdated"), this, SLOT(layoutUpdated(uint, int)));
    bus.connect(service, path, MenuIface, QStringLiteral("ItemsPropertiesUpdated"), this, SLOT(propertiesUpdated(QDBusArgument, QDBusArgument)));
}

MenuEntry *DBusMenu::entry(int id)
{
    MenuEntry *e = m_entries.value(id);
    if (!e) {
        e = new MenuEntry(id, this);
        m_entries.insert(id, e);
    }
    return e;
}

void DBusMenu::load(MenuEntry *target)
{
    QPointer<MenuEntry> guard(target);
    const int id = target->id();
    QDBusMessage about = QDBusMessage::createMethodCall(m_service, m_path, MenuIface, QStringLiteral("AboutToShow"));
    about << id;
    QDBusConnection::sessionBus().asyncCall(about);
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, MenuIface, QStringLiteral("GetLayout"));
    msg << id << 1 << QStringList();
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, guard] {
        const QDBusMessage reply = w->reply();
        w->deleteLater();
        if (!guard || reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2)
            return;
        guard->setLoaded(true);
        applyLayout(guard, reply.arguments().at(1).value<QDBusArgument>());
    });
}

void DBusMenu::applyLayout(MenuEntry *parent, const QDBusArgument &arg)
{
    int id = 0;
    QVariantMap props;
    arg.beginStructure();
    arg >> id >> props;
    if (id == parent->id() && id != 0)
        parent->setProps(props);
    QList<QObject *> children;
    QList<int> kids;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant v;
        arg >> v;
        const QDBusArgument child = v.variant().value<QDBusArgument>();
        int cid = 0;
        QVariantMap cprops;
        child.beginStructure();
        child >> cid >> cprops;
        child.beginArray();
        bool hasKids = false;
        while (!child.atEnd()) {
            QDBusVariant skip;
            child >> skip;
            hasKids = true;
        }
        child.endArray();
        child.endStructure();
        if (cid == parent->id() || kids.contains(cid))
            continue;
        MenuEntry *e = entry(cid);
        e->setProps(cprops);
        e->setHasChildren(hasKids);
        kids << cid;
        if (cprops.value(QStringLiteral("visible"), true).toBool())
            children << e;
    }
    arg.endArray();
    arg.endStructure();
    const QList<int> old = parent->kids();
    parent->setKids(kids);
    parent->children()->replace(children);
    for (int id : old)
        if (!kids.contains(id))
            drop(parent, id);
}

void DBusMenu::drop(MenuEntry *parent, int id)
{
    for (MenuEntry *other : std::as_const(m_entries))
        if (other != parent && other->kids().contains(id))
            return;
    MenuEntry *e = m_entries.value(id);
    if (!e || e == m_root)
        return;
    m_entries.remove(id);
    const QList<int> kids = e->kids();
    e->setKids({});
    e->children()->replace({});
    for (int k : kids)
        drop(e, k);
    e->deleteLater();
}

void DBusMenu::click(int id)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, MenuIface, QStringLiteral("Event"));
    msg << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(0)) << static_cast<uint>(0);
    QDBusConnection::sessionBus().asyncCall(msg);
}

void DBusMenu::layoutUpdated(uint, int parent)
{
    MenuEntry *e = m_entries.value(parent);
    if (e && e->loaded())
        load(e);
    else if (parent == 0 || !e) {
        for (MenuEntry *x : std::as_const(m_entries)) {
            if (x->loaded())
                load(x);
        }
    }
}

void DBusMenu::propertiesUpdated(const QDBusArgument &, const QDBusArgument &)
{
    for (MenuEntry *x : std::as_const(m_entries)) {
        if (x->loaded())
            load(x);
    }
}

void QsMenuOpener::setMenu(QObject *menu)
{
    auto *entry = qobject_cast<MenuEntry *>(menu);
    if (entry == m_menu)
        return;
    m_menu = entry;
    if (m_menu)
        m_menu->load();
    emit menuChanged();
}

ObjectModel *QsMenuOpener::children() const
{
    return m_menu ? m_menu->children() : m_none;
}

SystemTrayItem::SystemTrayItem(const QString &service, const QString &path, QObject *parent)
    : QObject(parent)
    , m_service(service)
    , m_path(path)
{
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(80);
    connect(&m_debounce, &QTimer::timeout, this, &SystemTrayItem::refresh);
    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const char *sig : {"NewIcon", "NewAttentionIcon", "NewOverlayIcon", "NewTitle", "NewStatus", "NewToolTip", "NewMenu"})
        bus.connect(service, path, ItemIface, QString::fromLatin1(sig), &m_debounce, SLOT(start()));
    refresh();
}

SystemTrayItem::~SystemTrayItem()
{
    ImageStore::drop(QStringLiteral("tray-") + QString::fromLatin1(QCryptographicHash::hash(key().toUtf8(), QCryptographicHash::Md5).toHex()));
}

void SystemTrayItem::refresh()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, PropsIface, QStringLiteral("GetAll"));
    msg << ItemIface;
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        QDBusPendingReply<QVariantMap> reply = *w;
        w->deleteLater();
        if (!reply.isError())
            apply(reply.value());
    });
}

void SystemTrayItem::apply(const QVariantMap &props)
{
    m_id = props.value(QStringLiteral("Id")).toString();
    m_title = props.value(QStringLiteral("Title")).toString();
    m_status = props.value(QStringLiteral("Status")).toString();
    m_onlyMenu = props.value(QStringLiteral("ItemIsMenu")).toBool();
    const QString menuPath = props.value(QStringLiteral("Menu")).value<QDBusObjectPath>().path();
    if (menuPath != m_menuPath) {
        m_menuPath = menuPath;
        delete m_menu;
        m_menu = nullptr;
    }
    const QString themePath = props.value(QStringLiteral("IconThemePath")).toString();
    const bool attention = m_status == QStringLiteral("NeedsAttention");
    QString icon;
    if (attention)
        icon = iconFor(props.value(QStringLiteral("AttentionIconName")).toString(), themePath);
    if (icon.isEmpty())
        icon = iconFor(props.value(QStringLiteral("IconName")).toString(), themePath);
    if (icon.isEmpty()) {
        QImage img = attention ? pixmapImage(props.value(QStringLiteral("AttentionIconPixmap"))) : QImage();
        if (img.isNull())
            img = pixmapImage(props.value(QStringLiteral("IconPixmap")));
        if (!img.isNull())
            icon = ImageStore::put(QStringLiteral("tray-") + QString::fromLatin1(QCryptographicHash::hash(key().toUtf8(), QCryptographicHash::Md5).toHex()), img);
    }
    m_icon = icon;
    m_tooltipTitle.clear();
    m_tooltipDescription.clear();
    const QVariant tip = props.value(QStringLiteral("ToolTip"));
    if (tip.userType() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument arg = tip.value<QDBusArgument>();
        QString iconName;
        arg.beginStructure();
        arg >> iconName;
        arg.beginArray();
        while (!arg.atEnd()) {
            int w;
            int h;
            QByteArray bytes;
            arg.beginStructure();
            arg >> w >> h >> bytes;
            arg.endStructure();
        }
        arg.endArray();
        arg >> m_tooltipTitle >> m_tooltipDescription;
        arg.endStructure();
    }
    emit changed();
}

QObject *SystemTrayItem::menu()
{
    if (!hasMenu())
        return nullptr;
    if (!m_menu)
        m_menu = new DBusMenu(m_service, m_menuPath, this);
    return m_menu->root();
}

void SystemTrayItem::call(const QString &method, const QVariantList &args)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, ItemIface, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg);
}

void SystemTrayItem::activate()
{
    call(QStringLiteral("Activate"), {0, 0});
}

void SystemTrayItem::secondaryActivate()
{
    call(QStringLiteral("SecondaryActivate"), {0, 0});
}

void SystemTrayItem::scroll(int delta, bool horizontal)
{
    call(QStringLiteral("Scroll"), {delta, horizontal ? QStringLiteral("horizontal") : QStringLiteral("vertical")});
}

void SystemTrayItem::display(QObject *, int x, int y)
{
    call(QStringLiteral("ContextMenu"), {x, y});
}

TrayWatcherAdaptor::TrayWatcherAdaptor(QObject *parent)
    : QDBusAbstractAdaptor(parent)
{
    setAutoRelaySignals(false);
}

QStringList TrayWatcherAdaptor::items() const
{
    return SystemTray::instance()->registered();
}

void TrayWatcherAdaptor::RegisterStatusNotifierItem(const QString &service, const QDBusMessage &message)
{
    SystemTray::instance()->registerItem(service, message.service());
}

void TrayWatcherAdaptor::RegisterStatusNotifierHost(const QString &)
{
    emit StatusNotifierHostRegistered();
}

SystemTray::SystemTray()
    : m_items(new ObjectModel(this))
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return;
    m_watcher.setConnection(bus);
    m_watcher.setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(&m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &SystemTray::removeService);
    watcherObject = new QObject(this);
    auto *adaptor = new TrayWatcherAdaptor(watcherObject);
    if (bus.registerObject(WatcherPath, watcherObject) && bus.registerService(WatcherService)) {
        m_isWatcher = true;
        emit adaptor->StatusNotifierHostRegistered();
        return;
    }
    bus.unregisterObject(WatcherPath);
    becomeHost();
}

SystemTray *SystemTray::instance()
{
    static SystemTray *self = new SystemTray();
    return self;
}

SystemTray *SystemTray::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

void SystemTray::becomeHost()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QString host = QStringLiteral("org.kde.StatusNotifierHost-%1-1").arg(QCoreApplication::applicationPid());
    bus.registerService(host);
    bus.connect(WatcherService, WatcherPath, WatcherService, QStringLiteral("StatusNotifierItemRegistered"), this, SLOT(itemRegistered(QString)));
    bus.connect(WatcherService, WatcherPath, WatcherService, QStringLiteral("StatusNotifierItemUnregistered"), this, SLOT(itemUnregistered(QString)));
    QDBusMessage reg = QDBusMessage::createMethodCall(WatcherService, WatcherPath, WatcherService, QStringLiteral("RegisterStatusNotifierHost"));
    reg << host;
    bus.asyncCall(reg);
    QDBusMessage get = QDBusMessage::createMethodCall(WatcherService, WatcherPath, PropsIface, QStringLiteral("Get"));
    get << WatcherService << QStringLiteral("RegisteredStatusNotifierItems");
    auto *w = new QDBusPendingCallWatcher(bus.asyncCall(get), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        QDBusPendingReply<QDBusVariant> reply = *w;
        w->deleteLater();
        if (reply.isError())
            return;
        for (const QString &spec : reply.value().variant().toStringList())
            itemRegistered(spec);
    });
}

QStringList SystemTray::registered() const
{
    QStringList out;
    for (auto it = m_byKey.cbegin(); it != m_byKey.cend(); ++it)
        out << it.key();
    return out;
}

void SystemTray::registerItem(const QString &spec, const QString &sender)
{
    QString service = spec;
    QString path = QStringLiteral("/StatusNotifierItem");
    if (spec.startsWith(QLatin1Char('/'))) {
        service = sender;
        path = spec;
    } else if (const int slash = spec.indexOf(QLatin1Char('/')); slash > 0) {
        service = spec.left(slash);
        path = spec.mid(slash);
    }
    add(service, path);
}

void SystemTray::itemRegistered(const QString &spec)
{
    registerItem(spec, QString());
}

void SystemTray::itemUnregistered(const QString &spec)
{
    QString service = spec;
    const int slash = spec.indexOf(QLatin1Char('/'));
    if (slash > 0)
        service = spec.left(slash);
    removeService(service);
}

void SystemTray::add(const QString &service, const QString &path)
{
    if (service.isEmpty())
        return;
    const QString key = service + path;
    if (m_byKey.contains(key))
        return;
    auto *item = new SystemTrayItem(service, path, this);
    m_byKey.insert(key, item);
    m_items->insert(item);
    m_watcher.addWatchedService(service);
    if (m_isWatcher) {
        if (auto *a = watcherObject->findChild<TrayWatcherAdaptor *>())
            emit a->StatusNotifierItemRegistered(key);
    }
}

void SystemTray::removeService(const QString &service)
{
    for (auto it = m_byKey.begin(); it != m_byKey.end();) {
        if (it.key().startsWith(service + QLatin1Char('/'))) {
            SystemTrayItem *item = it.value();
            const QString key = it.key();
            it = m_byKey.erase(it);
            m_items->remove(item);
            item->deleteLater();
            if (m_isWatcher) {
                if (auto *a = watcherObject->findChild<TrayWatcherAdaptor *>())
                    emit a->StatusNotifierItemUnregistered(key);
            }
        } else {
            ++it;
        }
    }
    m_watcher.removeWatchedService(service);
}

}
