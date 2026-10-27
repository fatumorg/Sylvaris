#include "scope.h"

#include "model.h"

#include <QJSValue>
#include <QQmlContext>

namespace stack {

QObject *createFrom(QQmlComponent *component, QObject *owner, const QVariantMap &initial)
{
    QQmlContext *ctx = component->creationContext();
    if (!ctx)
        ctx = qmlContext(owner);
    QObject *obj = component->beginCreate(ctx);
    if (!obj) {
        for (const auto &e : component->errors())
            qWarning("%s", qPrintable(e.toString()));
        return nullptr;
    }
    QVariantMap props;
    for (auto it = initial.cbegin(); it != initial.cend(); ++it) {
        if (obj->metaObject()->indexOfProperty(it.key().toUtf8().constData()) >= 0)
            props.insert(it.key(), it.value());
    }
    if (!props.isEmpty())
        component->setInitialProperties(obj, props);
    QQmlEngine::setObjectOwnership(obj, QQmlEngine::CppOwnership);
    obj->setParent(owner);
    component->completeCreate();
    return obj;
}

QQmlListProperty<QObject> Scope::data()
{
    return {this, &m_data, &Scope::append, &Scope::count, &Scope::at, &Scope::clear};
}

void Scope::append(QQmlListProperty<QObject> *list, QObject *object)
{
    auto *self = static_cast<Scope *>(list->object);
    if (!object)
        return;
    if (!object->parent())
        object->setParent(self);
    self->m_data.append(object);
}

qsizetype Scope::count(QQmlListProperty<QObject> *list)
{
    return static_cast<Scope *>(list->object)->m_data.size();
}

QObject *Scope::at(QQmlListProperty<QObject> *list, qsizetype index)
{
    return static_cast<Scope *>(list->object)->m_data.value(index);
}

void Scope::clear(QQmlListProperty<QObject> *list)
{
    static_cast<Scope *>(list->object)->m_data.clear();
}

Variants::~Variants()
{
    for (auto &item : m_items)
        delete item.second;
}

void Variants::setDelegate(QQmlComponent *delegate)
{
    if (delegate == m_delegate)
        return;
    m_delegate = delegate;
    for (auto &item : m_items)
        item.second->deleteLater();
    m_items.clear();
    emit delegateChanged();
    update();
}

void Variants::setModel(const QVariant &model)
{
    m_model = model;
    emit modelChanged();
    update();
}

QList<QObject *> Variants::instances() const
{
    QList<QObject *> out;
    for (const auto &item : m_items)
        out.append(item.second);
    return out;
}

void Variants::componentComplete()
{
    m_complete = true;
    update();
}

static QVariantList toList(QVariant v)
{
    if (v.userType() == qMetaTypeId<QJSValue>())
        v = v.value<QJSValue>().toVariant();
    if (auto *m = qobject_cast<ObjectModel *>(v.value<QObject *>())) {
        QVariantList out;
        for (QObject *o : m->values())
            out.append(QVariant::fromValue(o));
        return out;
    }
    if (v.typeId() == QMetaType::Int || v.typeId() == QMetaType::Double) {
        QVariantList out;
        for (int i = 0; i < v.toInt(); i++)
            out.append(i);
        return out;
    }
    if (v.canConvert<QVariantList>())
        return v.toList();
    return {};
}

void Variants::update()
{
    if (!m_complete || !m_delegate)
        return;
    const QVariantList values = toList(m_model);
    QList<QPair<QVariant, QObject *>> next;
    QList<QPair<QVariant, QObject *>> old = m_items;
    bool changed = false;
    for (const QVariant &v : values) {
        QObject *found = nullptr;
        for (int i = 0; i < old.size(); i++) {
            if (old[i].first == v) {
                found = old.takeAt(i).second;
                break;
            }
        }
        if (!found) {
            found = spawn(v);
            changed = true;
            if (!found)
                continue;
        }
        next.append({v, found});
    }
    if (!old.isEmpty())
        changed = true;
    m_items = next;
    for (auto &gone : old)
        gone.second->deleteLater();
    if (changed)
        emit instancesChanged();
}

QObject *Variants::spawn(const QVariant &value)
{
    return createFrom(m_delegate, this, {{QStringLiteral("modelData"), value}});
}

LazyLoader::~LazyLoader()
{
    delete m_item;
}

void LazyLoader::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;
    emit activeChanged();
    sync();
}

void LazyLoader::setComponent(QQmlComponent *component)
{
    if (component == m_component)
        return;
    m_component = component;
    emit componentChanged();
    if (m_item) {
        QObject *gone = m_item;
        m_item = nullptr;
        emit itemChanged();
        gone->deleteLater();
    }
    sync();
}

void LazyLoader::componentComplete()
{
    m_complete = true;
    sync();
}

void LazyLoader::sync()
{
    if (!m_complete)
        return;
    if (m_active && !m_item && m_component) {
        m_item = createFrom(m_component, this, {});
        if (m_item)
            emit itemChanged();
    } else if (!m_active && m_item) {
        QObject *gone = m_item;
        m_item = nullptr;
        emit itemChanged();
        gone->deleteLater();
    }
}

}
