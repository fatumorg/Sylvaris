#include "polkit.h"

#include <QTimer>

#include <polkitqt1-subject.h>

#include <pwd.h>
#include <unistd.h>

namespace stack {

AuthIdentity::AuthIdentity(const PolkitQt1::Identity &identity, QObject *parent)
    : QObject(parent)
    , m_identity(identity)
{
    m_name = identity.toString();
    if (!m_name.startsWith(QStringLiteral("unix-user:")))
        return;
    m_name = m_name.mid(10);
    m_uid = static_cast<int>(PolkitQt1::Identity(identity).toUnixUserIdentity().uid());
    struct passwd pw;
    struct passwd *found = nullptr;
    char buf[4096];
    if (getpwuid_r(static_cast<uid_t>(m_uid), &pw, buf, sizeof buf, &found) == 0 && found) {
        m_name = QString::fromLocal8Bit(found->pw_name);
        m_displayName = QString::fromLocal8Bit(found->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
    }
    if (m_displayName.isEmpty())
        m_displayName = m_name;
}

AuthFlow::AuthFlow(const QString &actionId, const QString &message, const QString &iconName, const QString &cookie, const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *result, QObject *parent)
    : QObject(parent)
    , m_actionId(actionId)
    , m_message(message)
    , m_iconName(iconName)
    , m_cookie(cookie)
    , m_result(result)
{
    const uid_t me = getuid();
    PolkitQt1::Identity pick;
    for (const PolkitQt1::Identity &id : identities) {
        if (!id.isValid())
            continue;
        if (!pick.isValid())
            pick = id;
        if (id.toString().startsWith(QStringLiteral("unix-user:")) && PolkitQt1::Identity(id).toUnixUserIdentity().uid() == me) {
            pick = id;
            break;
        }
    }
    if (pick.isValid())
        m_identity = new AuthIdentity(pick, this);
}

AuthFlow::~AuthFlow()
{
    abort();
}

void AuthFlow::start()
{
    if (m_completed)
        return;
    if (!m_identity) {
        m_supplementary = QStringLiteral("No identity can authorize this action");
        m_supplementaryError = true;
        emit changed();
        finish(false, true);
        return;
    }
    dropSession();
    m_asked = false;
    auto *session = new PolkitQt1::Agent::Session(m_identity->identity(), m_cookie, nullptr, this);
    m_session = session;
    connect(session, &PolkitQt1::Agent::Session::request, this, [this](const QString &prompt, bool echo) {
        m_asked = true;
        m_prompt = prompt;
        m_echo = echo;
        emit changed();
        m_responseRequired = true;
        emit isResponseRequiredChanged();
    });
    connect(session, &PolkitQt1::Agent::Session::showError, this, [this](const QString &text) {
        m_supplementary = text;
        m_supplementaryError = true;
        emit changed();
    });
    connect(session, &PolkitQt1::Agent::Session::showInfo, this, [this](const QString &text) {
        m_supplementary = text;
        m_supplementaryError = false;
        emit changed();
    });
    connect(session, &PolkitQt1::Agent::Session::completed, this, [this, session](bool gained) {
        if (session != m_session)
            return;
        dropSession();
        if (m_completed)
            return;
        if (gained || !m_asked) {
            finish(gained, false);
            return;
        }
        m_responseRequired = false;
        emit isResponseRequiredChanged();
        if (!m_supplementaryError || m_supplementary.isEmpty()) {
            m_supplementary = QStringLiteral("That password did not work, try again");
            m_supplementaryError = true;
            emit changed();
        }
        emit authenticationFailed();
        QTimer::singleShot(0, this, &AuthFlow::start);
    });
    session->initiate();
}

void AuthFlow::submit(const QString &response)
{
    if (m_completed || !m_session || !m_responseRequired)
        return;
    m_responseRequired = false;
    emit isResponseRequiredChanged();
    m_supplementary.clear();
    m_supplementaryError = false;
    emit changed();
    m_session->setResponse(response);
}

void AuthFlow::cancelAuthenticationRequest()
{
    if (m_completed)
        return;
    finish(false, true);
}

void AuthFlow::abort()
{
    if (!m_completed)
        finish(false, true);
}

void AuthFlow::dropSession()
{
    if (!m_session)
        return;
    PolkitQt1::Agent::Session *session = m_session;
    m_session = nullptr;
    session->disconnect(this);
    session->cancel();
    session->deleteLater();
}

void AuthFlow::finish(bool success, bool cancelled)
{
    dropSession();
    m_completed = true;
    m_success = success;
    m_cancelled = cancelled;
    m_responseRequired = false;
    if (m_result) {
        if (!success)
            m_result->setError(cancelled ? QStringLiteral("Authentication was cancelled") : QStringLiteral("Authentication failed"));
        m_result->setCompleted();
        m_result = nullptr;
    }
    emit isResponseRequiredChanged();
    emit isCompletedChanged();
}

AgentListener::AgentListener(PolkitAgent *agent)
    : PolkitQt1::Agent::Listener(agent)
    , m_agent(agent)
{
}

void AgentListener::initiateAuthentication(const QString &actionId, const QString &message, const QString &iconName, const PolkitQt1::Details &, const QString &cookie, const PolkitQt1::Identity::List &identities, PolkitQt1::Agent::AsyncResult *result)
{
    if (m_agent->isActive()) {
        result->setError(QStringLiteral("Another authentication is in progress"));
        result->setCompleted();
        return;
    }
    m_agent->begin(new AuthFlow(actionId, message, iconName, cookie, identities, result, m_agent));
}

bool AgentListener::initiateAuthenticationFinish()
{
    return true;
}

void AgentListener::cancelAuthentication()
{
    m_agent->cancel();
}

PolkitAgent::PolkitAgent(QObject *parent)
    : QObject(parent)
{
}

PolkitAgent::~PolkitAgent()
{
    if (m_flow)
        m_flow->abort();
}

void PolkitAgent::componentComplete()
{
    m_listener = new AgentListener(this);
    m_registered = m_listener->registerListener(PolkitQt1::UnixSessionSubject(getpid()), m_path);
    if (!m_registered)
        qWarning("could not register the polkit agent, another one is probably running");
    emit isRegisteredChanged();
}

void PolkitAgent::begin(AuthFlow *flow)
{
    if (m_flow)
        m_flow->deleteLater();
    m_flow = flow;
    connect(flow, &AuthFlow::isCompletedChanged, this, [this, flow] {
        emit flowChanged();
        QTimer::singleShot(1000, flow, [this, flow] {
            if (m_flow == flow) {
                m_flow = nullptr;
                emit flowChanged();
            }
            flow->deleteLater();
        });
    });
    emit flowChanged();
    flow->start();
}

void PolkitAgent::cancel()
{
    if (m_flow)
        m_flow->abort();
}

}
