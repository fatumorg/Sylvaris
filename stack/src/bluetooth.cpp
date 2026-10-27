#include "bluetooth.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

namespace stack {

namespace {

const QString Service = QStringLiteral("org.bluez");
const QString AdapterIface = QStringLiteral("org.bluez.Adapter1");
const QString DeviceIface = QStringLiteral("org.bluez.Device1");
const QString BatteryIface = QStringLiteral("org.bluez.Battery1");
const QString PropsIface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString ManagerIface = QStringLiteral("org.freedesktop.DBus.ObjectManager");

QDBusConnection bus()
{
    return QDBusConnection::systemBus();
}

void setRemote(const QString &path, const QString &iface, const QString &name, const QVariant &value)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, path, PropsIface, QStringLiteral("Set"));
    msg << iface << name << QVariant::fromValue(QDBusVariant(value));
    bus().asyncCall(msg);
}

QMap<QString, QVariantMap> readInterfaces(const QDBusArgument &arg)
{
    QMap<QString, QVariantMap> out;
    arg.beginMap();
    while (!arg.atEnd()) {
        QString name;
        QVariantMap props;
        arg.beginMapEntry();
        arg >> name >> props;
        arg.endMapEntry();
        out.insert(name, props);
    }
    arg.endMap();
    return out;
}

}

BluetoothAdapter::BluetoothAdapter(const QString &path, QObject *parent)
    : QObject(parent)
    , m_path(path)
{
}

void BluetoothAdapter::setEnabled(bool on)
{
    if (on == m_powered)
        return;
    setRemote(m_path, AdapterIface, QStringLiteral("Powered"), on);
}

void BluetoothAdapter::setDiscovering(bool on)
{
    if (on == m_discovering)
        return;
    bus().asyncCall(QDBusMessage::createMethodCall(Service, m_path, AdapterIface, on ? QStringLiteral("StartDiscovery") : QStringLiteral("StopDiscovery")));
}

void BluetoothAdapter::apply(const QVariantMap &props)
{
    if (props.contains(QStringLiteral("Alias")))
        m_name = props.value(QStringLiteral("Alias")).toString();
    else if (m_name.isEmpty() && props.contains(QStringLiteral("Name")))
        m_name = props.value(QStringLiteral("Name")).toString();
    if (props.contains(QStringLiteral("Powered")))
        m_powered = props.value(QStringLiteral("Powered")).toBool();
    if (props.contains(QStringLiteral("Discovering")))
        m_discovering = props.value(QStringLiteral("Discovering")).toBool();
    emit changed();
}

BluetoothDevice::BluetoothDevice(const QString &path, QObject *parent)
    : QObject(parent)
    , m_path(path)
{
}

void BluetoothDevice::setTrusted(bool on)
{
    if (on == m_trusted)
        return;
    setRemote(m_path, DeviceIface, QStringLiteral("Trusted"), on);
}

int BluetoothDevice::state() const
{
    if (m_disconnecting)
        return BluetoothDeviceState::Disconnecting;
    if (m_connecting)
        return BluetoothDeviceState::Connecting;
    return m_connected ? BluetoothDeviceState::Connected : BluetoothDeviceState::Disconnected;
}

void BluetoothDevice::apply(const QVariantMap &props)
{
    const auto str = [&](const char *key, QString &into) {
        const QString k = QString::fromLatin1(key);
        if (props.contains(k))
            into = props.value(k).toString();
    };
    const auto flag = [&](const char *key, bool &into) {
        const QString k = QString::fromLatin1(key);
        if (props.contains(k))
            into = props.value(k).toBool();
    };
    str("Address", m_address);
    str("Alias", m_alias);
    str("Name", m_deviceName);
    str("Icon", m_icon);
    flag("Connected", m_connected);
    flag("Paired", m_paired);
    flag("Trusted", m_trusted);
    if (props.contains(QStringLiteral("Adapter")))
        m_adapter = props.value(QStringLiteral("Adapter")).value<QDBusObjectPath>().path();
    if (m_deviceName.isEmpty())
        m_deviceName = m_address;
    if (props.contains(QStringLiteral("Connected"))) {
        m_connecting = false;
        m_disconnecting = false;
    }
    emit changed();
}

void BluetoothDevice::applyBattery(const QVariantMap &props)
{
    if (!props.contains(QStringLiteral("Percentage")))
        return;
    m_hasBattery = true;
    m_battery = qBound(0u, props.value(QStringLiteral("Percentage")).toUInt(), 100u) / 100.0;
    emit changed();
}

void BluetoothDevice::dropBattery()
{
    m_hasBattery = false;
    m_battery = 0;
    emit changed();
}

void BluetoothDevice::call(const QString &method, std::function<void(bool)> done)
{
    auto *w = new QDBusPendingCallWatcher(bus().asyncCall(QDBusMessage::createMethodCall(Service, m_path, DeviceIface, method), 60000), this);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, this, [w, done] {
        const bool ok = !w->isError();
        w->deleteLater();
        if (done)
            done(ok);
    });
}

void BluetoothDevice::connect()
{
    if (m_connecting)
        return;
    m_connecting = true;
    m_disconnecting = false;
    emit changed();
    call(QStringLiteral("Connect"), [this](bool) {
        m_connecting = false;
        emit changed();
    });
}

void BluetoothDevice::disconnect()
{
    if (m_disconnecting)
        return;
    m_disconnecting = true;
    m_connecting = false;
    emit changed();
    call(QStringLiteral("Disconnect"), [this](bool) {
        m_disconnecting = false;
        emit changed();
    });
}

void BluetoothDevice::pair()
{
    if (m_pairing)
        return;
    m_pairing = true;
    emit changed();
    call(QStringLiteral("Pair"), [this](bool) {
        m_pairing = false;
        emit changed();
    });
}

void BluetoothDevice::cancelPair()
{
    if (m_pairing)
        bus().asyncCall(QDBusMessage::createMethodCall(Service, m_path, DeviceIface, QStringLiteral("CancelPairing")));
}

void BluetoothDevice::forget()
{
    if (m_adapter.isEmpty())
        return;
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, m_adapter, AdapterIface, QStringLiteral("RemoveDevice"));
    msg << QVariant::fromValue(QDBusObjectPath(m_path));
    bus().asyncCall(msg);
}

Bluetooth *Bluetooth::create(QQmlEngine *, QJSEngine *)
{
    auto *b = new Bluetooth;
    QJSEngine::setObjectOwnership(b, QJSEngine::CppOwnership);
    return b;
}

Bluetooth::Bluetooth()
    : m_adapters(new ObjectModel(this))
    , m_devices(new ObjectModel(this))
    , m_watcher(Service, bus(), QDBusServiceWatcher::WatchForOwnerChange)
{
    bus().connect(Service, QString(), ManagerIface, QStringLiteral("InterfacesAdded"), this, SLOT(interfacesAdded(QDBusObjectPath, QDBusMessage)));
    bus().connect(Service, QString(), ManagerIface, QStringLiteral("InterfacesRemoved"), this, SLOT(interfacesRemoved(QDBusObjectPath, QStringList)));
    bus().connect(Service, QString(), PropsIface, QStringLiteral("PropertiesChanged"), this, SLOT(propertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
    QObject::connect(&m_watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString &, const QString &, const QString &owner) {
        clear();
        if (!owner.isEmpty())
            load();
    });
    load();
}

BluetoothAdapter *Bluetooth::defaultAdapter() const
{
    BluetoothAdapter *best = nullptr;
    for (BluetoothAdapter *a : m_adapterByPath)
        if (!best || a->path() < best->path())
            best = a;
    return best;
}

void Bluetooth::load()
{
    auto *w = new QDBusPendingCallWatcher(bus().asyncCall(QDBusMessage::createMethodCall(Service, QStringLiteral("/"), ManagerIface, QStringLiteral("GetManagedObjects"))), this);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        w->deleteLater();
        const QDBusMessage reply = w->reply();
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
            return;
        const QDBusArgument arg = reply.arguments().constFirst().value<QDBusArgument>();
        arg.beginMap();
        while (!arg.atEnd()) {
            QDBusObjectPath path;
            arg.beginMapEntry();
            arg >> path;
            const auto ifaces = readInterfaces(arg);
            arg.endMapEntry();
            addInterfaces(path.path(), ifaces);
        }
        arg.endMap();
    });
}

void Bluetooth::clear()
{
    m_devices->replace({});
    m_adapters->replace({});
    for (QObject *o : m_deviceByPath)
        o->deleteLater();
    for (QObject *o : m_adapterByPath)
        o->deleteLater();
    m_deviceByPath.clear();
    m_adapterByPath.clear();
    emit adaptersChanged();
}

void Bluetooth::addInterfaces(const QString &path, const QMap<QString, QVariantMap> &ifaces)
{
    if (ifaces.contains(AdapterIface)) {
        BluetoothAdapter *a = m_adapterByPath.value(path);
        const bool fresh = !a;
        if (fresh)
            a = new BluetoothAdapter(path, this);
        a->apply(ifaces.value(AdapterIface));
        if (fresh) {
            m_adapterByPath.insert(path, a);
            m_adapters->insert(a);
            emit adaptersChanged();
        }
    }
    if (ifaces.contains(DeviceIface)) {
        BluetoothDevice *d = m_deviceByPath.value(path);
        const bool fresh = !d;
        if (fresh)
            d = new BluetoothDevice(path, this);
        d->apply(ifaces.value(DeviceIface));
        if (fresh) {
            m_deviceByPath.insert(path, d);
            m_devices->insert(d);
        }
    }
    if (ifaces.contains(BatteryIface))
        if (BluetoothDevice *d = m_deviceByPath.value(path))
            d->applyBattery(ifaces.value(BatteryIface));
}

void Bluetooth::interfacesAdded(const QDBusObjectPath &path, const QDBusMessage &msg)
{
    if (msg.arguments().size() < 2)
        return;
    addInterfaces(path.path(), readInterfaces(msg.arguments().at(1).value<QDBusArgument>()));
}

void Bluetooth::interfacesRemoved(const QDBusObjectPath &path, const QStringList &ifaces)
{
    const QString p = path.path();
    if (ifaces.contains(BatteryIface))
        if (BluetoothDevice *d = m_deviceByPath.value(p))
            d->dropBattery();
    if (ifaces.contains(DeviceIface))
        if (BluetoothDevice *d = m_deviceByPath.take(p)) {
            m_devices->remove(d);
            d->deleteLater();
        }
    if (ifaces.contains(AdapterIface))
        if (BluetoothAdapter *a = m_adapterByPath.take(p)) {
            m_adapters->remove(a);
            emit adaptersChanged();
            a->deleteLater();
        }
}

void Bluetooth::propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &, const QDBusMessage &msg)
{
    const QString p = msg.path();
    if (iface == AdapterIface) {
        if (BluetoothAdapter *a = m_adapterByPath.value(p))
            a->apply(changed);
    } else if (iface == DeviceIface) {
        if (BluetoothDevice *d = m_deviceByPath.value(p))
            d->apply(changed);
    } else if (iface == BatteryIface) {
        if (BluetoothDevice *d = m_deviceByPath.value(p))
            d->applyBattery(changed);
    }
}

}
