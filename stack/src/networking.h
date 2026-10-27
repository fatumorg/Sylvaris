#pragma once

#include "model.h"

#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantMap>

namespace stack {

namespace NetworkBackendType {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, NetworkManager = 1 };
Q_ENUM_NS(Enum)
}

namespace DeviceType {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, Wired = 1, Wifi = 2, Other = 3 };
Q_ENUM_NS(Enum)
}

namespace ConnectionFailReason {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Unknown = 0, NoSecrets = 1, WifiClientDisconnected = 2, WifiClientFailed = 3, WifiAuthTimeout = 4, WifiNetworkLost = 5 };
Q_ENUM_NS(Enum)
}

class WifiSecurityType : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Enum { Unknown = 0, Open, StaticWep, WpaPsk, Wpa2Psk, Sae, WpaEap, Wpa2Eap, Owe };
    Q_ENUM(Enum)
    using QObject::QObject;
    Q_INVOKABLE static QString toString(int type);
};

class NetworkDevice;

class WifiNetwork : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("networks come from devices")
    Q_PROPERTY(QString name MEMBER m_name CONSTANT)
    Q_PROPERTY(qreal signalStrength MEMBER m_strength NOTIFY changed)
    Q_PROPERTY(int security MEMBER m_security NOTIFY changed)
    Q_PROPERTY(bool connected MEMBER m_connected NOTIFY changed)
    Q_PROPERTY(bool known MEMBER m_known NOTIFY changed)
    Q_PROPERTY(bool stateChanging MEMBER m_changing NOTIFY changed)

public:
    WifiNetwork(const QString &name, NetworkDevice *device);
    QString name() const { return m_name; }
    void update(qreal strength, int security, bool connected, bool known, bool changing, const QString &ap);
    QString accessPoint() const { return m_ap; }

    Q_INVOKABLE void connect();
    Q_INVOKABLE void connectWithPsk(const QString &psk);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void forget();

signals:
    void changed();
    void connectionFailed(int reason);

private:
    QString m_name;
    QString m_ap;
    NetworkDevice *m_device;
    qreal m_strength = 0;
    int m_security = WifiSecurityType::Unknown;
    bool m_connected = false;
    bool m_known = false;
    bool m_changing = false;
};

class NetworkDevice : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("devices come from Networking")
    Q_PROPERTY(int type MEMBER m_type CONSTANT)
    Q_PROPERTY(QString name MEMBER m_interface NOTIFY changed)
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(int state MEMBER m_state NOTIFY changed)
    Q_PROPERTY(bool scannerEnabled READ scannerEnabled WRITE setScannerEnabled NOTIFY scannerChanged)
    Q_PROPERTY(stack::ObjectModel *networks READ networks CONSTANT)

public:
    NetworkDevice(const QString &path, int type, QObject *parent);
    QString path() const { return m_path; }
    bool connected() const { return m_state == 100; }
    bool scannerEnabled() const { return m_scanning; }
    void setScannerEnabled(bool on);
    ObjectModel *networks() const { return m_networks; }

    void apply(const QVariantMap &props);
    void apApply(const QString &path, const QVariantMap &props);
    void apAdded(const QString &path);
    void apRemoved(const QString &path);
    void stateChanged(uint state, uint reason);
    void rebuild();
    void activate(WifiNetwork *network, const QString &psk, bool withPsk);
    void deactivate();
    void forget(const QString &ssid);

signals:
    void changed();
    void scannerChanged();

private:
    void fetch();
    void fetchAp(const QString &path);
    void scanNow();

    QString m_path;
    int m_type;
    QString m_interface;
    uint m_state = 0;
    QString m_activeAp;
    bool m_scanning = false;
    QTimer m_scanTimer;
    QTimer m_rebuild;
    QString m_activating;
    ObjectModel *m_networks;
    QHash<QString, QVariantMap> m_aps;
    QHash<QString, WifiNetwork *> m_bySsid;
};

class Networking : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(bool wifiHardwareEnabled MEMBER m_wifiHardware NOTIFY wifiEnabledChanged)
    Q_PROPERTY(stack::ObjectModel *devices READ devices CONSTANT)

public:
    static Networking *instance();
    static Networking *create(QQmlEngine *, QJSEngine *);

    int backend() const { return m_available ? NetworkBackendType::NetworkManager : NetworkBackendType::None; }
    bool wifiEnabled() const { return m_wifi; }
    void setWifiEnabled(bool on);
    ObjectModel *devices() const { return m_devices; }
    QStringList knownSsids() const { return m_known; }
    QHash<QString, QStringList> knownPaths() const { return m_knownPaths; }
    void refreshKnown();

signals:
    void backendChanged();
    void wifiEnabledChanged();
    void knownChanged();

private slots:
    void propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated, const QDBusMessage &msg);
    void deviceAdded(const QDBusObjectPath &path);
    void deviceRemoved(const QDBusObjectPath &path);
    void apAdded(const QDBusObjectPath &path, const QDBusMessage &msg);
    void apRemoved(const QDBusObjectPath &path, const QDBusMessage &msg);
    void deviceState(uint state, uint old, uint reason, const QDBusMessage &msg);
    void settingsChanged();

private:
    Networking();
    void start();
    void addDevice(const QString &path);

    bool m_available = false;
    bool m_wifi = false;
    bool m_wifiHardware = true;
    ObjectModel *m_devices;
    QHash<QString, NetworkDevice *> m_byPath;
    QStringList m_known;
    QHash<QString, QStringList> m_knownPaths;
};

}
