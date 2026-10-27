#pragma once

#include <QObject>
#include <QQmlEngine>

#include <memory>

namespace stack {

struct PamShared;

class PamResult : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Enum { Success = 0, Failed = 1, Error = 2, MaxTries = 3 };
    Q_ENUM(Enum)
    using QObject::QObject;
    Q_INVOKABLE static QString toString(int result);
};

class PamError : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Enum { StartFailed = 0, TryAuthFailed = 1, InternalError = 2 };
    Q_ENUM(Enum)
    using QObject::QObject;
    Q_INVOKABLE static QString toString(int error);
};

class PamContext : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString config MEMBER m_config NOTIFY configChanged)
    Q_PROPERTY(QString configDirectory MEMBER m_configDirectory NOTIFY configChanged)
    Q_PROPERTY(QString user MEMBER m_user NOTIFY configChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool responseRequired MEMBER m_responseRequired NOTIFY pamMessage)
    Q_PROPERTY(bool responseVisible MEMBER m_responseVisible NOTIFY pamMessage)
    Q_PROPERTY(QString message MEMBER m_message NOTIFY pamMessage)
    Q_PROPERTY(bool messageIsError MEMBER m_messageIsError NOTIFY pamMessage)

public:
    explicit PamContext(QObject *parent = nullptr);
    ~PamContext() override;

    bool active() const { return m_shared != nullptr; }
    void setActive(bool active);

    Q_INVOKABLE bool start();
    Q_INVOKABLE void abort();
    Q_INVOKABLE void respond(const QString &response);

    void deliver(const QString &text, bool error, bool required, bool echo);
    void conclude(int code, bool started);

signals:
    void configChanged();
    void activeChanged();
    void pamMessage();
    void completed(int result);
    void error(int error);

private:
    QString m_config = QStringLiteral("login");
    QString m_configDirectory = QStringLiteral("/etc/pam.d");
    QString m_user;
    bool m_responseRequired = false;
    bool m_responseVisible = false;
    QString m_message;
    bool m_messageIsError = false;
    std::shared_ptr<PamShared> m_shared;
};

}
