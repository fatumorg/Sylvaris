#include "pam.h"

#include <QCoreApplication>
#include <QFileInfo>

#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <thread>

#include <security/pam_appl.h>

namespace stack {

struct PamShared
{
    std::mutex mutex;
    std::condition_variable wake;
    bool aborted = false;
    bool answered = false;
    QByteArray answer;
    PamContext *owner = nullptr;
};

namespace {

void wipe(QByteArray &bytes)
{
    if (!bytes.isEmpty())
        explicit_bzero(bytes.data(), static_cast<size_t>(bytes.size()));
    bytes.clear();
}

void post(const std::shared_ptr<PamShared> &shared, std::function<void(PamContext *)> fn)
{
    QMetaObject::invokeMethod(QCoreApplication::instance(), [shared, fn] {
        PamContext *owner = nullptr;
        {
            std::lock_guard lock(shared->mutex);
            if (!shared->aborted)
                owner = shared->owner;
        }
        if (owner)
            fn(owner);
    }, Qt::QueuedConnection);
}

void freeResponses(pam_response *responses, int count)
{
    for (int i = 0; i < count; i++) {
        if (responses[i].resp) {
            explicit_bzero(responses[i].resp, std::strlen(responses[i].resp));
            std::free(responses[i].resp);
        }
    }
    std::free(responses);
}

struct ConvData
{
    std::shared_ptr<PamShared> shared;
};

int converse(int count, const struct pam_message **messages, struct pam_response **out, void *data)
{
    if (count <= 0 || count > PAM_MAX_NUM_MSG)
        return PAM_CONV_ERR;
    const std::shared_ptr<PamShared> shared = static_cast<ConvData *>(data)->shared;
    auto *responses = static_cast<pam_response *>(std::calloc(static_cast<size_t>(count), sizeof(pam_response)));
    if (!responses)
        return PAM_BUF_ERR;
    for (int i = 0; i < count; i++) {
        const int style = messages[i]->msg_style;
        const QString text = QString::fromUtf8(messages[i]->msg ? messages[i]->msg : "");
        if (style == PAM_PROMPT_ECHO_OFF || style == PAM_PROMPT_ECHO_ON) {
            const bool echo = style == PAM_PROMPT_ECHO_ON;
            post(shared, [text, echo](PamContext *c) { c->deliver(text, false, true, echo); });
            std::unique_lock lock(shared->mutex);
            shared->wake.wait(lock, [&] { return shared->aborted || shared->answered; });
            if (shared->aborted) {
                wipe(shared->answer);
                lock.unlock();
                freeResponses(responses, count);
                return PAM_CONV_ERR;
            }
            responses[i].resp = strndup(shared->answer.constData(), static_cast<size_t>(shared->answer.size()));
            shared->answered = false;
            wipe(shared->answer);
            if (!responses[i].resp) {
                lock.unlock();
                freeResponses(responses, count);
                return PAM_BUF_ERR;
            }
        } else if (style == PAM_ERROR_MSG || style == PAM_TEXT_INFO) {
            const bool error = style == PAM_ERROR_MSG;
            post(shared, [text, error](PamContext *c) { c->deliver(text, error, false, false); });
        } else {
            freeResponses(responses, count);
            return PAM_CONV_ERR;
        }
    }
    *out = responses;
    return PAM_SUCCESS;
}

void authenticate(std::shared_ptr<PamShared> shared, QByteArray service, QByteArray user, QByteArray dir)
{
    ConvData data{shared};
    const struct pam_conv conv = {converse, &data};
    pam_handle_t *handle = nullptr;
    int code = pam_start_confdir(service.constData(), user.isEmpty() ? nullptr : user.constData(), &conv, dir.constData(), &handle);
    if (code != PAM_SUCCESS) {
        post(shared, [code](PamContext *c) { c->conclude(code, false); });
        return;
    }
    code = pam_authenticate(handle, 0);
    pam_end(handle, code);
    post(shared, [code](PamContext *c) { c->conclude(code, true); });
}

}

QString PamResult::toString(int result)
{
    switch (result) {
    case Success:
        return QStringLiteral("Success");
    case Failed:
        return QStringLiteral("Failed");
    case MaxTries:
        return QStringLiteral("MaxTries");
    default:
        return QStringLiteral("Error");
    }
}

QString PamError::toString(int error)
{
    switch (error) {
    case StartFailed:
        return QStringLiteral("PAM could not start");
    case TryAuthFailed:
        return QStringLiteral("PAM stopped asking");
    default:
        return QStringLiteral("the PAM service is broken, check its modules");
    }
}

PamContext::PamContext(QObject *parent)
    : QObject(parent)
{
}

PamContext::~PamContext()
{
    abort();
}

void PamContext::setActive(bool active)
{
    if (active)
        start();
    else
        abort();
}

bool PamContext::start()
{
    if (m_shared)
        return false;
    if (m_config.isEmpty() || m_config.contains(QLatin1Char('/')) || m_config.startsWith(QLatin1Char('.'))) {
        qWarning("invalid PAM service name");
        return false;
    }
    if (!QFileInfo(m_configDirectory + QLatin1Char('/') + m_config).isFile()) {
        qWarning("PAM service %s not found in %s", qPrintable(m_config), qPrintable(m_configDirectory));
        return false;
    }
    m_shared = std::make_shared<PamShared>();
    m_shared->owner = this;
    m_responseRequired = false;
    m_message.clear();
    m_messageIsError = false;
    try {
        std::thread(authenticate, m_shared, m_config.toUtf8(), m_user.toUtf8(), m_configDirectory.toUtf8()).detach();
    } catch (...) {
        m_shared.reset();
        return false;
    }
    emit activeChanged();
    return true;
}

void PamContext::abort()
{
    if (!m_shared)
        return;
    {
        std::lock_guard lock(m_shared->mutex);
        m_shared->aborted = true;
        m_shared->owner = nullptr;
        wipe(m_shared->answer);
    }
    m_shared->wake.notify_all();
    m_shared.reset();
    m_responseRequired = false;
    emit activeChanged();
}

void PamContext::respond(const QString &response)
{
    if (!m_shared || !m_responseRequired)
        return;
    m_responseRequired = false;
    {
        std::lock_guard lock(m_shared->mutex);
        wipe(m_shared->answer);
        m_shared->answer = response.toUtf8();
        m_shared->answered = true;
    }
    m_shared->wake.notify_all();
}

void PamContext::deliver(const QString &text, bool error, bool required, bool echo)
{
    m_message = text;
    m_messageIsError = error;
    m_responseRequired = required;
    m_responseVisible = echo;
    emit pamMessage();
}

void PamContext::conclude(int code, bool started)
{
    {
        std::lock_guard lock(m_shared->mutex);
        m_shared->owner = nullptr;
    }
    m_shared.reset();
    m_responseRequired = false;
    emit activeChanged();
    if (!started) {
        emit error(PamError::StartFailed);
        return;
    }
    switch (code) {
    case PAM_SUCCESS:
        emit completed(PamResult::Success);
        break;
    case PAM_MAXTRIES:
        emit completed(PamResult::MaxTries);
        break;
    case PAM_AUTH_ERR:
    case PAM_USER_UNKNOWN:
    case PAM_CRED_INSUFFICIENT:
    case PAM_PERM_DENIED:
        emit completed(PamResult::Failed);
        break;
    case PAM_CONV_ERR:
        emit error(PamError::TryAuthFailed);
        break;
    case PAM_ABORT:
    case PAM_MODULE_UNKNOWN:
    case PAM_OPEN_ERR:
    case PAM_SYMBOL_ERR:
    case PAM_SERVICE_ERR:
    case PAM_BUF_ERR:
        emit error(PamError::InternalError);
        break;
    default:
        emit completed(PamResult::Error);
        break;
    }
}

}
