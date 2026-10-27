#include "window.h"

#include "stack.h"

#include <LayerShellQt/window.h>
#include <QGuiApplication>
#include <QQmlListReference>
#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

#include <cmath>

#include "qwayland-ext-background-effect-v1.h"

namespace stack {

namespace {

class BlurManager : public QWaylandClientExtensionTemplate<BlurManager>, public QtWayland::ext_background_effect_manager_v1
{
public:
    BlurManager()
        : QWaylandClientExtensionTemplate<BlurManager>(1)
    {
        initialize();
    }
    bool canBlur() const { return isActive() && m_blur; }

protected:
    void ext_background_effect_manager_v1_capabilities(uint32_t flags) override
    {
        m_blur = flags & capability_blur;
    }

private:
    bool m_blur = false;
};

BlurManager *blurManager()
{
    static BlurManager *manager = new BlurManager();
    return manager;
}

QRegion roundRect(const QRect &r, qreal radius, bool ellipse)
{
    if (r.isEmpty())
        return {};
    const qreal rx = ellipse ? r.width() / 2.0 : std::min<qreal>(radius, std::min(r.width(), r.height()) / 2.0);
    const qreal ry = ellipse ? r.height() / 2.0 : rx;
    if (rx < 1 || ry < 1)
        return QRegion(r);
    QRegion out;
    const int band = static_cast<int>(std::ceil(ry));
    for (int i = 0; i < band; i++) {
        const qreal dy = ry - i - 0.5;
        const qreal inset = rx - rx * std::sqrt(std::max<qreal>(0, 1 - (dy * dy) / (ry * ry)));
        const int x = static_cast<int>(std::round(inset));
        const int w = r.width() - 2 * x;
        if (w <= 0)
            continue;
        out += QRect(r.x() + x, r.y() + i, w, 1);
        out += QRect(r.x() + x, r.y() + r.height() - 1 - i, w, 1);
    }
    if (r.height() > 2 * band)
        out += QRect(r.x(), r.y() + band, r.width(), r.height() - 2 * band);
    return out;
}

}

void Region::setItem(QQuickItem *item)
{
    if (item == m_item)
        return;
    m_item = item;
    emit changed();
}

QQmlListProperty<Region> Region::regions()
{
    return {this, &m_children,
            [](QQmlListProperty<Region> *l, Region *r) {
                auto *self = static_cast<Region *>(l->object);
                if (!r)
                    return;
                self->m_children.append(r);
                connect(r, &Region::changed, self, &Region::changed);
                emit self->changed();
            },
            [](QQmlListProperty<Region> *l) { return static_cast<Region *>(l->object)->m_children.size(); },
            [](QQmlListProperty<Region> *l, qsizetype i) { return static_cast<Region *>(l->object)->m_children.value(i); },
            [](QQmlListProperty<Region> *l) {
                auto *self = static_cast<Region *>(l->object);
                for (Region *r : self->m_children)
                    disconnect(r, nullptr, self, nullptr);
                self->m_children.clear();
                emit self->changed();
            }};
}

QRegion Region::own() const
{
    QRectF rect(m_x, m_y, m_width, m_height);
    if (m_item) {
        if (!m_item->isVisible() || !m_item->window())
            return {};
        const QRectF scene = m_item->mapRectToScene(QRectF(0, 0, m_item->width(), m_item->height()));
        rect = QRectF(scene.x() + m_x, scene.y() + m_y, scene.width() + m_width, scene.height() + m_height);
    }
    if (rect.width() <= 0 || rect.height() <= 0)
        return {};
    return roundRect(rect.toAlignedRect(), m_radius, m_shape == RegionShape::Ellipse);
}

QRegion Region::build() const
{
    QRegion out = own();
    for (const Region *child : m_children) {
        const QRegion r = child->build();
        switch (child->m_intersection) {
        case Intersection::Combine:
            out = out.united(r);
            break;
        case Intersection::Subtract:
            out = out.subtracted(r);
            break;
        case Intersection::Intersect:
            out = out.intersected(r);
            break;
        case Intersection::Xor:
            out = out.xored(r);
            break;
        }
    }
    return out;
}

bool Region::dynamic() const
{
    if (m_item)
        return true;
    for (const Region *child : m_children) {
        if (child->dynamic())
            return true;
    }
    return false;
}

void BackgroundEffect::setBlurRegion(Region *region)
{
    if (region == m_region)
        return;
    m_region = region;
    emit changed();
}

WindowBase::WindowBase(QObject *parent)
    : QObject(parent)
    , m_content(new QQuickItem())
{
    QQmlEngine::setObjectOwnership(m_content, QQmlEngine::CppOwnership);
    m_content->setParent(this);
    m_window = makeWindow();
}

WindowBase::~WindowBase()
{
    m_shown = false;
    if (m_blurSurface) {
        ext_background_effect_surface_v1_destroy(m_blurSurface);
        m_blurSurface = nullptr;
    }
    disconnect(m_window, nullptr, this, nullptr);
    m_content->setParentItem(nullptr);
    delete m_window;
}

QQuickWindow *WindowBase::makeWindow()
{
    auto *w = new QQuickWindow();
    w->setColor(m_color);
    if (m_screen && m_screen->screen())
        w->setScreen(m_screen->screen());
    m_content->setParentItem(w->contentItem());
    m_content->setSize(w->size());
    connect(w, &QWindow::widthChanged, this, [this](int width) {
        m_content->setWidth(width);
        emit widthChanged();
    });
    connect(w, &QWindow::heightChanged, this, [this](int height) {
        m_content->setHeight(height);
        emit heightChanged();
    });
    connect(w, &QWindow::visibleChanged, this, [this] {
        if (!m_window->isVisible() && m_visible && m_shown) {
            m_visible = false;
            hideWindow();
            emit visibleChanged();
        }
    });
    connect(w, &QQuickWindow::closing, this, [this] { emit closed(); });
    connect(w, &QQuickWindow::afterAnimating, this, [this] {
        if ((m_mask && m_mask->dynamic()) || (m_effect && m_effect->blurRegion() && m_effect->blurRegion()->dynamic()))
            refreshRegions();
    });
    return w;
}

bool WindowBase::wayland() const
{
    return QGuiApplication::platformName() == QStringLiteral("wayland");
}

void WindowBase::setVisible(bool visible)
{
    if (visible == m_visible)
        return;
    m_visible = visible;
    emit visibleChanged();
    syncVisible();
}

void WindowBase::setImplicitWidth(int w)
{
    if (w == m_implicitWidth)
        return;
    m_implicitWidth = w;
    emit implicitWidthChanged();
    applySize();
}

void WindowBase::setImplicitHeight(int h)
{
    if (h == m_implicitHeight)
        return;
    m_implicitHeight = h;
    emit implicitHeightChanged();
    applySize();
}

void WindowBase::setColor(const QColor &color)
{
    if (color == m_color)
        return;
    m_color = color;
    m_window->setColor(color);
    emit colorChanged();
}

void WindowBase::setScreen(ShellScreen *screen)
{
    if (screen == m_screen)
        return;
    m_screen = screen;
    emit screenChanged();
    if (m_screen && m_screen->screen() && m_window->screen() != m_screen->screen()) {
        if (m_shown)
            recreate();
        else
            m_window->setScreen(m_screen->screen());
    }
}

void WindowBase::setMask(Region *mask)
{
    if (mask == m_mask)
        return;
    if (m_mask)
        disconnect(m_mask, nullptr, this, nullptr);
    m_mask = mask;
    if (m_mask)
        connect(m_mask, &Region::changed, this, &WindowBase::refreshRegions);
    emit maskChanged();
    refreshRegions();
}

QQmlListProperty<QObject> WindowBase::data()
{
    return {this, &m_data, &WindowBase::dataAppend, &WindowBase::dataCount, &WindowBase::dataAt, &WindowBase::dataClear};
}

void WindowBase::dataAppend(QQmlListProperty<QObject> *list, QObject *object)
{
    auto *self = static_cast<WindowBase *>(list->object);
    if (!object)
        return;
    self->m_data.append(object);
    QQmlListReference(self->m_content, "data").append(object);
}

qsizetype WindowBase::dataCount(QQmlListProperty<QObject> *list)
{
    return static_cast<WindowBase *>(list->object)->m_data.size();
}

QObject *WindowBase::dataAt(QQmlListProperty<QObject> *list, qsizetype index)
{
    return static_cast<WindowBase *>(list->object)->m_data.value(index);
}

void WindowBase::dataClear(QQmlListProperty<QObject> *list)
{
    static_cast<WindowBase *>(list->object)->m_data.clear();
}

void WindowBase::componentComplete()
{
    m_complete = true;
    attachEffect();
    if (m_screen && m_screen->screen())
        m_window->setScreen(m_screen->screen());
    applySize();
    Stack::instance()->whenReady(this, [this] { syncVisible(); });
}

void WindowBase::attachEffect()
{
    m_effect = qobject_cast<BackgroundEffect *>(qmlAttachedPropertiesObject<BackgroundEffect>(this, false));
    if (m_effect)
        connect(m_effect, &BackgroundEffect::changed, this, [this] {
            if (m_effect->blurRegion())
                connect(m_effect->blurRegion(), &Region::changed, this, &WindowBase::refreshRegions, Qt::UniqueConnection);
            refreshRegions();
        });
    if (m_effect && m_effect->blurRegion())
        connect(m_effect->blurRegion(), &Region::changed, this, &WindowBase::refreshRegions, Qt::UniqueConnection);
}

void WindowBase::applySize()
{
    m_window->resize(std::max(1, m_implicitWidth), std::max(1, m_implicitHeight));
}

void WindowBase::syncVisible()
{
    if (!m_complete || !Stack::instance()->isReady())
        return;
    if (m_visible && !m_shown) {
        configure();
        applySize();
        m_window->create();
        if (auto *w = dynamic_cast<QtWaylandClient::QWaylandWindow *>(m_window->handle())) {
            connect(w, &QtWaylandClient::QWaylandWindow::wlSurfaceCreated, this, &WindowBase::surfaceCreated, Qt::UniqueConnection);
            connect(w, &QtWaylandClient::QWaylandWindow::wlSurfaceDestroyed, this, &WindowBase::surfaceDestroyed, Qt::UniqueConnection);
        }
        m_shown = true;
        refreshRegions();
        m_window->setVisible(true);
    } else if (!m_visible && m_shown) {
        hideWindow();
    }
}

void WindowBase::hideWindow()
{
    m_shown = false;
    if (releaseOnHide())
        releaseWindow();
    else
        m_window->setVisible(false);
}

void WindowBase::releaseWindow()
{
    QQuickWindow *old = m_window;
    disconnect(old, nullptr, this, nullptr);
    old->setVisible(false);
    surfaceDestroyed();
    m_hasMask = false;
    m_lastMask = QRegion();
    m_window = makeWindow();
    old->deleteLater();
    Stack::instance()->trimSoon();
    applySize();
    emit windowChanged();
}

void WindowBase::recreate()
{
    const bool was = m_shown;
    m_shown = false;
    if (releaseOnHide()) {
        releaseWindow();
    } else {
        m_window->setVisible(false);
        surfaceDestroyed();
        m_window->destroy();
        if (m_screen && m_screen->screen())
            m_window->setScreen(m_screen->screen());
    }
    if (was)
        syncVisible();
}

void WindowBase::surfaceCreated()
{
    applyBlur(true);
}

void WindowBase::surfaceDestroyed()
{
    if (m_blurSurface) {
        ext_background_effect_surface_v1_destroy(m_blurSurface);
        m_blurSurface = nullptr;
    }
    m_hasBlur = false;
}

void WindowBase::refreshRegions()
{
    if (!m_complete)
        return;
    if (m_mask) {
        const QRegion next = m_mask->build();
        if (!m_hasMask || next != m_lastMask) {
            m_hasMask = true;
            m_lastMask = next;
            m_window->setMask(next.isEmpty() ? QRegion(-2, -2, 1, 1) : next);
        }
    } else if (m_hasMask) {
        m_hasMask = false;
        m_lastMask = QRegion();
        m_window->setMask(QRegion());
    }
    applyBlur(false);
}

void WindowBase::applyBlur(bool force)
{
    if (!wayland())
        return;
    Region *region = m_effect ? m_effect->blurRegion() : nullptr;
    auto *w = dynamic_cast<QtWaylandClient::QWaylandWindow *>(m_window->handle());
    if (!w || !w->wlSurface() || !blurManager()->canBlur())
        return;
    if (!region) {
        if (m_blurSurface && (m_hasBlur || force)) {
            ext_background_effect_surface_v1_set_blur_region(m_blurSurface, nullptr);
            m_hasBlur = false;
            m_lastBlur = QRegion();
            m_window->requestUpdate();
        }
        return;
    }
    const QRegion next = region->build();
    if (!force && m_hasBlur && next == m_lastBlur)
        return;
    if (!m_blurSurface)
        m_blurSurface = ext_background_effect_manager_v1_get_background_effect(blurManager()->object(), w->wlSurface());
    struct ::wl_region *wl = w->display()->createRegion(next);
    ext_background_effect_surface_v1_set_blur_region(m_blurSurface, wl);
    wl_region_destroy(wl);
    m_hasBlur = true;
    m_lastBlur = next;
    m_window->requestUpdate();
}

PanelWindow::PanelWindow(QObject *parent)
    : WindowBase(parent)
    , m_anchors(new PanelAnchors(this))
    , m_margins(new PanelMargins(this))
{
    if (wayland())
        LayerShellQt::Window::get(m_window);
    auto changed = [this] {
        configure();
        applySize();
        if (m_shown)
            m_window->requestUpdate();
    };
    connect(m_anchors, &PanelAnchors::changed, this, changed);
    connect(m_margins, &PanelMargins::changed, this, changed);
    connect(this, &WindowBase::implicitWidthChanged, this, [this] {
        if (m_mode == ExclusionMode::Auto)
            configure();
    });
    connect(this, &WindowBase::implicitHeightChanged, this, [this] {
        if (m_mode == ExclusionMode::Auto)
            configure();
    });
}

void PanelWindow::setExclusiveZone(int zone)
{
    if (zone == m_exclusiveZone)
        return;
    m_exclusiveZone = zone;
    emit exclusiveZoneChanged();
    configure();
}

void PanelWindow::setExclusionMode(ExclusionMode::Enum mode)
{
    if (mode == m_mode)
        return;
    m_mode = mode;
    emit exclusionModeChanged();
    configure();
}

void PanelWindow::componentComplete()
{
    m_layer = qobject_cast<WlrLayershell *>(qmlAttachedPropertiesObject<WlrLayershell>(this, true));
    connect(m_layer, &WlrLayershell::changed, this, &PanelWindow::layerChanged);
    WindowBase::componentComplete();
}

void PanelWindow::layerChanged()
{
    if (m_shown && m_layer && m_layer->m_namespace != m_appliedNamespace) {
        recreate();
        return;
    }
    configure();
    if (m_shown)
        m_window->requestUpdate();
}

void PanelWindow::applySize()
{
    const int w = m_anchors->left && m_anchors->right && m_shown ? m_window->width() : m_implicitWidth;
    const int h = m_anchors->top && m_anchors->bottom && m_shown ? m_window->height() : m_implicitHeight;
    m_window->resize(std::max(1, w), std::max(1, h));
}

void PanelWindow::configure()
{
    if (!m_complete || !wayland())
        return;
    auto *ls = LayerShellQt::Window::get(m_window);
    LayerShellQt::Window::Anchors anchors;
    if (m_anchors->top)
        anchors |= LayerShellQt::Window::AnchorTop;
    if (m_anchors->bottom)
        anchors |= LayerShellQt::Window::AnchorBottom;
    if (m_anchors->left)
        anchors |= LayerShellQt::Window::AnchorLeft;
    if (m_anchors->right)
        anchors |= LayerShellQt::Window::AnchorRight;
    ls->setAnchors(anchors);
    ls->setMargins(QMargins(m_margins->left, m_margins->top, m_margins->right, m_margins->bottom));

    LayerShellQt::Window::Anchor edge = LayerShellQt::Window::AnchorNone;
    const int count = m_anchors->top + m_anchors->bottom + m_anchors->left + m_anchors->right;
    if (count == 1 || count == 3) {
        if (m_anchors->top && (count == 1 || !m_anchors->bottom))
            edge = LayerShellQt::Window::AnchorTop;
        else if (m_anchors->bottom && (count == 1 || !m_anchors->top))
            edge = LayerShellQt::Window::AnchorBottom;
        else if (m_anchors->left && (count == 1 || !m_anchors->right))
            edge = LayerShellQt::Window::AnchorLeft;
        else if (m_anchors->right && (count == 1 || !m_anchors->left))
            edge = LayerShellQt::Window::AnchorRight;
    }
    int zone = 0;
    if (m_mode == ExclusionMode::Ignore) {
        zone = -1;
    } else if (m_mode == ExclusionMode::Normal) {
        zone = m_exclusiveZone;
    } else {
        switch (edge) {
        case LayerShellQt::Window::AnchorTop:
            zone = m_implicitHeight + m_margins->bottom;
            break;
        case LayerShellQt::Window::AnchorBottom:
            zone = m_implicitHeight + m_margins->top;
            break;
        case LayerShellQt::Window::AnchorLeft:
            zone = m_implicitWidth + m_margins->right;
            break;
        case LayerShellQt::Window::AnchorRight:
            zone = m_implicitWidth + m_margins->left;
            break;
        default:
            zone = 0;
        }
    }
    ls->setExclusiveZone(zone);
    if (edge != LayerShellQt::Window::AnchorNone)
        ls->setExclusiveEdge(edge);

    const WlrLayer::Enum layer = m_layer ? m_layer->m_layer : WlrLayer::Top;
    ls->setLayer(static_cast<LayerShellQt::Window::Layer>(layer));
    const WlrKeyboardFocus::Enum focus = m_layer ? m_layer->m_focus : WlrKeyboardFocus::None;
    ls->setKeyboardInteractivity(static_cast<LayerShellQt::Window::KeyboardInteractivity>(focus));
    if (!m_shown) {
        m_appliedNamespace = m_layer ? m_layer->m_namespace : QStringLiteral("sylstack");
        ls->setScope(m_appliedNamespace);
        ls->setActivateOnShow(false);
        ls->setWantsToBeOnActiveScreen(false);
        ls->setCloseOnDismissed(true);
        if (m_screen && m_screen->screen())
            ls->setScreen(m_screen->screen());
    }
}

FloatingWindow::FloatingWindow(QObject *parent)
    : WindowBase(parent)
{
    m_implicitWidth = 640;
    m_implicitHeight = 480;
}

void FloatingWindow::setTitle(const QString &title)
{
    if (title == m_window->title())
        return;
    m_window->setTitle(title);
    emit titleChanged();
}

void FloatingWindow::setMinimumSize(const QSize &size)
{
    if (size == m_window->minimumSize())
        return;
    m_window->setMinimumSize(size);
    emit minimumSizeChanged();
}

void FloatingWindow::setMaximumSize(const QSize &size)
{
    if (size == m_window->maximumSize())
        return;
    m_window->setMaximumSize(size);
    emit maximumSizeChanged();
}

PopupWindow::PopupWindow(QObject *parent)
    : WindowBase(parent)
    , m_anchor(new PopupAnchor(this))
{
    m_visible = false;
}

void PopupWindow::componentComplete()
{
    WindowBase::componentComplete();
}

void PopupWindow::configure()
{
    QQuickWindow *parentWindow = nullptr;
    if (m_anchor->window())
        parentWindow = m_anchor->window()->window();
    else if (m_anchor->item())
        parentWindow = m_anchor->item()->window();
    if (!parentWindow) {
        for (QObject *o = parent(); o && !parentWindow; o = o->parent()) {
            if (auto *w = qobject_cast<WindowBase *>(o))
                parentWindow = w->window();
        }
    }
    m_window->setTransientParent(parentWindow);
    m_window->setFlags(m_grab ? Qt::Popup : Qt::ToolTip);
    QRect r(m_anchor->rect()->x, m_anchor->rect()->y, m_anchor->rect()->width, m_anchor->rect()->height);
    if (m_anchor->item()) {
        QQuickItem *item = m_anchor->item();
        const QRectF scene = item->mapRectToScene(QRectF(0, 0, item->width(), item->height()));
        r = QRect(static_cast<int>(scene.x()) + r.x(), static_cast<int>(scene.y()) + r.y(),
                  r.width() > 0 ? r.width() : static_cast<int>(scene.width()),
                  r.height() > 0 ? r.height() : static_cast<int>(scene.height()));
    }
    r.setWidth(std::max(1, r.width()));
    r.setHeight(std::max(1, r.height()));
    m_window->setProperty("_q_waylandPopupAnchorRect", r);
    m_window->setProperty("_q_waylandPopupAnchor", QVariant::fromValue(Qt::Edges(m_anchor->edges)));
    m_window->setProperty("_q_waylandPopupGravity", QVariant::fromValue(Qt::Edges(m_anchor->gravity)));
    m_window->setProperty("_q_waylandPopupConstraintAdjustment", m_anchor->adjustment);
    if (parentWindow)
        m_window->setPosition(parentWindow->position() + r.topLeft());
}

}
