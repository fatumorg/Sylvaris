#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QQmlParserStatus>

namespace stack {

class Scope : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQmlListProperty<QObject> children READ data)
    Q_CLASSINFO("DefaultProperty", "children")

public:
    using QObject::QObject;
    QQmlListProperty<QObject> data();

private:
    static void append(QQmlListProperty<QObject> *list, QObject *object);
    static qsizetype count(QQmlListProperty<QObject> *list);
    static QObject *at(QQmlListProperty<QObject> *list, qsizetype index);
    static void clear(QQmlListProperty<QObject> *list);

    QList<QObject *> m_data;
};

class ShellRoot : public Scope
{
    Q_OBJECT
    QML_ELEMENT

public:
    using Scope::Scope;
};

class Singleton : public Scope
{
    Q_OBJECT
    QML_ELEMENT

public:
    using Scope::Scope;
};

class Variants : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QQmlComponent *delegate READ delegate WRITE setDelegate NOTIFY delegateChanged)
    Q_PROPERTY(QVariant model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(QList<QObject *> instances READ instances NOTIFY instancesChanged)
    Q_CLASSINFO("DefaultProperty", "delegate")

public:
    using QObject::QObject;
    ~Variants() override;

    QQmlComponent *delegate() const { return m_delegate; }
    void setDelegate(QQmlComponent *delegate);
    QVariant model() const { return m_model; }
    void setModel(const QVariant &model);
    QList<QObject *> instances() const;

    void classBegin() override {}
    void componentComplete() override;

signals:
    void delegateChanged();
    void modelChanged();
    void instancesChanged();

private:
    void update();
    QObject *spawn(const QVariant &value);

    QPointer<QQmlComponent> m_delegate;
    QVariant m_model;
    QList<QPair<QVariant, QObject *>> m_items;
    bool m_complete = false;
};

class LazyLoader : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QQmlComponent *component READ component WRITE setComponent NOTIFY componentChanged)
    Q_PROPERTY(QObject *item READ item NOTIFY itemChanged)
    Q_CLASSINFO("DefaultProperty", "component")

public:
    using QObject::QObject;
    ~LazyLoader() override;

    bool active() const { return m_active; }
    void setActive(bool active);
    QQmlComponent *component() const { return m_component; }
    void setComponent(QQmlComponent *component);
    QObject *item() const { return m_item; }

    void classBegin() override {}
    void componentComplete() override;

signals:
    void activeChanged();
    void componentChanged();
    void itemChanged();

private:
    void sync();

    QPointer<QQmlComponent> m_component;
    QPointer<QObject> m_item;
    bool m_active = false;
    bool m_complete = false;
};

QObject *createFrom(QQmlComponent *component, QObject *owner, const QVariantMap &initial);

}
