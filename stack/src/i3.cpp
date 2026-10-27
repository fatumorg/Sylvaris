#include "i3.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <cstring>

namespace stack {

namespace {

constexpr char Magic[] = "i3-ipc";
constexpr int MagicLen = 6;
constexpr quint32 RunCommand = 0;
constexpr quint32 GetWorkspaces = 1;
constexpr quint32 Subscribe = 2;

}

I3::I3()
    : m_workspaces(new ObjectModel(this))
{
    m_path = qEnvironmentVariable("SWAYSOCK");
    if (m_path.isEmpty())
        m_path = qEnvironmentVariable("I3SOCK");
    if (m_path.isEmpty())
        return;
    m_retry.setSingleShot(true);
    m_retry.setInterval(2000);
    connect(&m_retry, &QTimer::timeout, this, &I3::connectAll);
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(20);
    connect(&m_debounce, &QTimer::timeout, this, &I3::refresh);
    connect(&m_command, &QLocalSocket::readyRead, this, [this] { readFrom(m_command, m_commandBuffer, false); });
    connect(&m_events, &QLocalSocket::readyRead, this, [this] { readFrom(m_events, m_eventBuffer, true); });
    connect(&m_command, &QLocalSocket::connected, this, &I3::refresh);
    connect(&m_events, &QLocalSocket::connected, this, [this] { send(m_events, Subscribe, QByteArrayLiteral("[\"workspace\",\"output\"]")); });
    for (QLocalSocket *s : {&m_command, &m_events}) {
        connect(s, &QLocalSocket::disconnected, &m_retry, qOverload<>(&QTimer::start));
        connect(s, &QLocalSocket::errorOccurred, this, [this, s](QLocalSocket::LocalSocketError) {
            if (s->state() != QLocalSocket::ConnectedState)
                m_retry.start();
        });
    }
    connectAll();
}

I3 *I3::create(QQmlEngine *, QJSEngine *)
{
    static I3 *self = new I3();
    QJSEngine::setObjectOwnership(self, QJSEngine::CppOwnership);
    return self;
}

void I3::connectAll()
{
    if (m_command.state() == QLocalSocket::UnconnectedState) {
        m_commandBuffer.clear();
        m_command.connectToServer(m_path);
    }
    if (m_events.state() == QLocalSocket::UnconnectedState) {
        m_eventBuffer.clear();
        m_events.connectToServer(m_path);
    }
}

void I3::send(QLocalSocket &socket, quint32 type, const QByteArray &payload)
{
    if (socket.state() != QLocalSocket::ConnectedState)
        return;
    QByteArray msg(Magic, MagicLen);
    const quint32 len = static_cast<quint32>(payload.size());
    msg.append(reinterpret_cast<const char *>(&len), 4);
    msg.append(reinterpret_cast<const char *>(&type), 4);
    msg.append(payload);
    socket.write(msg);
}

void I3::readFrom(QLocalSocket &socket, QByteArray &buffer, bool events)
{
    buffer += socket.readAll();
    while (buffer.size() >= MagicLen + 8) {
        if (std::memcmp(buffer.constData(), Magic, MagicLen) != 0) {
            buffer.clear();
            socket.abort();
            return;
        }
        quint32 len;
        quint32 type;
        std::memcpy(&len, buffer.constData() + MagicLen, 4);
        std::memcpy(&type, buffer.constData() + MagicLen + 4, 4);
        if (len > 64u * 1024u * 1024u) {
            buffer.clear();
            socket.abort();
            return;
        }
        if (buffer.size() < MagicLen + 8 + static_cast<qsizetype>(len))
            return;
        const QByteArray payload = buffer.mid(MagicLen + 8, len);
        buffer.remove(0, MagicLen + 8 + len);
        message(type, payload, events);
    }
}

void I3::message(quint32 type, const QByteArray &payload, bool events)
{
    if (events) {
        if (type & 0x80000000u)
            m_debounce.start();
        return;
    }
    if (type == GetWorkspaces) {
        apply(payload);
    } else if (type == RunCommand) {
        for (const QJsonValue &v : QJsonDocument::fromJson(payload).array()) {
            const QJsonObject o = v.toObject();
            if (!o.value(QStringLiteral("success")).toBool(true))
                qWarning("sylstack: sway command failed: %s", qPrintable(o.value(QStringLiteral("error")).toString()));
        }
    }
}

void I3::dispatch(const QString &command)
{
    send(m_command, RunCommand, command.toUtf8());
}

void I3::refresh()
{
    send(m_command, GetWorkspaces, {});
}

void I3::apply(const QByteArray &json)
{
    const QJsonArray list = QJsonDocument::fromJson(json).array();
    QHash<qint64, I3Workspace *> next;
    QHash<QString, I3Monitor *> monitors;
    QList<QObject *> ordered;
    I3Monitor *focused = nullptr;
    for (const QJsonValue &v : list) {
        const QJsonObject o = v.toObject();
        const qint64 id = static_cast<qint64>(o.value(QStringLiteral("id")).toDouble());
        I3Workspace *w = m_byId.take(id);
        if (!w) {
            w = new I3Workspace(this);
            w->id = id;
        }
        const QString output = o.value(QStringLiteral("output")).toString();
        I3Monitor *m = monitors.value(output);
        if (!m) {
            m = m_monitors.take(output);
            if (!m) {
                m = new I3Monitor(this);
                m->name = output;
            }
            monitors.insert(output, m);
        }
        const int number = o.value(QStringLiteral("num")).toInt();
        const QString name = o.value(QStringLiteral("name")).toString();
        const bool active = o.value(QStringLiteral("visible")).toBool();
        const bool isFocused = o.value(QStringLiteral("focused")).toBool();
        const bool urgent = o.value(QStringLiteral("urgent")).toBool();
        if (isFocused)
            focused = m;
        if (w->number != number || w->name != name || w->monitor != m || w->active != active || w->focused != isFocused || w->urgent != urgent) {
            w->number = number;
            w->name = name;
            w->monitor = m;
            w->active = active;
            w->focused = isFocused;
            w->urgent = urgent;
            emit w->changed();
        }
        next.insert(id, w);
        ordered << w;
    }
    m_workspaces->replace(ordered);
    const auto oldWs = m_byId;
    const auto oldMon = m_monitors;
    m_byId = next;
    m_monitors = monitors;
    if (focused && focused != m_focused) {
        m_focused = focused;
        emit focusedMonitorChanged();
    }
    for (auto *o : oldWs)
        o->deleteLater();
    for (auto *o : oldMon) {
        if (o != m_focused)
            o->deleteLater();
    }
}

}
