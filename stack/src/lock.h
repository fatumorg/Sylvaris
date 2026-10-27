#pragma once

#include "window.h"

#include <QPointer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlParserStatus>

namespace stack {

class WlSessionLockSurface : public WindowBase
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit WlSessionLockSurface(QObject *parent = nullptr);

protected:
    void configure() override;
    void applySize() override;
};

class WlSessionLock : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool locked READ locked WRITE setLocked NOTIFY lockedChanged)
    Q_PROPERTY(bool secure READ secure NOTIFY secureChanged)
    Q_PROPERTY(QQmlComponent *surface READ surface WRITE setSurface NOTIFY surfaceChanged)
    Q_CLASSINFO("DefaultProperty", "surface")

public:
    explicit WlSessionLock(QObject *parent = nullptr);
    ~WlSessionLock() override;

    bool locked() const { return m_locked; }
    void setLocked(bool locked);
    bool secure() const;
    QQmlComponent *surface() const { return m_surface; }
    void setSurface(QQmlComponent *surface);

    void classBegin() override {}
    void componentComplete() override;

signals:
    void lockedChanged();
    void secureChanged();
    void surfaceChanged();

private slots:
    void lockStateChanged();

private:
    void apply();
    void syncSurfaces();
    void dropSurfaces();

    bool m_locked = false;
    bool m_complete = false;
    QPointer<QQmlComponent> m_surface;
    QHash<QObject *, QPointer<QObject>> m_surfaces;
};

}
