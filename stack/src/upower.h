#pragma once

#include "model.h"

#include <QObject>
#include <QQmlEngine>
#include <QDBusObjectPath>
#include <QVariantMap>

namespace stack {

class UPowerDeviceType : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Enum {
        Unknown = 0, LinePower, Battery, Ups, Monitor, Mouse, Keyboard, Pda, Phone, MediaPlayer, Tablet, Computer, GamingInput, Pen, Touchpad,
        Modem, Network, Headset, Speakers, Headphones, Video, OtherAudio, RemoteControl, Printer, Scanner, Camera, Wearable, Toy, BluetoothGeneric
    };
    Q_ENUM(Enum)
    using QObject::QObject;
    Q_INVOKABLE static QString toString(int type);
};

class UPowerDeviceState : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Enum { Unknown = 0, Charging, Discharging, Empty, FullyCharged, PendingCharge, PendingDischarge };
    Q_ENUM(Enum)
    using QObject::QObject;
    Q_INVOKABLE static QString toString(int state);
};

class UPowerDevice : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("devices come from UPower")
    Q_PROPERTY(bool ready MEMBER m_ready NOTIFY changed)
    Q_PROPERTY(int type MEMBER m_type NOTIFY changed)
    Q_PROPERTY(int state MEMBER m_state NOTIFY changed)
    Q_PROPERTY(qreal percentage MEMBER m_percentage NOTIFY changed)
    Q_PROPERTY(bool isPresent MEMBER m_present NOTIFY changed)
    Q_PROPERTY(bool powerSupply MEMBER m_powerSupply NOTIFY changed)
    Q_PROPERTY(bool isLaptopBattery READ isLaptopBattery NOTIFY changed)
    Q_PROPERTY(QString model MEMBER m_model NOTIFY changed)
    Q_PROPERTY(QString nativePath MEMBER m_nativePath NOTIFY changed)
    Q_PROPERTY(qreal timeToEmpty MEMBER m_toEmpty NOTIFY changed)
    Q_PROPERTY(qreal timeToFull MEMBER m_toFull NOTIFY changed)
    Q_PROPERTY(QString iconName MEMBER m_icon NOTIFY changed)

public:
    UPowerDevice(const QString &path, QObject *parent);
    QString path() const { return m_path; }
    bool isLaptopBattery() const { return m_type == UPowerDeviceType::Battery && m_powerSupply; }

signals:
    void changed();

private slots:
    void propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void fetch();
    void apply(const QVariantMap &props);

    QString m_path;
    bool m_ready = false;
    int m_type = 0;
    int m_state = 0;
    qreal m_percentage = 0;
    bool m_present = false;
    bool m_powerSupply = false;
    QString m_model;
    QString m_nativePath;
    qreal m_toEmpty = 0;
    qreal m_toFull = 0;
    QString m_icon;
};

class UPower : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::UPowerDevice *displayDevice READ displayDevice CONSTANT)
    Q_PROPERTY(stack::ObjectModel *devices READ devices CONSTANT)
    Q_PROPERTY(bool onBattery MEMBER m_onBattery NOTIFY onBatteryChanged)

public:
    static UPower *create(QQmlEngine *, QJSEngine *);
    UPowerDevice *displayDevice() const { return m_display; }
    ObjectModel *devices() const { return m_devices; }

signals:
    void onBatteryChanged();

private slots:
    void added(const QDBusObjectPath &path);
    void removed(const QDBusObjectPath &path);
    void propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);

private:
    UPower();
    void add(const QString &path);

    UPowerDevice *m_display = nullptr;
    ObjectModel *m_devices;
    QHash<QString, UPowerDevice *> m_byPath;
    bool m_onBattery = false;
};

}
