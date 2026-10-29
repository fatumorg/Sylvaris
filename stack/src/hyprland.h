#pragma once

#include "model.h"
#include "toplevel.h"

#include <QLocalSocket>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QSet>
#include <QTimer>
#include <QVariantMap>

#include <functional>

namespace stack {



class HyprlandMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("monitors come from Hyprland")
    Q_PROPERTY(QString name MEMBER name CONSTANT)

public:
    using QObject::QObject;
    QString name;
};

class HyprlandToplevel : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("toplevels come from Hyprland")
    Q_PROPERTY(QString address MEMBER address CONSTANT)
    Q_PROPERTY(stack::Toplevel *wayland READ wayland NOTIFY waylandChanged)

public:
    using QObject::QObject;
    Toplevel *wayland() const;
    void relink();

    QString address;
    int workspace = 0;

signals:
    void waylandChanged();

private:
    QPointer<Toplevel> m_wayland;
};

class HyprlandWorkspace : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("workspaces come from Hyprland")
    Q_PROPERTY(int id MEMBER id CONSTANT)
    Q_PROPERTY(QString name MEMBER name NOTIFY changed)
    Q_PROPERTY(stack::HyprlandMonitor *monitor MEMBER monitor NOTIFY changed)
    Q_PROPERTY(bool active MEMBER active NOTIFY changed)
    Q_PROPERTY(bool focused MEMBER focused NOTIFY changed)
    Q_PROPERTY(bool urgent MEMBER urgent NOTIFY changed)
    Q_PROPERTY(stack::ObjectModel *toplevels READ toplevels CONSTANT)

public:
    explicit HyprlandWorkspace(QObject *parent)
        : QObject(parent)
        , m_toplevels(new ObjectModel(this))
    {
    }
    ObjectModel *toplevels() const { return m_toplevels; }

    int id = 0;
    QString name;
    HyprlandMonitor *monitor = nullptr;
    bool active = false;
    bool focused = false;
    bool urgent = false;

signals:
    void changed();

private:
    ObjectModel *m_toplevels;
};

class Hyprland : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool usingLua READ usingLua NOTIFY usingLuaChanged)
    Q_PROPERTY(stack::ObjectModel *workspaces READ workspaces CONSTANT)
    Q_PROPERTY(stack::ObjectModel *toplevels READ toplevels CONSTANT)
    Q_PROPERTY(stack::ObjectModel *monitors READ monitors CONSTANT)
    Q_PROPERTY(stack::HyprlandMonitor *focusedMonitor READ focusedMonitor NOTIFY focusedMonitorChanged)

public:
    static Hyprland *create(QQmlEngine *, QJSEngine *);

    bool usingLua() const { return m_lua; }
    ObjectModel *workspaces() const { return m_workspaces; }
    ObjectModel *toplevels() const { return m_toplevels; }
    ObjectModel *monitors() const { return m_monitors; }
    HyprlandMonitor *focusedMonitor() const { return m_focused; }

    Q_INVOKABLE void dispatch(const QString &request);
    Q_INVOKABLE void refresh();

signals:
    void usingLuaChanged();
    void focusedMonitorChanged();
    void rawEvent(const QVariantMap &event);

private:
    Hyprland();
    void request(const QByteArray &req, std::function<void(const QByteArray &)> done);
    void connectEvents();
    void event(const QByteArray &line);
    void apply();

    QString m_dir;
    bool m_valid = false;
    bool m_lua = false;
    QLocalSocket m_events;
    QByteArray m_buffer;
    QTimer m_debounce;
    QTimer m_retry;
    QByteArray m_monitorsJson;
    QByteArray m_workspacesJson;
    QByteArray m_clientsJson;
    int m_pending = 0;
    bool m_again = false;
    QSet<QString> m_urgent;
    ObjectModel *m_workspaces;
    ObjectModel *m_toplevels;
    ObjectModel *m_monitors;
    QHash<int, HyprlandWorkspace *> m_wsById;
    QHash<QString, HyprlandToplevel *> m_tlByAddr;
    QHash<QString, HyprlandMonitor *> m_monByName;
    HyprlandMonitor *m_focused = nullptr;
};

}
