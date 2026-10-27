#include "greetd.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include <cstring>

namespace stack {

namespace {

constexpr quint32 MaxReply = 1 << 20;

QString socketPath()
{
    return qEnvironmentVariable("GREETD_SOCK");
}

void wipe(QByteArray &bytes)
{
    if (!bytes.isEmpty())
        explicit_bzero(bytes.data(), static_cast<size_t>(bytes.size()));
    bytes.clear();
}

}

Greetd *Greetd::create(QQmlEngine *, QJSEngine *)
{
    auto *g = new Greetd;
    QJSEngine::setObjectOwnership(g, QJSEngine::CppOwnership);
    return g;
}

Greetd::Greetd()
{
    connect(&m_socket, &QLocalSocket::readyRead, this, &Greetd::readAll);
    connect(&m_socket, &QLocalSocket::disconnected, this, [this] {
        m_buffer.clear();
        const bool busy = !m_pending.isEmpty() || (m_state != GreetdState::Inactive && m_state != GreetdState::Launched);
        m_pending.clear();
        if (busy && m_state != GreetdState::Launched) {
            setState(GreetdState::Inactive);
            emit error(QStringLiteral("Lost the connection to greetd"));
        }
    });
}

bool Greetd::available() const
{
    const QString path = socketPath();
    return !path.isEmpty() && QFileInfo(path).exists();
}

bool Greetd::ensure()
{
    if (m_socket.state() == QLocalSocket::ConnectedState)
        return true;
    if (!available()) {
        fail(QStringLiteral("greetd is not running"));
        return false;
    }
    m_socket.connectToServer(socketPath());
    if (!m_socket.waitForConnected(2000)) {
        fail(QStringLiteral("Could not connect to greetd"));
        return false;
    }
    return true;
}

void Greetd::send(const QJsonObject &request, Pending kind)
{
    if (!ensure())
        return;
    QByteArray body = QJsonDocument(request).toJson(QJsonDocument::Compact);
    const quint32 length = static_cast<quint32>(body.size());
    QByteArray frame(reinterpret_cast<const char *>(&length), sizeof length);
    frame.append(body);
    wipe(body);
    m_pending.enqueue(kind);
    m_socket.write(frame);
    m_socket.flush();
    wipe(frame);
}

void Greetd::fail(const QString &message)
{
    setState(GreetdState::Inactive);
    emit error(message);
}

void Greetd::setState(int state)
{
    if (state == m_state)
        return;
    m_state = state;
    if (state == GreetdState::Inactive)
        m_user.clear();
    emit stateChanged();
}

void Greetd::createSession(const QString &user)
{
    if (m_state != GreetdState::Inactive) {
        emit error(QStringLiteral("A session is already being set up"));
        return;
    }
    if (user.isEmpty()) {
        emit error(QStringLiteral("No user was chosen"));
        return;
    }
    m_user = user;
    setState(GreetdState::Authenticating);
    send({{QStringLiteral("type"), QStringLiteral("create_session")}, {QStringLiteral("username"), user}}, Create);
}

void Greetd::respond(const QString &response)
{
    if (m_state != GreetdState::Authenticating)
        return;
    QJsonObject request{{QStringLiteral("type"), QStringLiteral("post_auth_message_response")}};
    if (!response.isEmpty())
        request.insert(QStringLiteral("response"), response);
    send(request, Respond);
}

void Greetd::cancelSession()
{
    if (m_state == GreetdState::Inactive || m_state == GreetdState::Launched)
        return;
    send({{QStringLiteral("type"), QStringLiteral("cancel_session")}}, Cancel);
    setState(GreetdState::Inactive);
}

void Greetd::launch(const QStringList &command, const QStringList &environment, bool quit)
{
    if (m_state != GreetdState::ReadyToLaunch) {
        emit error(QStringLiteral("The session is not ready to launch"));
        return;
    }
    if (command.isEmpty()) {
        emit error(QStringLiteral("No session command"));
        return;
    }
    m_quit = quit;
    setState(GreetdState::Launching);
    send({{QStringLiteral("type"), QStringLiteral("start_session")}, {QStringLiteral("cmd"), QJsonArray::fromStringList(command)}, {QStringLiteral("env"), QJsonArray::fromStringList(environment)}}, Start);
}

void Greetd::readAll()
{
    m_buffer.append(m_socket.readAll());
    while (m_buffer.size() >= 4) {
        quint32 length = 0;
        std::memcpy(&length, m_buffer.constData(), sizeof length);
        if (length > MaxReply) {
            m_socket.abort();
            m_buffer.clear();
            fail(QStringLiteral("greetd sent an oversized reply"));
            return;
        }
        if (static_cast<quint32>(m_buffer.size()) < 4 + length)
            return;
        const QJsonDocument doc = QJsonDocument::fromJson(m_buffer.mid(4, static_cast<qsizetype>(length)));
        m_buffer.remove(0, 4 + static_cast<qsizetype>(length));
        handle(doc.object());
    }
}

void Greetd::handle(const QJsonObject &reply)
{
    const Pending kind = m_pending.isEmpty() ? Quiet : m_pending.dequeue();
    if (kind == Cancel || kind == Quiet)
        return;
    const QString type = reply.value(QStringLiteral("type")).toString();
    if (type == QStringLiteral("auth_message")) {
        const QString style = reply.value(QStringLiteral("auth_message_type")).toString();
        const bool required = style == QStringLiteral("visible") || style == QStringLiteral("secret");
        emit authMessage(reply.value(QStringLiteral("auth_message")).toString(), style == QStringLiteral("error"), required, style == QStringLiteral("visible"));
        return;
    }
    if (type == QStringLiteral("success")) {
        if (kind == Start) {
            setState(GreetdState::Launched);
            emit launched();
            if (m_quit)
                QTimer::singleShot(0, qApp, [] { QCoreApplication::exit(0); });
            return;
        }
        setState(GreetdState::ReadyToLaunch);
        emit readyToLaunch();
        return;
    }
    const QString description = reply.value(QStringLiteral("description")).toString();
    const bool auth = reply.value(QStringLiteral("error_type")).toString() == QStringLiteral("auth_error");
    send({{QStringLiteral("type"), QStringLiteral("cancel_session")}}, Quiet);
    setState(GreetdState::Inactive);
    if (auth)
        emit authFailure(description);
    else
        emit error(description.isEmpty() ? QStringLiteral("greetd reported an error") : description);
}

}
