#include "hyprland.h"

#include "toplevel.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <climits>
#include <memory>

namespace stack {

Toplevel *HyprlandToplevel::wayland() const
{
    return m_wayland;
}

void HyprlandToplevel::relink()
{
    Toplevel *t = ToplevelManager::instance()->byAddress(address);
    if (t != m_wayland) {
        m_wayland = t;
        emit waylandChanged();
    }
}

Hyprland::Hyprland()
    : m_workspaces(new ObjectModel(this))
    , m_toplevels(new ObjectModel(this))
    , m_monitors(new ObjectModel(this))
{
    const QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (sig.isEmpty())
        return;
    const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    for (const QString &base : {runtime + QStringLiteral("/hypr/"), QStringLiteral("/tmp/hypr/")}) {
        if (QFileInfo::exists(base + sig + QStringLiteral("/.socket.sock"))) {
            m_dir = base + sig;
            break;
        }
    }
    if (m_dir.isEmpty())
        return;
    m_valid = true;
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(30);
    connect(&m_debounce, &QTimer::timeout, this, &Hyprland::refresh);
    m_retry.setSingleShot(true);
    m_retry.setInterval(2000);
    connect(&m_retry, &QTimer::timeout, this, &Hyprland::connectEvents);
    connect(&m_events, &QLocalSocket::readyRead, this, [this] {
        m_buffer += m_events.readAll();
        qsizetype nl;
        while ((nl = m_buffer.indexOf('\n')) >= 0) {
            const QByteArray line = m_buffer.left(nl);
            m_buffer.remove(0, nl + 1);
            event(line);
        }
    });
    connect(&m_events, &QLocalSocket::disconnected, &m_retry, qOverload<>(&QTimer::start));
    connect(&m_events, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        if (m_events.state() != QLocalSocket::ConnectedState)
            m_retry.start();
    });
    connect(ToplevelManager::instance(), &ToplevelManager::addressesChanged, this, [this] {
        for (HyprlandToplevel *t : std::as_const(m_tlByAddr))
            t->relink();
    });
    request("j/status", [this](const QByteArray &reply) {
        const bool lua = reply != "unknown request" && QJsonDocument::fromJson(reply).object().value(QStringLiteral("configProvider")).toString() == QStringLiteral("lua");
        if (lua != m_lua) {
            m_lua = lua;
            emit usingLuaChanged();
        }
        connectEvents();
        refresh();
    });
}

Hyprland *Hyprland::create(QQmlEngine *, QJSEngine *)
{
    static Hyprland *self = new Hyprland();
    QJSEngine::setObjectOwnership(self, QJSEngine::CppOwnership);
    return self;
}

void Hyprland::request(const QByteArray &req, std::function<void(const QByteArray &)> done)
{
    if (!m_valid)
        return;
    auto *socket = new QLocalSocket(this);
    auto reply = std::make_shared<QByteArray>();
    auto finished = std::make_shared<bool>(false);
    connect(socket, &QLocalSocket::readyRead, socket, [socket, reply] { reply->append(socket->readAll()); });
    auto finish = [socket, reply, finished, done] {
        if (*finished)
            return;
        *finished = true;
        if (socket->isOpen())
            reply->append(socket->readAll());
        socket->deleteLater();
        if (done)
            done(*reply);
    };
    connect(socket, &QLocalSocket::disconnected, socket, finish);
    connect(socket, &QLocalSocket::errorOccurred, socket, [socket, finish](QLocalSocket::LocalSocketError e) {
        if (e != QLocalSocket::PeerClosedError && socket->state() != QLocalSocket::ConnectedState)
            finish();
    });
    socket->connectToServer(m_dir + QStringLiteral("/.socket.sock"));
    if (socket->waitForConnected(1000)) {
        socket->write(req);
        socket->flush();
    }
}

void Hyprland::connectEvents()
{
    if (!m_valid || m_events.state() != QLocalSocket::UnconnectedState)
        return;
    m_buffer.clear();
    m_events.connectToServer(m_dir + QStringLiteral("/.socket2.sock"), QIODevice::ReadOnly);
}

void Hyprland::event(const QByteArray &line)
{
    const qsizetype sep = line.indexOf(">>");
    if (sep < 0)
        return;
    const QByteArray name = line.left(sep);
    const QByteArray data = line.mid(sep + 2);
    if (name == "urgent") {
        m_urgent.insert(QStringLiteral("0x") + QString::fromUtf8(data));
    } else if (name == "activewindowv2") {
        m_urgent.remove(QStringLiteral("0x") + QString::fromUtf8(data));
    } else if (name == "activewindow" || name == "windowtitle" || name == "windowtitlev2" || name == "activelayout" || name == "submap"
               || name == "screencast" || name == "bell" || name == "configreloaded" || name == "pin") {
        return;
    }
    m_debounce.start();
}

void Hyprland::dispatch(const QString &command)
{
    request("dispatch " + command.toUtf8(), [command](const QByteArray &reply) {
        if (reply.trimmed() != "ok")
            qWarning("sylstack: hyprland dispatch %s failed: %s", qPrintable(command), reply.constData());
    });
}

void Hyprland::refresh()
{
    if (!m_valid)
        return;
    if (m_pending > 0) {
        m_again = true;
        return;
    }
    m_pending = 3;
    auto step = [this](QByteArray *slot) {
        return [this, slot](const QByteArray &reply) {
            *slot = reply;
            if (--m_pending == 0) {
                apply();
                if (m_again) {
                    m_again = false;
                    m_debounce.start();
                }
            }
        };
    };
    request("j/monitors", step(&m_monitorsJson));
    request("j/workspaces", step(&m_workspacesJson));
    request("j/clients", step(&m_clientsJson));
}

void Hyprland::apply()
{
    const QJsonArray monitors = QJsonDocument::fromJson(m_monitorsJson).array();
    const QJsonArray workspaces = QJsonDocument::fromJson(m_workspacesJson).array();
    const QJsonArray clients = QJsonDocument::fromJson(m_clientsJson).array();
    if (monitors.isEmpty() && workspaces.isEmpty())
        return;

    QSet<int> active;
    int focusedWs = INT_MIN;
    HyprlandMonitor *focused = nullptr;
    QList<QObject *> monList;
    QHash<QString, HyprlandMonitor *> monNext;
    for (const QJsonValue &v : monitors) {
        const QJsonObject o = v.toObject();
        const QString name = o.value(QStringLiteral("name")).toString();
        HyprlandMonitor *m = m_monByName.take(name);
        if (!m) {
            m = new HyprlandMonitor(this);
            m->name = name;
        }
        monNext.insert(name, m);
        monList << m;
        const int ws = o.value(QStringLiteral("activeWorkspace")).toObject().value(QStringLiteral("id")).toInt(INT_MIN);
        active.insert(ws);
        const int special = o.value(QStringLiteral("specialWorkspace")).toObject().value(QStringLiteral("id")).toInt(0);
        if (special != 0)
            active.insert(special);
        if (o.value(QStringLiteral("focused")).toBool()) {
            focused = m;
            focusedWs = ws;
        }
    }

    QHash<int, QList<QObject *>> byWs;
    QHash<QString, HyprlandToplevel *> tlNext;
    QList<QObject *> tlList;
    for (const QJsonValue &v : clients) {
        const QJsonObject o = v.toObject();
        const QString addr = o.value(QStringLiteral("address")).toString();
        if (addr.isEmpty())
            continue;
        HyprlandToplevel *t = m_tlByAddr.take(addr);
        if (!t) {
            t = new HyprlandToplevel(this);
            t->address = addr;
        }
        t->workspace = o.value(QStringLiteral("workspace")).toObject().value(QStringLiteral("id")).toInt();
        t->relink();
        tlNext.insert(addr, t);
        tlList << t;
        byWs[t->workspace] << t;
    }

    QList<QObject *> wsList;
    QHash<int, HyprlandWorkspace *> wsNext;
    for (const QJsonValue &v : workspaces) {
        const QJsonObject o = v.toObject();
        const int id = o.value(QStringLiteral("id")).toInt();
        HyprlandWorkspace *w = m_wsById.take(id);
        if (!w) {
            w = new HyprlandWorkspace(this);
            w->id = id;
        }
        const bool isFocused = id == focusedWs;
        if (isFocused) {
            for (QObject *o2 : byWs.value(id))
                m_urgent.remove(static_cast<HyprlandToplevel *>(o2)->address);
        }
        bool urgent = false;
        for (QObject *o2 : byWs.value(id))
            urgent = urgent || m_urgent.contains(static_cast<HyprlandToplevel *>(o2)->address);
        const QString name = o.value(QStringLiteral("name")).toString();
        HyprlandMonitor *mon = monNext.value(o.value(QStringLiteral("monitor")).toString());
        const bool isActive = active.contains(id);
        w->toplevels()->replace(byWs.value(id));
        if (w->name != name || w->monitor != mon || w->active != isActive || w->focused != isFocused || w->urgent != urgent) {
            w->name = name;
            w->monitor = mon;
            w->active = isActive;
            w->focused = isFocused;
            w->urgent = urgent;
            emit w->changed();
        }
        wsNext.insert(id, w);
        wsList << w;
    }

    for (const QString &addr : m_urgent.values()) {
        if (!tlNext.contains(addr))
            m_urgent.remove(addr);
    }

    m_monitors->replace(monList);
    m_toplevels->replace(tlList);
    m_workspaces->replace(wsList);
    const auto oldWs = m_wsById;
    const auto oldTl = m_tlByAddr;
    const auto oldMon = m_monByName;
    m_wsById = wsNext;
    m_tlByAddr = tlNext;
    m_monByName = monNext;
    if (focused != m_focused) {
        m_focused = focused;
        emit focusedMonitorChanged();
    }
    for (auto *o : oldWs)
        o->deleteLater();
    for (auto *o : oldTl)
        o->deleteLater();
    for (auto *o : oldMon)
        o->deleteLater();
}

}
