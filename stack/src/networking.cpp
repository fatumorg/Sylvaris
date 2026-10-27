#include "networking.h"

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

using NMSettings = QMap<QString, QVariantMap>;
Q_DECLARE_METATYPE(NMSettings)

namespace stack {

namespace {

const QString Service = QStringLiteral("org.freedesktop.NetworkManager");
const QString RootPath = QStringLiteral("/org/freedesktop/NetworkManager");
const QString RootIface = QStringLiteral("org.freedesktop.NetworkManager");
const QString DeviceIface = QStringLiteral("org.freedesktop.NetworkManager.Device");
const QString WirelessIface = QStringLiteral("org.freedesktop.NetworkManager.Device.Wireless");
const QString ApIface = QStringLiteral("org.freedesktop.NetworkManager.AccessPoint");
const QString SettingsPath = QStringLiteral("/org/freedesktop/NetworkManager/Settings");
const QString SettingsIface = QStringLiteral("org.freedesktop.NetworkManager.Settings");
const QString ConnIface = QStringLiteral("org.freedesktop.NetworkManager.Settings.Connection");
const QString PropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

QDBusConnection bus()
{
    return QDBusConnection::systemBus();
}

template<typename T, typename F>
void async(const QDBusMessage &msg, QObject *ctx, F done)
{
    auto *w = new QDBusPendingCallWatcher(bus().asyncCall(msg), ctx);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, ctx, [w, done] {
        QDBusPendingReply<T> reply = *w;
        w->deleteLater();
        done(reply);
    });
}

QDBusMessage getAll(const QString &path, const QString &iface)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, path, PropsIface, QStringLiteral("GetAll"));
    msg << iface;
    return msg;
}

int securityOf(const QVariantMap &ap)
{
    const uint flags = ap.value(QStringLiteral("Flags")).toUInt();
    const uint wpa = ap.value(QStringLiteral("WpaFlags")).toUInt();
    const uint rsn = ap.value(QStringLiteral("RsnFlags")).toUInt();
    if (rsn & 0x400)
        return WifiSecurityType::Sae;
    if (rsn & 0x800)
        return WifiSecurityType::Owe;
    if (rsn & 0x200)
        return WifiSecurityType::Wpa2Eap;
    if (wpa & 0x200)
        return WifiSecurityType::WpaEap;
    if (rsn & 0x100)
        return WifiSecurityType::Wpa2Psk;
    if (wpa & 0x100)
        return WifiSecurityType::WpaPsk;
    if (flags & 0x1)
        return WifiSecurityType::StaticWep;
    return WifiSecurityType::Open;
}

int failReason(uint reason)
{
    switch (reason) {
    case 7:
        return ConnectionFailReason::NoSecrets;
    case 8:
        return ConnectionFailReason::WifiClientDisconnected;
    case 9:
    case 10:
        return ConnectionFailReason::WifiClientFailed;
    case 11:
        return ConnectionFailReason::WifiAuthTimeout;
    case 53:
        return ConnectionFailReason::WifiNetworkLost;
    default:
        return ConnectionFailReason::Unknown;
    }
}

}

QString WifiSecurityType::toString(int type)
{
    switch (type) {
    case Open:
        return QStringLiteral("Open");
    case StaticWep:
        return QStringLiteral("WEP");
    case WpaPsk:
        return QStringLiteral("WPA");
    case Wpa2Psk:
        return QStringLiteral("WPA2");
    case Sae:
        return QStringLiteral("WPA3");
    case WpaEap:
        return QStringLiteral("WPA Enterprise");
    case Wpa2Eap:
        return QStringLiteral("WPA2 Enterprise");
    case Owe:
        return QStringLiteral("Enhanced Open");
    default:
        return QStringLiteral("Unknown");
    }
}

WifiNetwork::WifiNetwork(const QString &name, NetworkDevice *device)
    : QObject(device)
    , m_name(name)
    , m_device(device)
{
}

void WifiNetwork::update(qreal strength, int security, bool connected, bool known, bool changing, const QString &ap)
{
    m_ap = ap;
    if (strength == m_strength && security == m_security && connected == m_connected && known == m_known && changing == m_changing)
        return;
    m_strength = strength;
    m_security = security;
    m_connected = connected;
    m_known = known;
    m_changing = changing;
    emit changed();
}

void WifiNetwork::connect()
{
    m_device->activate(this, {}, false);
}

void WifiNetwork::connectWithPsk(const QString &psk)
{
    m_device->activate(this, psk, true);
}

void WifiNetwork::disconnect()
{
    if (m_connected)
        m_device->deactivate();
}

void WifiNetwork::forget()
{
    m_device->forget(m_name);
}

NetworkDevice::NetworkDevice(const QString &path, int type, QObject *parent)
    : QObject(parent)
    , m_path(path)
    , m_type(type)
    , m_networks(new ObjectModel(this))
{
    m_scanTimer.setInterval(10000);
    QObject::connect(&m_scanTimer, &QTimer::timeout, this, &NetworkDevice::scanNow);
    m_rebuild.setSingleShot(true);
    m_rebuild.setInterval(50);
    QObject::connect(&m_rebuild, &QTimer::timeout, this, &NetworkDevice::rebuild);
    QObject::connect(Networking::instance(), &Networking::knownChanged, &m_rebuild, qOverload<>(&QTimer::start));
    fetch();
}

void NetworkDevice::fetch()
{
    async<QVariantMap>(getAll(m_path, DeviceIface), this, [this](const QDBusPendingReply<QVariantMap> &r) {
        if (!r.isError())
            apply(r.value());
    });
    if (m_type != DeviceType::Wifi)
        return;
    async<QVariantMap>(getAll(m_path, WirelessIface), this, [this](const QDBusPendingReply<QVariantMap> &r) {
        if (r.isError())
            return;
        apply(r.value());
        const QDBusArgument arg = r.value().value(QStringLiteral("AccessPoints")).value<QDBusArgument>();
        for (const QDBusObjectPath &p : qdbus_cast<QList<QDBusObjectPath>>(arg))
            apAdded(p.path());
    });
}

void NetworkDevice::apply(const QVariantMap &props)
{
    bool touched = false;
    if (props.contains(QStringLiteral("State"))) {
        m_state = props.value(QStringLiteral("State")).toUInt();
        touched = true;
    }
    if (props.contains(QStringLiteral("Interface"))) {
        m_interface = props.value(QStringLiteral("Interface")).toString();
        touched = true;
    }
    if (props.contains(QStringLiteral("ActiveAccessPoint"))) {
        m_activeAp = props.value(QStringLiteral("ActiveAccessPoint")).value<QDBusObjectPath>().path();
        touched = true;
    }
    if (touched) {
        emit changed();
        m_rebuild.start();
    }
}

void NetworkDevice::apAdded(const QString &path)
{
    if (m_type != DeviceType::Wifi || m_aps.contains(path))
        return;
    m_aps.insert(path, {});
    fetchAp(path);
}

void NetworkDevice::apRemoved(const QString &path)
{
    if (m_aps.remove(path))
        m_rebuild.start();
}

void NetworkDevice::fetchAp(const QString &path)
{
    async<QVariantMap>(getAll(path, ApIface), this, [this, path](const QDBusPendingReply<QVariantMap> &r) {
        if (!r.isError() && m_aps.contains(path))
            apApply(path, r.value());
    });
}

void NetworkDevice::apApply(const QString &path, const QVariantMap &props)
{
    if (!m_aps.contains(path))
        return;
    QVariantMap &ap = m_aps[path];
    for (auto it = props.cbegin(); it != props.cend(); ++it)
        ap.insert(it.key(), it.value());
    m_rebuild.start();
}

void NetworkDevice::stateChanged(uint state, uint reason)
{
    m_state = state;
    if (!m_activating.isEmpty()) {
        WifiNetwork *n = m_bySsid.value(m_activating);
        if (state == 120 || (state == 30 && reason != 0 && reason != 39)) {
            const QString ssid = m_activating;
            m_activating.clear();
            if (n)
                emit n->connectionFailed(failReason(reason));
            Q_UNUSED(ssid)
        } else if (state == 100) {
            m_activating.clear();
        }
    }
    emit changed();
    m_rebuild.start();
}

void NetworkDevice::rebuild()
{
    QString activeSsid;
    if (!m_activeAp.isEmpty() && m_activeAp != QStringLiteral("/"))
        activeSsid = QString::fromUtf8(m_aps.value(m_activeAp).value(QStringLiteral("Ssid")).toByteArray());
    const QStringList known = Networking::instance()->knownSsids();
    QHash<QString, QPair<QString, QVariantMap>> best;
    for (auto it = m_aps.cbegin(); it != m_aps.cend(); ++it) {
        const QString ssid = QString::fromUtf8(it.value().value(QStringLiteral("Ssid")).toByteArray());
        if (ssid.isEmpty())
            continue;
        const int strength = it.value().value(QStringLiteral("Strength")).toInt();
        if (!best.contains(ssid) || best.value(ssid).second.value(QStringLiteral("Strength")).toInt() < strength)
            best.insert(ssid, {it.key(), it.value()});
    }
    QHash<QString, WifiNetwork *> next;
    QList<QObject *> list;
    for (auto it = best.cbegin(); it != best.cend(); ++it) {
        WifiNetwork *n = m_bySsid.take(it.key());
        if (!n)
            n = new WifiNetwork(it.key(), this);
        const bool connected = it.key() == activeSsid && m_state == 100;
        const bool changing = it.key() == m_activating || (it.key() == activeSsid && ((m_state >= 40 && m_state < 100) || m_state == 110));
        n->update(it.value().second.value(QStringLiteral("Strength")).toInt() / 100.0, securityOf(it.value().second), connected, known.contains(it.key()), changing,
                  it.value().first);
        next.insert(it.key(), n);
        list << n;
    }
    std::sort(list.begin(), list.end(), [](QObject *a, QObject *b) {
        auto *x = static_cast<WifiNetwork *>(a);
        auto *y = static_cast<WifiNetwork *>(b);
        if (x->property("connected").toBool() != y->property("connected").toBool())
            return x->property("connected").toBool();
        return x->property("signalStrength").toReal() > y->property("signalStrength").toReal();
    });
    const auto old = m_bySsid;
    m_bySsid = next;
    m_networks->replace(list);
    for (WifiNetwork *n : old)
        n->deleteLater();
}

void NetworkDevice::setScannerEnabled(bool on)
{
    if (on == m_scanning)
        return;
    m_scanning = on;
    if (on) {
        scanNow();
        m_scanTimer.start();
    } else {
        m_scanTimer.stop();
    }
    emit scannerChanged();
}

void NetworkDevice::scanNow()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, m_path, WirelessIface, QStringLiteral("RequestScan"));
    msg << QVariantMap();
    bus().asyncCall(msg);
}

void NetworkDevice::activate(WifiNetwork *network, const QString &psk, bool withPsk)
{
    const QString ssid = network->name();
    const QStringList paths = Networking::instance()->knownPaths().value(ssid);
    m_activating = ssid;
    m_rebuild.start();
    if (!paths.isEmpty() && !withPsk) {
        QDBusMessage msg = QDBusMessage::createMethodCall(Service, RootPath, RootIface, QStringLiteral("ActivateConnection"));
        msg << QVariant::fromValue(QDBusObjectPath(paths.first())) << QVariant::fromValue(QDBusObjectPath(m_path)) << QVariant::fromValue(QDBusObjectPath(QStringLiteral("/")));
        QPointer<WifiNetwork> guard(network);
        async<QDBusObjectPath>(msg, this, [this, guard](const QDBusPendingReply<QDBusObjectPath> &r) {
            if (r.isError() && guard) {
                m_activating.clear();
                emit guard->connectionFailed(ConnectionFailReason::Unknown);
                m_rebuild.start();
            }
        });
        return;
    }
    for (const QString &p : paths) {
        QDBusMessage del = QDBusMessage::createMethodCall(Service, p, ConnIface, QStringLiteral("Delete"));
        bus().asyncCall(del);
    }
    NMSettings settings;
    settings[QStringLiteral("connection")] = {{QStringLiteral("type"), QStringLiteral("802-11-wireless")}, {QStringLiteral("id"), ssid}};
    settings[QStringLiteral("802-11-wireless")] = {{QStringLiteral("ssid"), ssid.toUtf8()}, {QStringLiteral("mode"), QStringLiteral("infrastructure")}};
    const int security = network->property("security").toInt();
    if (withPsk && security != WifiSecurityType::Open) {
        const QString mgmt = security == WifiSecurityType::Sae ? QStringLiteral("sae") : security == WifiSecurityType::StaticWep ? QStringLiteral("none") : QStringLiteral("wpa-psk");
        QVariantMap sec {{QStringLiteral("key-mgmt"), mgmt}};
        if (security == WifiSecurityType::StaticWep)
            sec.insert(QStringLiteral("wep-key0"), psk);
        else
            sec.insert(QStringLiteral("psk"), psk);
        settings[QStringLiteral("802-11-wireless-security")] = sec;
    }
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, RootPath, RootIface, QStringLiteral("AddAndActivateConnection"));
    msg << QVariant::fromValue(settings) << QVariant::fromValue(QDBusObjectPath(m_path)) << QVariant::fromValue(QDBusObjectPath(network->accessPoint().isEmpty() ? QStringLiteral("/") : network->accessPoint()));
    QPointer<WifiNetwork> guard(network);
    auto *w = new QDBusPendingCallWatcher(bus().asyncCall(msg), this);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, this, [this, w, guard] {
        const QDBusMessage reply = w->reply();
        w->deleteLater();
        if (reply.type() == QDBusMessage::ErrorMessage && guard) {
            m_activating.clear();
            emit guard->connectionFailed(reply.errorName().contains(QStringLiteral("Secret")) ? ConnectionFailReason::NoSecrets : ConnectionFailReason::Unknown);
            m_rebuild.start();
        }
        Networking::instance()->refreshKnown();
    });
}

void NetworkDevice::deactivate()
{
    bus().asyncCall(QDBusMessage::createMethodCall(Service, m_path, DeviceIface, QStringLiteral("Disconnect")));
}

void NetworkDevice::forget(const QString &ssid)
{
    for (const QString &p : Networking::instance()->knownPaths().value(ssid))
        bus().asyncCall(QDBusMessage::createMethodCall(Service, p, ConnIface, QStringLiteral("Delete")));
}

Networking::Networking()
    : m_devices(new ObjectModel(this))
{
    qDBusRegisterMetaType<NMSettings>();
    QMetaObject::invokeMethod(this, &Networking::start, Qt::QueuedConnection);
}

Networking *Networking::instance()
{
    static Networking *self = new Networking();
    return self;
}

Networking *Networking::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

void Networking::start()
{
    if (!bus().isConnected())
        return;
    bus().connect(Service, QString(), PropsIface, QStringLiteral("PropertiesChanged"), this, SLOT(propertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
    bus().connect(Service, RootPath, RootIface, QStringLiteral("DeviceAdded"), this, SLOT(deviceAdded(QDBusObjectPath)));
    bus().connect(Service, RootPath, RootIface, QStringLiteral("DeviceRemoved"), this, SLOT(deviceRemoved(QDBusObjectPath)));
    bus().connect(Service, QString(), WirelessIface, QStringLiteral("AccessPointAdded"), this, SLOT(apAdded(QDBusObjectPath, QDBusMessage)));
    bus().connect(Service, QString(), WirelessIface, QStringLiteral("AccessPointRemoved"), this, SLOT(apRemoved(QDBusObjectPath, QDBusMessage)));
    bus().connect(Service, QString(), DeviceIface, QStringLiteral("StateChanged"), this, SLOT(deviceState(uint, uint, uint, QDBusMessage)));
    bus().connect(Service, SettingsPath, SettingsIface, QStringLiteral("NewConnection"), this, SLOT(settingsChanged()));
    bus().connect(Service, SettingsPath, SettingsIface, QStringLiteral("ConnectionRemoved"), this, SLOT(settingsChanged()));
    async<QVariantMap>(getAll(RootPath, RootIface), this, [this](const QDBusPendingReply<QVariantMap> &r) {
        if (r.isError())
            return;
        m_available = true;
        emit backendChanged();
        m_wifi = r.value().value(QStringLiteral("WirelessEnabled")).toBool();
        m_wifiHardware = r.value().value(QStringLiteral("WirelessHardwareEnabled"), true).toBool();
        emit wifiEnabledChanged();
        refreshKnown();
        async<QList<QDBusObjectPath>>(QDBusMessage::createMethodCall(Service, RootPath, RootIface, QStringLiteral("GetDevices")), this,
                                      [this](const QDBusPendingReply<QList<QDBusObjectPath>> &d) {
                                          if (d.isError())
                                              return;
                                          for (const QDBusObjectPath &p : d.value())
                                              addDevice(p.path());
                                      });
    });
}

void Networking::addDevice(const QString &path)
{
    if (m_byPath.contains(path))
        return;
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, path, PropsIface, QStringLiteral("Get"));
    msg << DeviceIface << QStringLiteral("DeviceType");
    async<QDBusVariant>(msg, this, [this, path](const QDBusPendingReply<QDBusVariant> &r) {
        if (r.isError() || m_byPath.contains(path))
            return;
        const uint t = r.value().variant().toUInt();
        const int type = t == 2 ? DeviceType::Wifi : t == 1 ? DeviceType::Wired : DeviceType::Other;
        auto *d = new NetworkDevice(path, type, this);
        m_byPath.insert(path, d);
        m_devices->insert(d);
    });
}

void Networking::setWifiEnabled(bool on)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, RootPath, PropsIface, QStringLiteral("Set"));
    msg << RootIface << QStringLiteral("WirelessEnabled") << QVariant::fromValue(QDBusVariant(on));
    bus().asyncCall(msg);
}

void Networking::refreshKnown()
{
    async<QList<QDBusObjectPath>>(QDBusMessage::createMethodCall(Service, SettingsPath, SettingsIface, QStringLiteral("ListConnections")), this,
                                  [this](const QDBusPendingReply<QList<QDBusObjectPath>> &r) {
                                      if (r.isError())
                                          return;
                                      const QList<QDBusObjectPath> paths = r.value();
                                      auto pending = std::make_shared<int>(static_cast<int>(paths.size()));
                                      auto found = std::make_shared<QHash<QString, QStringList>>();
                                      auto finish = [this, found] {
                                          m_knownPaths = *found;
                                          m_known = found->keys();
                                          emit knownChanged();
                                      };
                                      if (paths.isEmpty())
                                          finish();
                                      for (const QDBusObjectPath &p : paths) {
                                          async<NMSettings>(QDBusMessage::createMethodCall(Service, p.path(), ConnIface, QStringLiteral("GetSettings")), this,
                                                            [p, pending, found, finish](const QDBusPendingReply<NMSettings> &s) {
                                                                if (!s.isError()) {
                                                                    const NMSettings v = s.value();
                                                                    if (v.value(QStringLiteral("connection")).value(QStringLiteral("type")).toString() == QStringLiteral("802-11-wireless")) {
                                                                        const QString ssid = QString::fromUtf8(v.value(QStringLiteral("802-11-wireless")).value(QStringLiteral("ssid")).toByteArray());
                                                                        if (!ssid.isEmpty())
                                                                            (*found)[ssid] << p.path();
                                                                    }
                                                                }
                                                                if (--*pending == 0)
                                                                    finish();
                                                            });
                                      }
                                  });
}

void Networking::settingsChanged()
{
    refreshKnown();
}

void Networking::propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &, const QDBusMessage &msg)
{
    const QString path = msg.path();
    if (iface == RootIface && path == RootPath) {
        if (changed.contains(QStringLiteral("WirelessEnabled"))) {
            m_wifi = changed.value(QStringLiteral("WirelessEnabled")).toBool();
            emit wifiEnabledChanged();
        }
        if (changed.contains(QStringLiteral("WirelessHardwareEnabled"))) {
            m_wifiHardware = changed.value(QStringLiteral("WirelessHardwareEnabled")).toBool();
            emit wifiEnabledChanged();
        }
    } else if (iface == DeviceIface || iface == WirelessIface) {
        if (NetworkDevice *d = m_byPath.value(path))
            d->apply(changed);
    } else if (iface == ApIface) {
        for (NetworkDevice *d : std::as_const(m_byPath))
            d->apApply(path, changed);
    }
}

void Networking::deviceAdded(const QDBusObjectPath &path)
{
    addDevice(path.path());
}

void Networking::deviceRemoved(const QDBusObjectPath &path)
{
    if (NetworkDevice *d = m_byPath.take(path.path())) {
        m_devices->remove(d);
        d->deleteLater();
    }
}

void Networking::apAdded(const QDBusObjectPath &path, const QDBusMessage &msg)
{
    if (NetworkDevice *d = m_byPath.value(msg.path()))
        d->apAdded(path.path());
}

void Networking::apRemoved(const QDBusObjectPath &path, const QDBusMessage &msg)
{
    if (NetworkDevice *d = m_byPath.value(msg.path()))
        d->apRemoved(path.path());
}

void Networking::deviceState(uint state, uint, uint reason, const QDBusMessage &msg)
{
    if (NetworkDevice *d = m_byPath.value(msg.path()))
        d->stateChanged(state, reason);
}

}
