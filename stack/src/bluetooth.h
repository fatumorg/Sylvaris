#pragma once

#include "model.h"

#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusServiceWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QVariantMap>

#include <functional>

namespace stack {

namespace BluetoothDeviceState {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Disconnected = 0, Connected = 1, Disconnecting = 2, Connecting = 3 };
Q_ENUM_NS(Enum)
}

class BluetoothAdapter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("adapters come from Bluetooth")
    Q_PROPERTY(QString name MEMBER m_name NOTIFY changed)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(bool discovering READ discovering WRITE setDiscovering NOTIFY changed)

public:
    BluetoothAdapter(const QString &path, QObject *parent);
    QString path() const { return m_path; }
    bool enabled() const { return m_powered; }
    void setEnabled(bool on);
    bool discovering() const { return m_discovering; }
    void setDiscovering(bool on);
    void apply(const QVariantMap &props);

signals:
    void changed();

private:
    QString m_path;
    QString m_name;
    bool m_powered = false;
    bool m_discovering = false;
};

class BluetoothDevice : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("devices come from Bluetooth")
    Q_PROPERTY(QString address MEMBER m_address NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString deviceName MEMBER m_deviceName NOTIFY changed)
    Q_PROPERTY(QString icon MEMBER m_icon NOTIFY changed)
    Q_PROPERTY(bool connected MEMBER m_connected NOTIFY changed)
    Q_PROPERTY(bool paired MEMBER m_paired NOTIFY changed)
    Q_PROPERTY(bool pairing MEMBER m_pairing NOTIFY changed)
    Q_PROPERTY(bool trusted READ trusted WRITE setTrusted NOTIFY changed)
    Q_PROPERTY(int state READ state NOTIFY changed)
    Q_PROPERTY(bool batteryAvailable MEMBER m_hasBattery NOTIFY changed)
    Q_PROPERTY(qreal battery MEMBER m_battery NOTIFY changed)

public:
    BluetoothDevice(const QString &path, QObject *parent);
    QString path() const { return m_path; }
    QString adapter() const { return m_adapter; }
    QString name() const { return m_alias.isEmpty() ? m_deviceName : m_alias; }
    bool trusted() const { return m_trusted; }
    void setTrusted(bool on);
    int state() const;
    void apply(const QVariantMap &props);
    void applyBattery(const QVariantMap &props);
    void dropBattery();

    Q_INVOKABLE void connect();
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void pair();
    Q_INVOKABLE void cancelPair();
    Q_INVOKABLE void forget();

signals:
    void changed();

private:
    void call(const QString &method, std::function<void(bool)> done = {});

    QString m_path;
    QString m_adapter;
    QString m_address;
    QString m_alias;
    QString m_deviceName;
    QString m_icon;
    bool m_connected = false;
    bool m_paired = false;
    bool m_pairing = false;
    bool m_trusted = false;
    bool m_connecting = false;
    bool m_disconnecting = false;
    bool m_hasBattery = false;
    qreal m_battery = 0;
};

class Bluetooth : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::BluetoothAdapter *defaultAdapter READ defaultAdapter NOTIFY adaptersChanged)
    Q_PROPERTY(stack::ObjectModel *adapters READ adapters CONSTANT)
    Q_PROPERTY(stack::ObjectModel *devices READ devices CONSTANT)

public:
    static Bluetooth *create(QQmlEngine *, QJSEngine *);
    BluetoothAdapter *defaultAdapter() const;
    ObjectModel *adapters() const { return m_adapters; }
    ObjectModel *devices() const { return m_devices; }

signals:
    void adaptersChanged();

private slots:
    void interfacesAdded(const QDBusObjectPath &path, const QDBusMessage &msg);
    void interfacesRemoved(const QDBusObjectPath &path, const QStringList &ifaces);
    void propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated, const QDBusMessage &msg);

private:
    Bluetooth();
    void load();
    void clear();
    void addInterfaces(const QString &path, const QMap<QString, QVariantMap> &ifaces);

    ObjectModel *m_adapters;
    ObjectModel *m_devices;
    QDBusServiceWatcher m_watcher;
    QHash<QString, BluetoothAdapter *> m_adapterByPath;
    QHash<QString, BluetoothDevice *> m_deviceByPath;
};

}
