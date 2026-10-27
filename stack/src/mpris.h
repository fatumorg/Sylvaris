#pragma once

#include "model.h"

#include <QDBusServiceWatcher>
#include <QElapsedTimer>
#include <QObject>
#include <QQmlEngine>
#include <QVariantMap>

class QDBusMessage;

namespace stack {

namespace MprisLoopState {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, Track = 1, Playlist = 2 };
Q_ENUM_NS(Enum)
}

namespace MprisPlaybackState {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Stopped = 0, Playing = 1, Paused = 2 };
Q_ENUM_NS(Enum)
}

class MprisPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("players come from Mpris")
    Q_PROPERTY(QString dbusName READ dbusName CONSTANT)
    Q_PROPERTY(QString identity MEMBER m_identity NOTIFY changed)
    Q_PROPERTY(QString desktopEntry MEMBER m_desktopEntry NOTIFY changed)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY changed)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY changed)
    Q_PROPERTY(QString trackAlbum READ trackAlbum NOTIFY changed)
    Q_PROPERTY(QString trackArtUrl READ trackArtUrl NOTIFY changed)
    Q_PROPERTY(QVariantMap metadata MEMBER m_metadata NOTIFY changed)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY changed)
    Q_PROPERTY(int playbackState MEMBER m_state NOTIFY changed)
    Q_PROPERTY(qreal length READ length NOTIFY changed)
    Q_PROPERTY(bool lengthSupported READ lengthSupported NOTIFY changed)
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool positionSupported MEMBER m_positionSupported NOTIFY changed)
    Q_PROPERTY(bool canSeek MEMBER m_canSeek NOTIFY changed)
    Q_PROPERTY(bool canPlay MEMBER m_canPlay NOTIFY changed)
    Q_PROPERTY(bool canPause MEMBER m_canPause NOTIFY changed)
    Q_PROPERTY(bool canTogglePlaying READ canTogglePlaying NOTIFY changed)
    Q_PROPERTY(bool canGoNext MEMBER m_canNext NOTIFY changed)
    Q_PROPERTY(bool canGoPrevious MEMBER m_canPrevious NOTIFY changed)
    Q_PROPERTY(bool canRaise MEMBER m_canRaise NOTIFY changed)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY changed)
    Q_PROPERTY(bool shuffleSupported MEMBER m_shuffleSupported NOTIFY changed)
    Q_PROPERTY(int loopState READ loopState WRITE setLoopState NOTIFY changed)
    Q_PROPERTY(bool loopSupported MEMBER m_loopSupported NOTIFY changed)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY changed)
    Q_PROPERTY(bool volumeSupported MEMBER m_volumeSupported NOTIFY changed)

public:
    MprisPlayer(const QString &service, QObject *parent);

    QString dbusName() const { return m_service; }
    QString trackTitle() const;
    QString trackArtist() const;
    QString trackAlbum() const;
    QString trackArtUrl() const;
    bool isPlaying() const { return m_state == MprisPlaybackState::Playing; }
    qreal length() const;
    bool lengthSupported() const;
    qreal position() const;
    void setPosition(qreal seconds);
    bool canTogglePlaying() const { return m_canPlay || m_canPause; }
    bool shuffle() const { return m_shuffle; }
    void setShuffle(bool shuffle);
    int loopState() const { return m_loop; }
    void setLoopState(int state);
    qreal volume() const { return m_volume; }
    void setVolume(qreal volume);

    Q_INVOKABLE void togglePlaying();
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void raise();

signals:
    void changed();
    void positionChanged();

private slots:
    void propertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);
    void seeked(qlonglong position);

private:
    void apply(const QVariantMap &props);
    void call(const QString &method, const QVariantList &args = {});
    void set(const QString &property, const QVariant &value);
    void fetchPosition();
    void fetchAll();

    QString m_service;
    QString m_identity;
    QString m_desktopEntry;
    QVariantMap m_metadata;
    int m_state = MprisPlaybackState::Stopped;
    qint64 m_positionUs = 0;
    QElapsedTimer m_since;
    qreal m_rate = 1;
    bool m_positionSupported = false;
    bool m_canSeek = false;
    bool m_canPlay = false;
    bool m_canPause = false;
    bool m_canNext = false;
    bool m_canPrevious = false;
    bool m_canRaise = false;
    bool m_shuffle = false;
    bool m_shuffleSupported = false;
    int m_loop = MprisLoopState::None;
    bool m_loopSupported = false;
    qreal m_volume = 1;
    bool m_volumeSupported = false;
};

class Mpris : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::ObjectModel *players READ players CONSTANT)

public:
    static Mpris *create(QQmlEngine *, QJSEngine *);
    ObjectModel *players() const { return m_players; }

private:
    Mpris();
    void add(const QString &service);
    void remove(const QString &service);

    ObjectModel *m_players;
    QDBusServiceWatcher m_watcher;
    QHash<QString, MprisPlayer *> m_byName;
};

}
