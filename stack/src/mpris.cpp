#include "mpris.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

namespace stack {

namespace {

const QString Path = QStringLiteral("/org/mpris/MediaPlayer2");
const QString Root = QStringLiteral("org.mpris.MediaPlayer2");
const QString PlayerIface = QStringLiteral("org.mpris.MediaPlayer2.Player");
const QString PropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

QVariant plain(const QVariant &v)
{
    if (v.userType() == qMetaTypeId<QDBusVariant>())
        return plain(v.value<QDBusVariant>().variant());
    if (v.userType() == qMetaTypeId<QDBusObjectPath>())
        return v.value<QDBusObjectPath>().path();
    if (v.userType() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument arg = v.value<QDBusArgument>();
        if (arg.currentType() == QDBusArgument::ArrayType && arg.currentSignature() == QStringLiteral("as"))
            return qdbus_cast<QStringList>(arg);
        if (arg.currentType() == QDBusArgument::MapType) {
            QVariantMap out;
            const QVariantMap raw = qdbus_cast<QVariantMap>(arg);
            for (auto it = raw.cbegin(); it != raw.cend(); ++it)
                out.insert(it.key(), plain(it.value()));
            return out;
        }
        return {};
    }
    return v;
}

QVariantMap plainMap(const QVariantMap &in)
{
    QVariantMap out;
    for (auto it = in.cbegin(); it != in.cend(); ++it)
        out.insert(it.key(), plain(it.value()));
    return out;
}

}

MprisPlayer::MprisPlayer(const QString &service, QObject *parent)
    : QObject(parent)
    , m_service(service)
{
    m_since.start();
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(service, Path, PropsIface, QStringLiteral("PropertiesChanged"), this, SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
    bus.connect(service, Path, PlayerIface, QStringLiteral("Seeked"), this, SLOT(seeked(qlonglong)));
    fetchAll();
}

void MprisPlayer::fetchAll()
{
    for (const QString &iface : {Root, PlayerIface}) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_service, Path, PropsIface, QStringLiteral("GetAll"));
        msg << iface;
        auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
            QDBusPendingReply<QVariantMap> reply = *w;
            w->deleteLater();
            if (!reply.isError())
                apply(plainMap(reply.value()));
        });
    }
}

void MprisPlayer::apply(const QVariantMap &props)
{
    bool fetch = false;
    for (auto it = props.cbegin(); it != props.cend(); ++it) {
        const QString &k = it.key();
        const QVariant &v = it.value();
        if (k == QStringLiteral("Identity"))
            m_identity = v.toString();
        else if (k == QStringLiteral("DesktopEntry"))
            m_desktopEntry = v.toString();
        else if (k == QStringLiteral("CanRaise"))
            m_canRaise = v.toBool();
        else if (k == QStringLiteral("Metadata")) {
            m_metadata = v.toMap();
            fetch = true;
        } else if (k == QStringLiteral("PlaybackStatus")) {
            const QString s = v.toString();
            m_state = s == QStringLiteral("Playing") ? MprisPlaybackState::Playing : s == QStringLiteral("Paused") ? MprisPlaybackState::Paused : MprisPlaybackState::Stopped;
            fetch = true;
        } else if (k == QStringLiteral("Position")) {
            m_positionUs = v.toLongLong();
            m_positionSupported = true;
            m_since.restart();
        } else if (k == QStringLiteral("Rate"))
            m_rate = v.toDouble();
        else if (k == QStringLiteral("CanSeek"))
            m_canSeek = v.toBool();
        else if (k == QStringLiteral("CanPlay"))
            m_canPlay = v.toBool();
        else if (k == QStringLiteral("CanPause"))
            m_canPause = v.toBool();
        else if (k == QStringLiteral("CanGoNext"))
            m_canNext = v.toBool();
        else if (k == QStringLiteral("CanGoPrevious"))
            m_canPrevious = v.toBool();
        else if (k == QStringLiteral("Shuffle")) {
            m_shuffle = v.toBool();
            m_shuffleSupported = true;
        } else if (k == QStringLiteral("LoopStatus")) {
            const QString s = v.toString();
            m_loop = s == QStringLiteral("Track") ? MprisLoopState::Track : s == QStringLiteral("Playlist") ? MprisLoopState::Playlist : MprisLoopState::None;
            m_loopSupported = true;
        } else if (k == QStringLiteral("Volume")) {
            m_volume = v.toDouble();
            m_volumeSupported = true;
        }
    }
    emit changed();
    emit positionChanged();
    if (fetch)
        fetchPosition();
}

void MprisPlayer::propertiesChanged(const QString &iface, const QVariantMap &changedProps, const QStringList &invalidated)
{
    if (iface != Root && iface != PlayerIface)
        return;
    apply(plainMap(changedProps));
    if (!invalidated.isEmpty())
        fetchAll();
}

void MprisPlayer::seeked(qlonglong position)
{
    m_positionUs = position;
    m_since.restart();
    emit positionChanged();
}

void MprisPlayer::fetchPosition()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, Path, PropsIface, QStringLiteral("Get"));
    msg << PlayerIface << QStringLiteral("Position");
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, w] {
        QDBusPendingReply<QDBusVariant> reply = *w;
        w->deleteLater();
        if (reply.isError())
            return;
        m_positionUs = plain(reply.value().variant()).toLongLong();
        m_positionSupported = true;
        m_since.restart();
        emit changed();
        emit positionChanged();
    });
}

QString MprisPlayer::trackTitle() const
{
    return m_metadata.value(QStringLiteral("xesam:title")).toString();
}

QString MprisPlayer::trackArtist() const
{
    const QVariant v = m_metadata.value(QStringLiteral("xesam:artist"));
    return v.typeId() == QMetaType::QStringList ? v.toStringList().join(QStringLiteral(", ")) : v.toString();
}

QString MprisPlayer::trackAlbum() const
{
    return m_metadata.value(QStringLiteral("xesam:album")).toString();
}

QString MprisPlayer::trackArtUrl() const
{
    const QString url = m_metadata.value(QStringLiteral("mpris:artUrl")).toString();
    if (url.startsWith(QStringLiteral("file://")) || url.startsWith(QStringLiteral("https://")) || url.startsWith(QStringLiteral("http://")) || url.startsWith(QStringLiteral("data:")))
        return url;
    return {};
}

qreal MprisPlayer::length() const
{
    return m_metadata.value(QStringLiteral("mpris:length")).toLongLong() / 1e6;
}

bool MprisPlayer::lengthSupported() const
{
    return m_metadata.contains(QStringLiteral("mpris:length")) && length() > 0;
}

qreal MprisPlayer::position() const
{
    qint64 us = m_positionUs;
    if (m_state == MprisPlaybackState::Playing)
        us += static_cast<qint64>(m_since.elapsed() * 1000 * m_rate);
    qreal s = us / 1e6;
    if (lengthSupported())
        s = std::min(s, length());
    return std::max<qreal>(0, s);
}

void MprisPlayer::setPosition(qreal seconds)
{
    if (!m_canSeek)
        return;
    const qint64 target = static_cast<qint64>(std::max<qreal>(0, seconds) * 1e6);
    const QString track = m_metadata.value(QStringLiteral("mpris:trackid")).toString();
    if (!track.isEmpty())
        call(QStringLiteral("SetPosition"), {QVariant::fromValue(QDBusObjectPath(track)), target});
    else
        call(QStringLiteral("Seek"), {target - static_cast<qint64>(position() * 1e6)});
    m_positionUs = target;
    m_since.restart();
    emit positionChanged();
}

void MprisPlayer::setShuffle(bool shuffle)
{
    set(QStringLiteral("Shuffle"), shuffle);
}

void MprisPlayer::setLoopState(int state)
{
    set(QStringLiteral("LoopStatus"), state == MprisLoopState::Track ? QStringLiteral("Track") : state == MprisLoopState::Playlist ? QStringLiteral("Playlist") : QStringLiteral("None"));
}

void MprisPlayer::setVolume(qreal volume)
{
    set(QStringLiteral("Volume"), std::clamp<qreal>(volume, 0, 1));
}

void MprisPlayer::call(const QString &method, const QVariantList &args)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, Path, method == QStringLiteral("Raise") ? Root : PlayerIface, method);
    msg.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(msg);
}

void MprisPlayer::set(const QString &property, const QVariant &value)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, Path, PropsIface, QStringLiteral("Set"));
    msg << PlayerIface << property << QVariant::fromValue(QDBusVariant(value));
    QDBusConnection::sessionBus().asyncCall(msg);
}

void MprisPlayer::togglePlaying() { call(QStringLiteral("PlayPause")); }
void MprisPlayer::play() { call(QStringLiteral("Play")); }
void MprisPlayer::pause() { call(QStringLiteral("Pause")); }
void MprisPlayer::stop() { call(QStringLiteral("Stop")); }
void MprisPlayer::next() { call(QStringLiteral("Next")); }
void MprisPlayer::previous() { call(QStringLiteral("Previous")); }
void MprisPlayer::raise() { call(QStringLiteral("Raise")); }

Mpris::Mpris()
    : m_players(new ObjectModel(this))
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return;
    m_watcher.setConnection(bus);
    m_watcher.setWatchMode(QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration);
    m_watcher.addWatchedService(QStringLiteral("org.mpris.MediaPlayer2.*"));
    connect(&m_watcher, &QDBusServiceWatcher::serviceRegistered, this, &Mpris::add);
    connect(&m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &Mpris::remove);
    const QStringList names = bus.interface()->registeredServiceNames().value();
    for (const QString &name : names) {
        if (name.startsWith(QStringLiteral("org.mpris.MediaPlayer2.")))
            add(name);
    }
}

Mpris *Mpris::create(QQmlEngine *, QJSEngine *)
{
    static Mpris *self = new Mpris();
    QJSEngine::setObjectOwnership(self, QJSEngine::CppOwnership);
    return self;
}

void Mpris::add(const QString &service)
{
    if (m_byName.contains(service))
        return;
    auto *p = new MprisPlayer(service, this);
    m_byName.insert(service, p);
    m_players->insert(p);
}

void Mpris::remove(const QString &service)
{
    if (MprisPlayer *p = m_byName.take(service)) {
        m_players->remove(p);
        p->deleteLater();
    }
}

}
