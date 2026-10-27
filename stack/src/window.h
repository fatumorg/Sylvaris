#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegion>

#include "stack.h"

struct ext_background_effect_surface_v1;

namespace stack {

namespace ExclusionMode {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Normal = 0, Ignore = 1, Auto = 2 };
Q_ENUM_NS(Enum)
}

namespace WlrLayer {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Background = 0, Bottom = 1, Top = 2, Overlay = 3 };
Q_ENUM_NS(Enum)
}

namespace WlrKeyboardFocus {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, Exclusive = 1, OnDemand = 2 };
Q_ENUM_NS(Enum)
}

namespace RegionShape {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Rect = 0, Ellipse = 1 };
Q_ENUM_NS(Enum)
}

namespace Intersection {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Combine = 0, Subtract = 1, Intersect = 2, Xor = 3 };
Q_ENUM_NS(Enum)
}

namespace Edges {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, Top = 1, Left = 2, Right = 4, Bottom = 8 };
Q_ENUM_NS(Enum)
}

namespace PopupAdjustment {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, SlideX = 1, SlideY = 2, Slide = 3, FlipX = 4, FlipY = 8, Flip = 12, ResizeX = 16, ResizeY = 32, Resize = 48, All = 63 };
Q_ENUM_NS(Enum)
}

class Region : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal x MEMBER m_x NOTIFY changed)
    Q_PROPERTY(qreal y MEMBER m_y NOTIFY changed)
    Q_PROPERTY(qreal width MEMBER m_width NOTIFY changed)
    Q_PROPERTY(qreal height MEMBER m_height NOTIFY changed)
    Q_PROPERTY(qreal radius MEMBER m_radius NOTIFY changed)
    Q_PROPERTY(QQuickItem *item READ item WRITE setItem NOTIFY changed)
    Q_PROPERTY(stack::RegionShape::Enum shape MEMBER m_shape NOTIFY changed)
    Q_PROPERTY(stack::Intersection::Enum intersection MEMBER m_intersection NOTIFY changed)
    Q_PROPERTY(QQmlListProperty<stack::Region> regions READ regions)
    Q_CLASSINFO("DefaultProperty", "regions")

public:
    using QObject::QObject;

    QQuickItem *item() const { return m_item; }
    void setItem(QQuickItem *item);
    QQmlListProperty<Region> regions();
    QRegion build() const;
    bool dynamic() const;

signals:
    void changed();

private:
    QRegion own() const;

    qreal m_x = 0;
    qreal m_y = 0;
    qreal m_width = 0;
    qreal m_height = 0;
    qreal m_radius = 0;
    QPointer<QQuickItem> m_item;
    RegionShape::Enum m_shape = RegionShape::Rect;
    Intersection::Enum m_intersection = Intersection::Combine;
    QList<Region *> m_children;
};

class PanelAnchors : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool top MEMBER top NOTIFY changed)
    Q_PROPERTY(bool bottom MEMBER bottom NOTIFY changed)
    Q_PROPERTY(bool left MEMBER left NOTIFY changed)
    Q_PROPERTY(bool right MEMBER right NOTIFY changed)

public:
    using QObject::QObject;
    bool top = false;
    bool bottom = false;
    bool left = false;
    bool right = false;

signals:
    void changed();
};

class PanelMargins : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(int top MEMBER top NOTIFY changed)
    Q_PROPERTY(int bottom MEMBER bottom NOTIFY changed)
    Q_PROPERTY(int left MEMBER left NOTIFY changed)
    Q_PROPERTY(int right MEMBER right NOTIFY changed)

public:
    using QObject::QObject;
    int top = 0;
    int bottom = 0;
    int left = 0;
    int right = 0;

signals:
    void changed();
};

class WlrLayershell : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("attached to PanelWindow")
    QML_ATTACHED(WlrLayershell)
    Q_PROPERTY(stack::WlrLayer::Enum layer MEMBER m_layer NOTIFY changed)
    Q_PROPERTY(QString namespace MEMBER m_namespace NOTIFY changed)
    Q_PROPERTY(stack::WlrKeyboardFocus::Enum keyboardFocus MEMBER m_focus NOTIFY changed)

public:
    using QObject::QObject;
    static WlrLayershell *qmlAttachedProperties(QObject *object) { return new WlrLayershell(object); }

    WlrLayer::Enum m_layer = WlrLayer::Top;
    QString m_namespace = QStringLiteral("sylstack");
    WlrKeyboardFocus::Enum m_focus = WlrKeyboardFocus::None;

signals:
    void changed();
};

class BackgroundEffect : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("attached to windows")
    QML_ATTACHED(BackgroundEffect)
    Q_PROPERTY(stack::Region *blurRegion READ blurRegion WRITE setBlurRegion NOTIFY changed)

public:
    using QObject::QObject;
    static BackgroundEffect *qmlAttachedProperties(QObject *object) { return new BackgroundEffect(object); }
    Region *blurRegion() const { return m_region; }
    void setBlurRegion(Region *region);

signals:
    void changed();

private:
    QPointer<Region> m_region;
};

class WindowBase : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("use PanelWindow, PopupWindow or FloatingWindow")
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool visible READ visible WRITE setVisible NOTIFY visibleChanged)
    Q_PROPERTY(int width READ width NOTIFY widthChanged)
    Q_PROPERTY(int height READ height NOTIFY heightChanged)
    Q_PROPERTY(int implicitWidth READ implicitWidth WRITE setImplicitWidth NOTIFY implicitWidthChanged)
    Q_PROPERTY(int implicitHeight READ implicitHeight WRITE setImplicitHeight NOTIFY implicitHeightChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(stack::ShellScreen *screen READ screen WRITE setScreen NOTIFY screenChanged)
    Q_PROPERTY(QQuickItem *contentItem READ contentItem CONSTANT)
    Q_PROPERTY(QQuickWindow *window READ window CONSTANT)
    Q_PROPERTY(stack::Region *mask READ mask WRITE setMask NOTIFY maskChanged)
    Q_PROPERTY(QQmlListProperty<QObject> data READ data)
    Q_CLASSINFO("DefaultProperty", "data")

public:
    explicit WindowBase(QObject *parent = nullptr);
    ~WindowBase() override;

    bool visible() const { return m_visible; }
    void setVisible(bool visible);
    int width() const { return m_window->width(); }
    int height() const { return m_window->height(); }
    int implicitWidth() const { return m_implicitWidth; }
    void setImplicitWidth(int w);
    int implicitHeight() const { return m_implicitHeight; }
    void setImplicitHeight(int h);
    QColor color() const { return m_window->color(); }
    void setColor(const QColor &color);
    ShellScreen *screen() const { return m_screen; }
    void setScreen(ShellScreen *screen);
    QQuickItem *contentItem() const { return m_window->contentItem(); }
    QQuickWindow *window() const { return m_window; }
    Region *mask() const { return m_mask; }
    void setMask(Region *mask);
    QQmlListProperty<QObject> data();

    void classBegin() override {}
    void componentComplete() override;

signals:
    void visibleChanged();
    void widthChanged();
    void heightChanged();
    void implicitWidthChanged();
    void implicitHeightChanged();
    void colorChanged();
    void screenChanged();
    void maskChanged();
    void closed();

protected:
    virtual void configure() {}
    virtual void applySize();
    void recreate();
    void syncVisible();
    void refreshRegions();
    bool wayland() const;

    QQuickWindow *m_window;
    bool m_visible = true;
    bool m_complete = false;
    bool m_shown = false;
    int m_implicitWidth = 100;
    int m_implicitHeight = 100;
    QPointer<ShellScreen> m_screen;

private:
    void attachEffect();
    void surfaceCreated();
    void surfaceDestroyed();
    void applyBlur(bool force);

    static void dataAppend(QQmlListProperty<QObject> *list, QObject *object);
    static qsizetype dataCount(QQmlListProperty<QObject> *list);
    static QObject *dataAt(QQmlListProperty<QObject> *list, qsizetype index);
    static void dataClear(QQmlListProperty<QObject> *list);

    QPointer<Region> m_mask;
    QPointer<BackgroundEffect> m_effect;
    QRegion m_lastMask;
    bool m_hasMask = false;
    QRegion m_lastBlur;
    bool m_hasBlur = false;
    ::ext_background_effect_surface_v1 *m_blurSurface = nullptr;
    QList<QObject *> m_data;
};

class PanelWindow : public WindowBase
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(stack::PanelAnchors *anchors READ anchors CONSTANT)
    Q_PROPERTY(stack::PanelMargins *margins READ margins CONSTANT)
    Q_PROPERTY(int exclusiveZone READ exclusiveZone WRITE setExclusiveZone NOTIFY exclusiveZoneChanged)
    Q_PROPERTY(stack::ExclusionMode::Enum exclusionMode READ exclusionMode WRITE setExclusionMode NOTIFY exclusionModeChanged)

public:
    explicit PanelWindow(QObject *parent = nullptr);

    PanelAnchors *anchors() const { return m_anchors; }
    PanelMargins *margins() const { return m_margins; }
    int exclusiveZone() const { return m_exclusiveZone; }
    void setExclusiveZone(int zone);
    ExclusionMode::Enum exclusionMode() const { return m_mode; }
    void setExclusionMode(ExclusionMode::Enum mode);
    void componentComplete() override;

signals:
    void exclusiveZoneChanged();
    void exclusionModeChanged();

protected:
    void configure() override;
    void applySize() override;

private:
    void layerChanged();

    PanelAnchors *m_anchors;
    PanelMargins *m_margins;
    int m_exclusiveZone = 0;
    ExclusionMode::Enum m_mode = ExclusionMode::Auto;
    QPointer<WlrLayershell> m_layer;
    QString m_appliedNamespace;
};

class FloatingWindow : public WindowBase
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(QSize minimumSize READ minimumSize WRITE setMinimumSize NOTIFY minimumSizeChanged)
    Q_PROPERTY(QSize maximumSize READ maximumSize WRITE setMaximumSize NOTIFY maximumSizeChanged)

public:
    explicit FloatingWindow(QObject *parent = nullptr);

    QString title() const { return m_window->title(); }
    void setTitle(const QString &title);
    QSize minimumSize() const { return m_window->minimumSize(); }
    void setMinimumSize(const QSize &size);
    QSize maximumSize() const { return m_window->maximumSize(); }
    void setMaximumSize(const QSize &size);

signals:
    void titleChanged();
    void minimumSizeChanged();
    void maximumSizeChanged();
};

class PopupRect : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(int x MEMBER x NOTIFY changed)
    Q_PROPERTY(int y MEMBER y NOTIFY changed)
    Q_PROPERTY(int width MEMBER width NOTIFY changed)
    Q_PROPERTY(int height MEMBER height NOTIFY changed)

public:
    using QObject::QObject;
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;

signals:
    void changed();
};

class PopupAnchor : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(stack::WindowBase *window READ window WRITE setWindow NOTIFY changed)
    Q_PROPERTY(QQuickItem *item READ item WRITE setItem NOTIFY changed)
    Q_PROPERTY(stack::PopupRect *rect READ rect CONSTANT)
    Q_PROPERTY(int edges MEMBER edges NOTIFY changed)
    Q_PROPERTY(int gravity MEMBER gravity NOTIFY changed)
    Q_PROPERTY(int adjustment MEMBER adjustment NOTIFY changed)

public:
    explicit PopupAnchor(QObject *parent)
        : QObject(parent)
        , m_rect(new PopupRect(this))
    {
    }
    PopupRect *rect() const { return m_rect; }
    WindowBase *window() const { return m_window; }
    void setWindow(WindowBase *window)
    {
        if (window != m_window) {
            m_window = window;
            emit changed();
        }
    }
    QQuickItem *item() const { return m_item; }
    void setItem(QQuickItem *item)
    {
        if (item != m_item) {
            m_item = item;
            emit changed();
        }
    }

    int edges = Edges::Top | Edges::Left;
    int gravity = Edges::Bottom | Edges::Right;
    int adjustment = PopupAdjustment::All;

signals:
    void changed();

private:
    PopupRect *m_rect;
    QPointer<WindowBase> m_window;
    QPointer<QQuickItem> m_item;
};

class PopupWindow : public WindowBase
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(stack::PopupAnchor *anchor READ anchor CONSTANT)
    Q_PROPERTY(bool grabFocus MEMBER m_grab NOTIFY grabFocusChanged)

public:
    explicit PopupWindow(QObject *parent = nullptr);
    PopupAnchor *anchor() const { return m_anchor; }
    void componentComplete() override;

signals:
    void grabFocusChanged();

protected:
    void configure() override;

private:
    PopupAnchor *m_anchor;
    bool m_grab = false;
};

}
