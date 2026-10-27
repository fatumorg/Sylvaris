#include "lock.h"

#include "scope.h"

#include <QGuiApplication>
#include <QScreen>
#include <wayland-client-core.h>
#include <QtWaylandClient/private/qwaylandscreen_p.h>
#include <QtWaylandClient/private/qwaylandshellintegration_p.h>
#include <QtWaylandClient/private/qwaylandshellsurface_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

#include "qwayland-ext-session-lock-v1.h"

namespace stack {

namespace {

class SessionLock : public QObject, public QtWayland::ext_session_lock_v1
{
    Q_OBJECT

public:
    explicit SessionLock(struct ::ext_session_lock_v1 *object)
        : QtWayland::ext_session_lock_v1(object)
    {
    }
    bool secure = false;
    bool dead = false;

    void release()
    {
        if (!object())
            return;
        if (secure && !dead)
            unlock_and_destroy();
        else
            destroy();
    }

signals:
    void stateChanged();

protected:
    void ext_session_lock_v1_locked() override
    {
        secure = true;
        emit stateChanged();
    }
    void ext_session_lock_v1_finished() override
    {
        secure = false;
        dead = true;
        emit stateChanged();
    }
};

SessionLock *s_lock = nullptr;

class LockSurface : public QtWaylandClient::QWaylandShellSurface, public QtWayland::ext_session_lock_surface_v1
{
public:
    LockSurface(QtWaylandClient::QWaylandWindow *window, SessionLock *lock)
        : QtWaylandClient::QWaylandShellSurface(window)
    {
        QtWaylandClient::QWaylandScreen *screen = window->waylandScreen();
        if (!screen || !screen->output()) {
            qWarning("lock surface has no output");
            return;
        }
        init(lock->get_lock_surface(wlSurface(), screen->output()));
    }
    ~LockSurface() override
    {
        if (object())
            destroy();
    }
    bool isExposed() const override { return m_configured; }
    bool commitSurfaceRole() const override { return false; }
    void applyConfigure() override { resizeFromApplyConfigure(m_size); }

protected:
    void ext_session_lock_surface_v1_configure(uint32_t serial, uint32_t width, uint32_t height) override
    {
        ack_configure(serial);
        m_size = QSize(static_cast<int>(width), static_cast<int>(height));
        if (!m_configured) {
            m_configured = true;
            resizeFromApplyConfigure(m_size);
            window()->updateExposure();
        } else {
            applyConfigureWhenPossible();
        }
    }

private:
    QSize m_size;
    bool m_configured = false;
};

class LockIntegration : public QtWaylandClient::QWaylandShellIntegrationTemplate<LockIntegration>, public QtWayland::ext_session_lock_manager_v1
{
public:
    LockIntegration()
        : QtWaylandClient::QWaylandShellIntegrationTemplate<LockIntegration>(1)
    {
    }
    QtWaylandClient::QWaylandShellSurface *createShellSurface(QtWaylandClient::QWaylandWindow *window) override
    {
        if (!s_lock || !s_lock->object() || s_lock->dead)
            return nullptr;
        return new LockSurface(window, s_lock);
    }
};

LockIntegration *integration()
{
    static LockIntegration *made = nullptr;
    static bool tried = false;
    if (!tried) {
        tried = true;
        made = new LockIntegration();
        if (!qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>() || !made->initialize(nullptr)) {
            delete made;
            made = nullptr;
        }
    }
    return made;
}

}

WlSessionLockSurface::WlSessionLockSurface(QObject *parent)
    : WindowBase(parent)
{
    setColor(Qt::black);
}

void WlSessionLockSurface::configure()
{
    applySize();
    m_window->create();
    auto *w = dynamic_cast<QtWaylandClient::QWaylandWindow *>(m_window->handle());
    LockIntegration *shell = integration();
    if (w && shell)
        w->setShellIntegration(shell);
}

void WlSessionLockSurface::applySize()
{
    if (QScreen *s = m_window->screen())
        m_window->setGeometry(s->geometry());
}

WlSessionLock::WlSessionLock(QObject *parent)
    : QObject(parent)
{
    connect(Stack::instance(), &Stack::screensChanged, this, &WlSessionLock::syncSurfaces);
}

WlSessionLock::~WlSessionLock()
{
    if (s_lock)
        disconnect(s_lock, nullptr, this, nullptr);
    for (const QPointer<QObject> &s : std::as_const(m_surfaces))
        delete s.data();
}

bool WlSessionLock::secure() const
{
    return m_locked && s_lock && s_lock->secure;
}

void WlSessionLock::setLocked(bool locked)
{
    if (locked == m_locked)
        return;
    m_locked = locked;
    emit lockedChanged();
    apply();
}

void WlSessionLock::setSurface(QQmlComponent *surface)
{
    if (surface == m_surface)
        return;
    m_surface = surface;
    emit surfaceChanged();
    dropSurfaces();
    syncSurfaces();
}

void WlSessionLock::componentComplete()
{
    m_complete = true;
    apply();
}

void WlSessionLock::apply()
{
    if (!m_complete)
        return;
    if (m_locked) {
        if (s_lock && s_lock->dead) {
            disconnect(s_lock, nullptr, this, nullptr);
            s_lock->release();
            delete s_lock;
            s_lock = nullptr;
        }
        if (!s_lock) {
            LockIntegration *shell = integration();
            if (!shell) {
                qWarning("the compositor does not support ext-session-lock-v1");
                return;
            }
            s_lock = new SessionLock(shell->lock());
        }
        connect(s_lock, &SessionLock::stateChanged, this, &WlSessionLock::lockStateChanged, Qt::UniqueConnection);
        syncSurfaces();
        emit secureChanged();
        return;
    }
    dropSurfaces();
    if (s_lock) {
        disconnect(s_lock, nullptr, this, nullptr);
        s_lock->release();
        delete s_lock;
        s_lock = nullptr;
        if (auto *app = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>())
            wl_display_flush(app->display());
    }
    emit secureChanged();
}

void WlSessionLock::lockStateChanged()
{
    if (s_lock && s_lock->dead)
        dropSurfaces();
    emit secureChanged();
}

void WlSessionLock::syncSurfaces()
{
    if (!m_complete || !m_locked || !m_surface || !s_lock || s_lock->dead)
        return;
    QSet<QObject *> live;
    for (const QVariant &v : Stack::instance()->screens()) {
        auto *screen = qobject_cast<ShellScreen *>(v.value<QObject *>());
        if (!screen)
            continue;
        live.insert(screen);
        if (m_surfaces.value(screen))
            continue;
        QObject *made = createFrom(m_surface, this, {{QStringLiteral("screen"), QVariant::fromValue(screen)}});
        if (made && !qobject_cast<WlSessionLockSurface *>(made)) {
            qWarning("WlSessionLock.surface must be a WlSessionLockSurface");
            delete made;
            made = nullptr;
        }
        if (made)
            m_surfaces.insert(screen, made);
    }
    for (auto it = m_surfaces.begin(); it != m_surfaces.end();) {
        if (!live.contains(it.key()) || !it.value()) {
            if (it.value())
                it.value()->deleteLater();
            it = m_surfaces.erase(it);
        } else {
            ++it;
        }
    }
}

void WlSessionLock::dropSurfaces()
{
    const auto surfaces = m_surfaces;
    m_surfaces.clear();
    for (const QPointer<QObject> &s : surfaces) {
        if (s)
            s->deleteLater();
    }
}

}

#include "lock.moc"
