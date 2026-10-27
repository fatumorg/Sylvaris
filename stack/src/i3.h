#pragma once

#include "model.h"

#include <QLocalSocket>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>

namespace stack {

class I3Monitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("monitors come from I3")
    Q_PROPERTY(QString name MEMBER name CONSTANT)

public:
    using QObject::QObject;
    QString name;
};

class I3Workspace : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("workspaces come from I3")
    Q_PROPERTY(qint64 id MEMBER id CONSTANT)
    Q_PROPERTY(int number MEMBER number NOTIFY changed)
    Q_PROPERTY(QString name MEMBER name NOTIFY changed)
    Q_PROPERTY(stack::I3Monitor *monitor MEMBER monitor NOTIFY changed)
    Q_PROPERTY(bool active MEMBER active NOTIFY changed)
    Q_PROPERTY(bool focused MEMBER focused NOTIFY changed)
    Q_PROPERTY(bool urgent MEMBER urgent NOTIFY changed)

public:
    using QObject::QObject;
    qint64 id = 0;
    int number = 0;
    QString name;
    I3Monitor *monitor = nullptr;
    bool active = false;
    bool focused = false;
    bool urgent = false;

signals:
    void changed();
};

class I3 : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::ObjectModel *workspaces READ workspaces CONSTANT)
    Q_PROPERTY(stack::I3Monitor *focusedMonitor READ focusedMonitor NOTIFY focusedMonitorChanged)

public:
    static I3 *create(QQmlEngine *, QJSEngine *);

    ObjectModel *workspaces() const { return m_workspaces; }
    I3Monitor *focusedMonitor() const { return m_focused; }

    Q_INVOKABLE void dispatch(const QString &command);
    Q_INVOKABLE void refresh();

signals:
    void focusedMonitorChanged();

private:
    I3();
    void send(QLocalSocket &socket, quint32 type, const QByteArray &payload);
    void readFrom(QLocalSocket &socket, QByteArray &buffer, bool events);
    void message(quint32 type, const QByteArray &payload, bool events);
    void connectAll();
    void apply(const QByteArray &json);

    QString m_path;
    QLocalSocket m_command;
    QLocalSocket m_events;
    QByteArray m_commandBuffer;
    QByteArray m_eventBuffer;
    QTimer m_retry;
    QTimer m_debounce;
    ObjectModel *m_workspaces;
    QHash<qint64, I3Workspace *> m_byId;
    QHash<QString, I3Monitor *> m_monitors;
    I3Monitor *m_focused = nullptr;
};

}
