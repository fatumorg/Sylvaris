#pragma once

#include "model.h"

#include <QObject>
#include <QQmlEngine>
#include <QtWaylandClient/QWaylandClientExtensionTemplate>

#include "qwayland-hyprland-toplevel-mapping-v1.h"
#include "qwayland-wlr-foreign-toplevel-management-unstable-v1.h"

namespace stack {

class Toplevel : public QObject, public QtWayland::zwlr_foreign_toplevel_handle_v1
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("toplevels come from ToplevelManager")
    Q_PROPERTY(QString appId READ appId NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(bool activated READ activated NOTIFY changed)
    Q_PROPERTY(bool minimized READ minimized WRITE setMinimized NOTIFY changed)
    Q_PROPERTY(bool maximized READ maximized WRITE setMaximized NOTIFY changed)
    Q_PROPERTY(bool fullscreen READ fullscreen WRITE setFullscreen NOTIFY changed)
    Q_PROPERTY(QString address READ address NOTIFY addressChanged)

public:
    explicit Toplevel(struct ::zwlr_foreign_toplevel_handle_v1 *handle, QObject *parent);
    ~Toplevel() override;

    QString appId() const { return m_appId; }
    QString title() const { return m_title; }
    bool activated() const { return m_activated; }
    bool minimized() const { return m_minimized; }
    void setMinimized(bool minimized);
    bool maximized() const { return m_maximized; }
    void setMaximized(bool maximized);
    bool fullscreen() const { return m_fullscreen; }
    void setFullscreen(bool fullscreen);
    QString address() const { return m_address; }
    void setAddress(const QString &address);
    bool ready() const { return m_ready; }

    Q_INVOKABLE void activate();
    Q_INVOKABLE void close();

signals:
    void changed();
    void addressChanged();
    void readyChanged();
    void gone();

protected:
    void zwlr_foreign_toplevel_handle_v1_title(const QString &title) override;
    void zwlr_foreign_toplevel_handle_v1_app_id(const QString &app_id) override;
    void zwlr_foreign_toplevel_handle_v1_state(wl_array *state) override;
    void zwlr_foreign_toplevel_handle_v1_done() override;
    void zwlr_foreign_toplevel_handle_v1_closed() override;

private:
    QString m_appId;
    QString m_title;
    QString m_address;
    bool m_activated = false;
    bool m_minimized = false;
    bool m_maximized = false;
    bool m_fullscreen = false;
    bool m_ready = false;
};

class ToplevelManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::ObjectModel *toplevels READ toplevels CONSTANT)
    Q_PROPERTY(stack::Toplevel *activeToplevel READ activeToplevel NOTIFY activeToplevelChanged)

public:
    static ToplevelManager *instance();
    static ToplevelManager *create(QQmlEngine *, QJSEngine *);

    ObjectModel *toplevels() const { return m_model; }
    Toplevel *activeToplevel() const;
    Toplevel *byAddress(const QString &address) const;
    void added(Toplevel *toplevel);

signals:
    void activeToplevelChanged();
    void addressesChanged();

private:
    ToplevelManager();

    ObjectModel *m_model;
    QList<Toplevel *> m_all;
};

}
