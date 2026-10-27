#pragma once

#include <QLocalSocket>
#include <QObject>
#include <QQmlEngine>
#include <QQueue>

namespace stack {

namespace GreetdState {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Inactive = 0, Authenticating = 1, ReadyToLaunch = 2, Launching = 3, Launched = 4 };
Q_ENUM_NS(Enum)
}

class Greetd : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(int state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString user MEMBER m_user NOTIFY stateChanged)

public:
    static Greetd *create(QQmlEngine *, QJSEngine *);
    bool available() const;
    int state() const { return m_state; }

    Q_INVOKABLE void createSession(const QString &user);
    Q_INVOKABLE void respond(const QString &response);
    Q_INVOKABLE void cancelSession();
    Q_INVOKABLE void launch(const QStringList &command, const QStringList &environment = {}, bool quit = true);

signals:
    void stateChanged();
    void authMessage(const QString &message, bool error, bool responseRequired, bool echoResponse);
    void authFailure(const QString &message);
    void readyToLaunch();
    void launched();
    void error(const QString &error);

private:
    enum Pending { Create, Respond, Cancel, Start, Quiet };

    Greetd();
    bool ensure();
    void send(const QJsonObject &request, Pending kind);
    void readAll();
    void handle(const QJsonObject &reply);
    void setState(int state);
    void fail(const QString &message);

    QLocalSocket m_socket;
    QByteArray m_buffer;
    QQueue<Pending> m_pending;
    int m_state = GreetdState::Inactive;
    QString m_user;
    bool m_quit = false;
};

}
