#include "upower.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QMetaEnum>

namespace stack {

namespace {

const QString Service = QStringLiteral("org.freedesktop.UPower");
const QString DeviceIface = QStringLiteral("org.freedesktop.UPower.Device");
const QString PropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

QString spaced(const char *key)
{
    QString out;
    const QString k = QString::fromLatin1(key);
    for (int i = 0; i < k.size(); i++) {
        if (i > 0 && k[i].isUpper() && k[i - 1].isLower())
            out += QLatin1Char(' ');
        out += k[i];
    }
    return out;
}

}

QString UPowerDeviceType::toString(int type)
{
    const char *key = QMetaEnum::fromType<Enum>().valueToKey(type);
    return key ? spaced(key) : QStringLiteral("Invalid Type");
}

QString UPowerDeviceState::toString(int state)
{
    const char *key = QMetaEnum::fromType<Enum>().valueToKey(state);
    return key ? spaced(key) : QStringLiteral("Unknown");
}

UPowerDevice::UPowerDevice(const QString &path, QObject *parent)
    : QObject(parent)
    , m_path(path)
{
    QDBusConnection::systemBus().connect(Service, path, PropsIface, QStringLiteral("PropertiesChanged"), this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
    fetch();
}

void UPowerDevice::fetch()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, m_path, PropsIface, QStringLiteral("GetAll"));
    msg << DeviceIface;
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        QDBusPendingReply<QVariantMap> reply = *w;
        w->deleteLater();
        if (reply.isError())
            return;
        m_ready = true;
        apply(reply.value());
    });
}

void UPowerDevice::apply(const QVariantMap &props)
{
    for (auto it = props.cbegin(); it != props.cend(); ++it) {
        const QString &k = it.key();
        const QVariant &v = it.value();
        if (k == QStringLiteral("Type"))
            m_type = v.toInt();
        else if (k == QStringLiteral("State"))
            m_state = v.toInt();
        else if (k == QStringLiteral("Percentage"))
            m_percentage = v.toDouble() / 100.0;
        else if (k == QStringLiteral("IsPresent"))
            m_present = v.toBool();
        else if (k == QStringLiteral("PowerSupply"))
            m_powerSupply = v.toBool();
        else if (k == QStringLiteral("Model"))
            m_model = v.toString();
        else if (k == QStringLiteral("NativePath"))
            m_nativePath = v.toString();
        else if (k == QStringLiteral("TimeToEmpty"))
            m_toEmpty = v.toLongLong();
        else if (k == QStringLiteral("TimeToFull"))
            m_toFull = v.toLongLong();
        else if (k == QStringLiteral("IconName"))
            m_icon = v.toString();
    }
    emit changed();
}

void UPowerDevice::propertiesChanged(const QString &iface, const QVariantMap &changedProps, const QStringList &invalidated)
{
    if (iface != DeviceIface)
        return;
    apply(changedProps);
    if (!invalidated.isEmpty())
        fetch();
}

UPower::UPower()
    : m_devices(new ObjectModel(this))
{
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected())
        return;
    m_display = new UPowerDevice(QStringLiteral("/org/freedesktop/UPower/devices/DisplayDevice"), this);
    bus.connect(Service, QStringLiteral("/org/freedesktop/UPower"), Service, QStringLiteral("DeviceAdded"), this, SLOT(added(QDBusObjectPath)));
    bus.connect(Service, QStringLiteral("/org/freedesktop/UPower"), Service, QStringLiteral("DeviceRemoved"), this, SLOT(removed(QDBusObjectPath)));
    bus.connect(Service, QStringLiteral("/org/freedesktop/UPower"), PropsIface, QStringLiteral("PropertiesChanged"), this,
                SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
    auto *w = new QDBusPendingCallWatcher(bus.asyncCall(QDBusMessage::createMethodCall(Service, QStringLiteral("/org/freedesktop/UPower"), Service, QStringLiteral("EnumerateDevices"))), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        QDBusPendingReply<QList<QDBusObjectPath>> reply = *w;
        w->deleteLater();
        if (reply.isError())
            return;
        for (const QDBusObjectPath &p : reply.value())
            add(p.path());
    });
    QDBusMessage msg = QDBusMessage::createMethodCall(Service, QStringLiteral("/org/freedesktop/UPower"), PropsIface, QStringLiteral("Get"));
    msg << Service << QStringLiteral("OnBattery");
    auto *b = new QDBusPendingCallWatcher(bus.asyncCall(msg), this);
    connect(b, &QDBusPendingCallWatcher::finished, this, [this, b] {
        QDBusPendingReply<QDBusVariant> reply = *b;
        b->deleteLater();
        if (!reply.isError() && reply.value().variant().toBool() != m_onBattery) {
            m_onBattery = !m_onBattery;
            emit onBatteryChanged();
        }
    });
}

UPower *UPower::create(QQmlEngine *, QJSEngine *)
{
    static UPower *self = new UPower();
    QJSEngine::setObjectOwnership(self, QJSEngine::CppOwnership);
    return self;
}

void UPower::add(const QString &path)
{
    if (m_byPath.contains(path))
        return;
    auto *d = new UPowerDevice(path, this);
    m_byPath.insert(path, d);
    m_devices->insert(d);
}

void UPower::added(const QDBusObjectPath &path)
{
    add(path.path());
}

void UPower::removed(const QDBusObjectPath &path)
{
    if (UPowerDevice *d = m_byPath.take(path.path())) {
        m_devices->remove(d);
        d->deleteLater();
    }
}

void UPower::propertiesChanged(const QString &iface, const QVariantMap &changedProps, const QStringList &)
{
    if (iface == Service && changedProps.contains(QStringLiteral("OnBattery"))) {
        m_onBattery = changedProps.value(QStringLiteral("OnBattery")).toBool();
        emit onBatteryChanged();
    }
}

}
