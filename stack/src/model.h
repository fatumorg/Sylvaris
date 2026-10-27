#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

namespace stack {

class ObjectModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("models come from services")
    Q_PROPERTY(QList<QObject *> values READ values NOTIFY valuesChanged)

public:
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &parent = {}) const override
    {
        return parent.isValid() ? 0 : static_cast<int>(m_items.size());
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (role != Qt::UserRole || !index.isValid() || index.row() >= m_items.size())
            return {};
        return QVariant::fromValue(m_items.at(index.row()));
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {{Qt::UserRole, "modelData"}};
    }

    QList<QObject *> values() const
    {
        return m_items;
    }

    bool contains(QObject *object) const
    {
        return m_items.contains(object);
    }

    void insert(QObject *object)
    {
        if (!object || m_items.contains(object))
            return;
        const int row = static_cast<int>(m_items.size());
        beginInsertRows({}, row, row);
        m_items.append(object);
        endInsertRows();
        emit valuesChanged();
    }

    void remove(QObject *object)
    {
        const int row = static_cast<int>(m_items.indexOf(object));
        if (row < 0)
            return;
        beginRemoveRows({}, row, row);
        m_items.removeAt(row);
        endRemoveRows();
        emit valuesChanged();
    }

    void replace(const QList<QObject *> &items)
    {
        if (items == m_items)
            return;
        beginResetModel();
        m_items = items;
        endResetModel();
        emit valuesChanged();
    }

signals:
    void valuesChanged();

private:
    QList<QObject *> m_items;
};

}
