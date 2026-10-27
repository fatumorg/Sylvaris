#pragma once

#include "model.h"

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QVariantMap>

namespace stack {

namespace NotificationUrgency {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Low = 0, Normal = 1, Critical = 2 };
Q_ENUM_NS(Enum)
}

namespace NotificationCloseReason {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Expired = 1, Dismissed = 2, CloseRequested = 3 };
Q_ENUM_NS(Enum)
}

class Notification;
class NotificationServer;

class NotificationAction : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("actions come from notifications")
    Q_PROPERTY(QString identifier MEMBER identifier CONSTANT)
    Q_PROPERTY(QString text MEMBER text CONSTANT)

public:
    NotificationAction(const QString &id, const QString &label, Notification *parent);
    Q_INVOKABLE void invoke();

    QString identifier;
    QString text;

private:
    Notification *m_notification;
};

class Notification : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("notifications come from NotificationServer")
    Q_PROPERTY(int id READ id CONSTANT)
    Q_PROPERTY(bool tracked MEMBER m_tracked NOTIFY trackedChanged)
    Q_PROPERTY(QString appName MEMBER appName NOTIFY changed)
    Q_PROPERTY(QString appIcon MEMBER appIcon NOTIFY changed)
    Q_PROPERTY(QString summary MEMBER summary NOTIFY changed)
    Q_PROPERTY(QString body MEMBER body NOTIFY changed)
    Q_PROPERTY(QString image MEMBER image NOTIFY changed)
    Q_PROPERTY(QString desktopEntry MEMBER desktopEntry NOTIFY changed)
    Q_PROPERTY(int urgency MEMBER urgency NOTIFY changed)
    Q_PROPERTY(int expireTimeout MEMBER expireTimeout NOTIFY changed)
    Q_PROPERTY(bool resident MEMBER resident NOTIFY changed)
    Q_PROPERTY(bool transient MEMBER transient NOTIFY changed)
    Q_PROPERTY(bool hasInlineReply MEMBER hasInlineReply NOTIFY changed)
    Q_PROPERTY(QString inlineReplyPlaceholder MEMBER inlineReplyPlaceholder NOTIFY changed)
    Q_PROPERTY(QVariantMap hints MEMBER hints NOTIFY changed)
    Q_PROPERTY(QList<QObject *> actions READ actions NOTIFY changed)

public:
    Notification(quint32 id, NotificationServer *server);
    ~Notification() override;

    int id() const { return static_cast<int>(m_id); }
    bool isTracked() const { return m_tracked; }
    QList<QObject *> actions() const { return m_actions; }
    void fill(const QString &app, const QString &icon, const QString &summary, const QString &body, const QStringList &actions, const QVariantMap &hints, int timeout);

    Q_INVOKABLE void dismiss();
    Q_INVOKABLE void expire();
    Q_INVOKABLE void sendInlineReply(const QString &text);
    void invokeAction(const QString &key);
    void close(int reason);

    QString appName;
    QString appIcon;
    QString summary;
    QString body;
    QString image;
    QString desktopEntry;
    int urgency = NotificationUrgency::Normal;
    int expireTimeout = -1;
    bool resident = false;
    bool transient = false;
    bool hasInlineReply = false;
    QString inlineReplyPlaceholder;
    QVariantMap hints;

signals:
    void changed();
    void trackedChanged();
    void closed(int reason);

private:
    quint32 m_id;
    bool m_tracked = false;
    bool m_closed = false;
    QPointer<NotificationServer> m_server;
    QList<QObject *> m_actions;
};

class NotificationServer : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool keepOnReload MEMBER m_keep NOTIFY capsChanged)
    Q_PROPERTY(bool persistenceSupported MEMBER m_persistence NOTIFY capsChanged)
    Q_PROPERTY(bool bodySupported MEMBER m_body NOTIFY capsChanged)
    Q_PROPERTY(bool bodyMarkupSupported MEMBER m_markup NOTIFY capsChanged)
    Q_PROPERTY(bool bodyHyperlinksSupported MEMBER m_links NOTIFY capsChanged)
    Q_PROPERTY(bool bodyImagesSupported MEMBER m_bodyImages NOTIFY capsChanged)
    Q_PROPERTY(bool actionsSupported MEMBER m_actions NOTIFY capsChanged)
    Q_PROPERTY(bool imageSupported MEMBER m_images NOTIFY capsChanged)
    Q_PROPERTY(bool inlineReplySupported MEMBER m_reply NOTIFY capsChanged)
    Q_PROPERTY(stack::ObjectModel *trackedNotifications READ tracked CONSTANT)

public:
    explicit NotificationServer(QObject *parent = nullptr);
    ~NotificationServer() override;

    ObjectModel *tracked() const { return m_tracked; }
    QStringList capabilities() const;
    quint32 notify(const QString &app, quint32 replaces, const QString &icon, const QString &summary, const QString &body, const QStringList &actions,
                   const QVariantMap &hints, int timeout);
    void closeRequested(quint32 id);
    void closedSignal(quint32 id, int reason);
    void actionSignal(quint32 id, const QString &key);
    void replySignal(quint32 id, const QString &text);
    void forget(Notification *n);

    void classBegin() override {}
    void componentComplete() override;

signals:
    void notification(stack::Notification *notification);
    void capsChanged();

private:
    bool m_keep = false;
    bool m_persistence = false;
    bool m_body = true;
    bool m_markup = false;
    bool m_links = false;
    bool m_bodyImages = false;
    bool m_actions = false;
    bool m_images = false;
    bool m_reply = false;
    bool m_registered = false;
    quint32 m_next = 1;
    ObjectModel *m_tracked;
    QHash<quint32, Notification *> m_live;
};

class NotificationAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationAdaptor(NotificationServer *server);

public slots:
    QStringList GetCapabilities();
    QString GetServerInformation(QString &vendor, QString &version, QString &specVersion);
    quint32 Notify(const QString &app_name, quint32 replaces_id, const QString &app_icon, const QString &summary, const QString &body, const QStringList &actions,
                   const QVariantMap &hints, int expire_timeout);
    void CloseNotification(quint32 id);

signals:
    void NotificationClosed(quint32 id, quint32 reason);
    void ActionInvoked(quint32 id, const QString &action_key);
    void NotificationReplied(quint32 id, const QString &text);

private:
    NotificationServer *m_server;
};

}
