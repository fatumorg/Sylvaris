#include "notifications.h"

#include "desktop.h"
#include "stack.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QFileInfo>
#include <QImage>
#include <QUrl>

namespace stack {

namespace {

QImage imageFromHint(const QVariant &value)
{
    if (value.userType() != qMetaTypeId<QDBusArgument>())
        return {};
    const QDBusArgument arg = value.value<QDBusArgument>();
    int width = 0;
    int height = 0;
    int stride = 0;
    bool alpha = false;
    int bits = 0;
    int channels = 0;
    QByteArray data;
    arg.beginStructure();
    arg >> width >> height >> stride >> alpha >> bits >> channels >> data;
    arg.endStructure();
    if (width <= 0 || height <= 0 || width > 4096 || height > 4096 || bits != 8 || (channels != 3 && channels != 4) || (alpha && channels != 4))
        return {};
    const qint64 row = static_cast<qint64>(width) * channels;
    if (stride < row || static_cast<qint64>(data.size()) < static_cast<qint64>(stride) * (height - 1) + row)
        return {};
    QImage out(width, height, channels == 4 ? QImage::Format_RGBA8888 : QImage::Format_RGB888);
    for (int y = 0; y < height; y++)
        std::memcpy(out.scanLine(y), data.constData() + static_cast<qint64>(y) * stride, static_cast<size_t>(row));
    return out;
}

QString imageUrl(const QString &value)
{
    if (value.isEmpty())
        return {};
    if (value.startsWith(QStringLiteral("file://")))
        return value;
    if (value.startsWith(QLatin1Char('/')))
        return QUrl::fromLocalFile(value).toString();
    if (value.contains(QStringLiteral("://")))
        return {};
    return Stack::instance()->iconPath(value, true);
}

QVariantMap plainHints(const QVariantMap &hints)
{
    QVariantMap out;
    for (auto it = hints.cbegin(); it != hints.cend(); ++it) {
        if (it.value().userType() == qMetaTypeId<QDBusArgument>())
            continue;
        out.insert(it.key(), it.value());
    }
    return out;
}

}

NotificationAction::NotificationAction(const QString &id, const QString &label, Notification *parent)
    : QObject(parent)
    , identifier(id)
    , text(label)
    , m_notification(parent)
{
}

void NotificationAction::invoke()
{
    m_notification->invokeAction(identifier);
}

Notification::Notification(quint32 id, NotificationServer *server)
    : QObject(server)
    , m_id(id)
    , m_server(server)
{
}

Notification::~Notification()
{
    ImageStore::drop(QStringLiteral("notification-") + QString::number(m_id));
}

void Notification::fill(const QString &app, const QString &icon, const QString &sum, const QString &text, const QStringList &acts, const QVariantMap &h, int timeout)
{
    appName = app;
    appIcon = icon;
    summary = sum;
    body = text;
    expireTimeout = timeout;
    hints = plainHints(h);
    urgency = std::clamp(h.value(QStringLiteral("urgency"), 1).toInt(), 0, 2);
    resident = h.value(QStringLiteral("resident")).toBool();
    transient = h.value(QStringLiteral("transient")).toBool();
    desktopEntry = h.value(QStringLiteral("desktop-entry")).toString();
    inlineReplyPlaceholder = h.value(QStringLiteral("x-kde-reply-placeholder-text")).toString();
    image.clear();
    for (const char *key : {"image-data", "image_data", "icon_data"}) {
        const QImage img = imageFromHint(h.value(QString::fromLatin1(key)));
        if (!img.isNull()) {
            image = ImageStore::put(QStringLiteral("notification-") + QString::number(m_id), img);
            break;
        }
    }
    if (image.isEmpty()) {
        for (const char *key : {"image-path", "image_path"}) {
            const QString v = h.value(QString::fromLatin1(key)).toString();
            if (!v.isEmpty()) {
                image = imageUrl(v);
                break;
            }
        }
    }
    qDeleteAll(m_actions);
    m_actions.clear();
    hasInlineReply = false;
    for (int i = 0; i + 1 < acts.size(); i += 2) {
        if (acts[i] == QStringLiteral("inline-reply")) {
            hasInlineReply = true;
            if (inlineReplyPlaceholder.isEmpty())
                inlineReplyPlaceholder = acts[i + 1];
            continue;
        }
        m_actions << new NotificationAction(acts[i], acts[i + 1], this);
    }
    emit changed();
}

void Notification::dismiss()
{
    close(NotificationCloseReason::Dismissed);
}

void Notification::expire()
{
    close(NotificationCloseReason::Expired);
}

void Notification::sendInlineReply(const QString &text)
{
    if (m_server && hasInlineReply)
        m_server->replySignal(m_id, text);
}

void Notification::invokeAction(const QString &key)
{
    if (!m_server)
        return;
    m_server->actionSignal(m_id, key);
    if (!resident)
        close(NotificationCloseReason::Dismissed);
}

void Notification::close(int reason)
{
    if (m_closed)
        return;
    m_closed = true;
    if (m_server)
        m_server->closedSignal(m_id, reason);
    emit closed(reason);
    if (m_server)
        m_server->forget(this);
}

NotificationServer::NotificationServer(QObject *parent)
    : QObject(parent)
    , m_tracked(new ObjectModel(this))
{
}

NotificationServer::~NotificationServer()
{
    if (m_registered) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        bus.unregisterObject(QStringLiteral("/org/freedesktop/Notifications"));
        bus.unregisterService(QStringLiteral("org.freedesktop.Notifications"));
    }
}

void NotificationServer::componentComplete()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning("sylstack: no session bus, notifications are off");
        return;
    }
    new NotificationAdaptor(this);
    if (!bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this)) {
        qWarning("sylstack: could not register the notification object");
        return;
    }
    if (!bus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        qWarning("sylstack: another notification daemon is running, Sylvaris notifications are off");
        bus.unregisterObject(QStringLiteral("/org/freedesktop/Notifications"));
        return;
    }
    m_registered = true;
}

QStringList NotificationServer::capabilities() const
{
    QStringList caps;
    if (m_body)
        caps << QStringLiteral("body");
    if (m_markup)
        caps << QStringLiteral("body-markup");
    if (m_links)
        caps << QStringLiteral("body-hyperlinks");
    if (m_bodyImages)
        caps << QStringLiteral("body-images");
    if (m_actions)
        caps << QStringLiteral("actions");
    if (m_images)
        caps << QStringLiteral("icon-static");
    if (m_persistence)
        caps << QStringLiteral("persistence");
    if (m_reply)
        caps << QStringLiteral("inline-reply");
    return caps;
}

quint32 NotificationServer::notify(const QString &app, quint32 replaces, const QString &icon, const QString &summary, const QString &body, const QStringList &actions,
                                   const QVariantMap &hints, int timeout)
{
    if (Notification *old = replaces ? m_live.value(replaces) : nullptr) {
        old->fill(app, icon, summary, body, m_actions ? actions : QStringList(), hints, timeout);
        return replaces;
    }
    auto *n = new Notification(m_next++, this);
    if (m_next == 0)
        m_next = 1;
    QQmlEngine::setObjectOwnership(n, QQmlEngine::CppOwnership);
    n->fill(app, icon, summary, body, m_actions ? actions : QStringList(), hints, timeout);
    emit notification(n);
    const quint32 id = static_cast<quint32>(n->id());
    if (!n->isTracked()) {
        QMetaObject::invokeMethod(this, [this, id] { closedSignal(id, NotificationCloseReason::Dismissed); }, Qt::QueuedConnection);
        delete n;
        return id;
    }
    m_live.insert(id, n);
    m_tracked->insert(n);
    return id;
}

void NotificationServer::closeRequested(quint32 id)
{
    if (Notification *n = m_live.value(id))
        n->close(NotificationCloseReason::CloseRequested);
}

void NotificationServer::forget(Notification *n)
{
    m_live.remove(static_cast<quint32>(n->id()));
    m_tracked->remove(n);
    n->deleteLater();
}

void NotificationServer::closedSignal(quint32 id, int reason)
{
    if (auto *a = findChild<NotificationAdaptor *>())
        emit a->NotificationClosed(id, static_cast<quint32>(reason));
}

void NotificationServer::actionSignal(quint32 id, const QString &key)
{
    if (auto *a = findChild<NotificationAdaptor *>())
        emit a->ActionInvoked(id, key);
}

void NotificationServer::replySignal(quint32 id, const QString &text)
{
    if (auto *a = findChild<NotificationAdaptor *>())
        emit a->NotificationReplied(id, text);
}

NotificationAdaptor::NotificationAdaptor(NotificationServer *server)
    : QDBusAbstractAdaptor(server)
    , m_server(server)
{
}

QStringList NotificationAdaptor::GetCapabilities()
{
    return m_server->capabilities();
}

QString NotificationAdaptor::GetServerInformation(QString &vendor, QString &version, QString &specVersion)
{
    vendor = QStringLiteral("Sylvaris");
    version = QStringLiteral(SYLSTACK_VERSION);
    specVersion = QStringLiteral("1.2");
    return QStringLiteral("Sylvaris");
}

quint32 NotificationAdaptor::Notify(const QString &app_name, quint32 replaces_id, const QString &app_icon, const QString &summary, const QString &body,
                                    const QStringList &actions, const QVariantMap &hints, int expire_timeout)
{
    return m_server->notify(app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout);
}

void NotificationAdaptor::CloseNotification(quint32 id)
{
    m_server->closeRequested(id);
}

}
