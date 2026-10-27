#include "toplevel.h"

#include <QGuiApplication>
#include <QPointer>

namespace stack {

namespace {

class TopManager : public QWaylandClientExtensionTemplate<TopManager>, public QtWayland::zwlr_foreign_toplevel_manager_v1
{
public:
    TopManager()
        : QWaylandClientExtensionTemplate<TopManager>(3)
    {
        initialize();
    }

protected:
    void zwlr_foreign_toplevel_manager_v1_toplevel(struct ::zwlr_foreign_toplevel_handle_v1 *handle) override
    {
        ToplevelManager::instance()->added(new Toplevel(handle, ToplevelManager::instance()));
    }
};

class MapManager : public QWaylandClientExtensionTemplate<MapManager>, public QtWayland::hyprland_toplevel_mapping_manager_v1
{
public:
    MapManager()
        : QWaylandClientExtensionTemplate<MapManager>(1)
    {
        initialize();
    }
};

class MapHandle : public QtWayland::hyprland_toplevel_window_mapping_handle_v1
{
public:
    MapHandle(struct ::hyprland_toplevel_window_mapping_handle_v1 *h, Toplevel *t)
        : QtWayland::hyprland_toplevel_window_mapping_handle_v1(h)
        , m_toplevel(t)
    {
    }
    ~MapHandle() override { destroy(); }

protected:
    void hyprland_toplevel_window_mapping_handle_v1_window_address(uint32_t hi, uint32_t lo) override
    {
        const quint64 addr = (static_cast<quint64>(hi) << 32) | lo;
        if (m_toplevel)
            m_toplevel->setAddress(QStringLiteral("0x") + QString::number(addr, 16));
        delete this;
    }
    void hyprland_toplevel_window_mapping_handle_v1_failed() override { delete this; }

private:
    QPointer<Toplevel> m_toplevel;
};

TopManager *topManager()
{
    static TopManager *m = QGuiApplication::platformName() == QStringLiteral("wayland") ? new TopManager() : nullptr;
    return m;
}

MapManager *mapManager()
{
    static MapManager *m = QGuiApplication::platformName() == QStringLiteral("wayland") && qEnvironmentVariableIsSet("HYPRLAND_INSTANCE_SIGNATURE") ? new MapManager() : nullptr;
    return m;
}

}

Toplevel::Toplevel(struct ::zwlr_foreign_toplevel_handle_v1 *handle, QObject *parent)
    : QObject(parent)
    , QtWayland::zwlr_foreign_toplevel_handle_v1(handle)
{
}

Toplevel::~Toplevel()
{
    if (isInitialized())
        destroy();
}

void Toplevel::setMinimized(bool minimized)
{
    if (minimized)
        set_minimized();
    else
        unset_minimized();
}

void Toplevel::setMaximized(bool maximized)
{
    if (maximized)
        set_maximized();
    else
        unset_maximized();
}

void Toplevel::setFullscreen(bool fullscreen)
{
    if (fullscreen)
        set_fullscreen(nullptr);
    else
        unset_fullscreen();
}

void Toplevel::setAddress(const QString &address)
{
    if (address == m_address)
        return;
    m_address = address;
    emit addressChanged();
}

void Toplevel::activate()
{
    auto *app = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (app && app->seat())
        QtWayland::zwlr_foreign_toplevel_handle_v1::activate(app->seat());
}

void Toplevel::close()
{
    QtWayland::zwlr_foreign_toplevel_handle_v1::close();
}

void Toplevel::zwlr_foreign_toplevel_handle_v1_title(const QString &title)
{
    m_title = title;
}

void Toplevel::zwlr_foreign_toplevel_handle_v1_app_id(const QString &app_id)
{
    m_appId = app_id;
}

void Toplevel::zwlr_foreign_toplevel_handle_v1_state(wl_array *state)
{
    m_activated = m_minimized = m_maximized = m_fullscreen = false;
    const auto *v = static_cast<const uint32_t *>(state->data);
    for (size_t i = 0; i < state->size / sizeof(uint32_t); i++) {
        switch (v[i]) {
        case state_maximized:
            m_maximized = true;
            break;
        case state_minimized:
            m_minimized = true;
            break;
        case state_activated:
            m_activated = true;
            break;
        case state_fullscreen:
            m_fullscreen = true;
            break;
        }
    }
}

void Toplevel::zwlr_foreign_toplevel_handle_v1_done()
{
    if (!m_ready) {
        m_ready = true;
        emit readyChanged();
        if (auto *m = mapManager(); m && m->isActive())
            new MapHandle(m->get_window_for_toplevel_wlr(object()), this);
    }
    emit changed();
}

void Toplevel::zwlr_foreign_toplevel_handle_v1_closed()
{
    emit gone();
}

ToplevelManager::ToplevelManager()
    : m_model(new ObjectModel(this))
{
}

ToplevelManager *ToplevelManager::instance()
{
    static ToplevelManager *self = [] {
        auto *m = new ToplevelManager();
        topManager();
        mapManager();
        return m;
    }();
    return self;
}

ToplevelManager *ToplevelManager::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

void ToplevelManager::added(Toplevel *toplevel)
{
    m_all.append(toplevel);
    connect(toplevel, &Toplevel::readyChanged, this, [this, toplevel] { m_model->insert(toplevel); });
    connect(toplevel, &Toplevel::changed, this, &ToplevelManager::activeToplevelChanged);
    connect(toplevel, &Toplevel::addressChanged, this, &ToplevelManager::addressesChanged);
    connect(toplevel, &Toplevel::gone, this, [this, toplevel] {
        m_all.removeAll(toplevel);
        m_model->remove(toplevel);
        emit activeToplevelChanged();
        emit addressesChanged();
        toplevel->deleteLater();
    });
}

Toplevel *ToplevelManager::activeToplevel() const
{
    for (Toplevel *t : m_all) {
        if (t->ready() && t->activated())
            return t;
    }
    return nullptr;
}

Toplevel *ToplevelManager::byAddress(const QString &address) const
{
    if (address.isEmpty())
        return nullptr;
    for (Toplevel *t : m_all) {
        if (t->address() == address)
            return t;
    }
    return nullptr;
}

}
