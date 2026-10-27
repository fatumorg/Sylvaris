#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlParserStatus>

#include <polkitqt1-agent-listener.h>
#include <polkitqt1-agent-session.h>
#include <polkitqt1-identity.h>

namespace stack {

class AuthIdentity : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("identities come from AuthFlow")
    Q_PROPERTY(QString name MEMBER m_name CONSTANT)
    Q_PROPERTY(QString displayName MEMBER m_displayName CONSTANT)
    Q_PROPERTY(int uid MEMBER m_uid CONSTANT)

public:
    AuthIdentity(const PolkitQt1::Identity &identity, QObject *parent);
    PolkitQt1::Identity identity() const { return m_identity; }
    int uid() const { return m_uid; }

private:
    PolkitQt1::Identity m_identity;
    QString m_name;
    QString m_displayName;
    int m_uid = -1;
};

class AuthFlow : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("flows come from PolkitAgent")
    Q_PROPERTY(QString message MEMBER m_message CONSTANT)
    Q_PROPERTY(QString iconName MEMBER m_iconName CONSTANT)
    Q_PROPERTY(QString actionId MEMBER m_actionId CONSTANT)
    Q_PROPERTY(stack::AuthIdentity *selectedIdentity READ selectedIdentity CONSTANT)
    Q_PROPERTY(bool isResponseRequired MEMBER m_responseRequired NOTIFY isResponseRequiredChanged)
    Q_PROPERTY(QString inputPrompt MEMBER m_prompt NOTIFY changed)
    Q_PROPERTY(bool responseVisible MEMBER m_echo NOTIFY changed)
    Q_PROPERTY(QString supplementaryMessage MEMBER m_supplementary NOTIFY changed)
    Q_PROPERTY(bool supplementaryIsError MEMBER m_supplementaryError NOTIFY changed)
    Q_PROPERTY(bool isCompleted MEMBER m_completed NOTIFY isCompletedChanged)
    Q_PROPERTY(bool isSuccessful MEMBER m_success NOTIFY isCompletedChanged)
    Q_PROPERTY(bool isCancelled MEMBER m_cancelled NOTIFY isCompletedChanged)

public:
    AuthFlow(const QString &actionId, const QString &message, const QString &iconName, const QString &cookie, const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *result, QObject *parent);
    ~AuthFlow() override;

    AuthIdentity *selectedIdentity() const { return m_identity; }
    bool completed() const { return m_completed; }
    void start();
    void abort();

    Q_INVOKABLE void submit(const QString &response);
    Q_INVOKABLE void cancelAuthenticationRequest();

signals:
    void changed();
    void isResponseRequiredChanged();
    void isCompletedChanged();
    void authenticationFailed();

private:
    void finish(bool success, bool cancelled);
    void dropSession();

    QString m_actionId;
    QString m_message;
    QString m_iconName;
    QString m_cookie;
    AuthIdentity *m_identity = nullptr;
    PolkitQt1::Agent::AsyncResult *m_result;
    QPointer<PolkitQt1::Agent::Session> m_session;
    bool m_responseRequired = false;
    QString m_prompt;
    bool m_echo = false;
    QString m_supplementary;
    bool m_supplementaryError = false;
    bool m_completed = false;
    bool m_success = false;
    bool m_cancelled = false;
    bool m_failedOnce = false;
};

class PolkitAgent;

class AgentListener : public PolkitQt1::Agent::Listener
{
    Q_OBJECT

public:
    explicit AgentListener(PolkitAgent *agent);

public slots:
    void initiateAuthentication(const QString &actionId, const QString &message, const QString &iconName, const PolkitQt1::Details &details, const QString &cookie, const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *result) override;
    bool initiateAuthenticationFinish() override;
    void cancelAuthentication() override;

private:
    PolkitAgent *m_agent;
};

class PolkitAgent : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString path MEMBER m_path NOTIFY pathChanged)
    Q_PROPERTY(bool isRegistered MEMBER m_registered NOTIFY isRegisteredChanged)
    Q_PROPERTY(stack::AuthFlow *flow READ flow NOTIFY flowChanged)
    Q_PROPERTY(bool isActive READ isActive NOTIFY flowChanged)

public:
    explicit PolkitAgent(QObject *parent = nullptr);
    ~PolkitAgent() override;

    AuthFlow *flow() const { return m_flow; }
    bool isActive() const { return m_flow && !m_flow->completed(); }
    void begin(AuthFlow *flow);
    void cancel();

    void classBegin() override {}
    void componentComplete() override;

signals:
    void pathChanged();
    void isRegisteredChanged();
    void flowChanged();

private:
    QString m_path = QStringLiteral("/org/sylvaris/PolkitAgent");
    bool m_registered = false;
    AgentListener *m_listener = nullptr;
    QPointer<AuthFlow> m_flow;
};

}
