#pragma once

#include "model.h"

#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QSocketNotifier>
#include <QTimer>
#include <QVariantMap>

struct pw_proxy;

namespace stack {

class PwNode;

class PwNodeAudio : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("audio comes from PwNode")
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY changed)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY changed)
    Q_PROPERTY(QList<qreal> volumes READ volumes NOTIFY changed)

public:
    explicit PwNodeAudio(PwNode *node);

    qreal volume() const;
    void setVolume(qreal volume);
    bool muted() const { return m_muted; }
    void setMuted(bool muted);
    QList<qreal> volumes() const { return m_volumes; }
    void update(const QList<qreal> &volumes, bool muted);

signals:
    void changed();

private:
    PwNode *m_node;
    QList<qreal> m_volumes;
    bool m_muted = false;
};

class PwNode : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("nodes come from Pipewire")
    Q_PROPERTY(int id READ id CONSTANT)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString description READ description NOTIFY changed)
    Q_PROPERTY(QString nickname READ nickname NOTIFY changed)
    Q_PROPERTY(QString mediaClass READ mediaClass NOTIFY changed)
    Q_PROPERTY(bool isSink READ isSink NOTIFY changed)
    Q_PROPERTY(bool isStream READ isStream NOTIFY changed)
    Q_PROPERTY(QVariantMap properties READ properties NOTIFY changed)
    Q_PROPERTY(stack::PwNodeAudio *audio READ audio NOTIFY changed)

public:
    PwNode(quint32 id, QObject *parent);
    ~PwNode() override;

    int id() const { return static_cast<int>(m_id); }
    QString name() const { return m_props.value(QStringLiteral("node.name")).toString(); }
    QString description() const { return m_props.value(QStringLiteral("node.description")).toString(); }
    QString nickname() const { return m_props.value(QStringLiteral("node.nick")).toString(); }
    QString mediaClass() const { return m_props.value(QStringLiteral("media.class")).toString(); }
    bool isSink() const;
    bool isStream() const;
    QVariantMap properties() const { return m_props; }
    PwNodeAudio *audio() const { return m_audio; }

    void setProps(const QVariantMap &props);
    void bind(void *registry);
    void param(const void *pod);
    void sendVolumes(const QList<qreal> &volumes);
    void sendMute(bool muted);

    quint32 m_id;
    pw_proxy *m_proxy = nullptr;
    void *m_hook = nullptr;

signals:
    void changed();

private:
    void wpctl(const QStringList &args);

    QVariantMap m_props;
    PwNodeAudio *m_audio = nullptr;
    QStringList m_pendingArgs;
    bool m_running = false;
};

class PwLinkGroup : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("link groups come from Pipewire")
    Q_PROPERTY(stack::PwNode *source READ source CONSTANT)
    Q_PROPERTY(stack::PwNode *target READ target CONSTANT)

public:
    PwLinkGroup(PwNode *source, PwNode *target, QObject *parent)
        : QObject(parent)
        , m_source(source)
        , m_target(target)
    {
    }
    PwNode *source() const { return m_source; }
    PwNode *target() const { return m_target; }

private:
    QPointer<PwNode> m_source;
    QPointer<PwNode> m_target;
};

class PwObjectTracker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariant objects MEMBER m_objects NOTIFY objectsChanged)

public:
    using QObject::QObject;

signals:
    void objectsChanged();

private:
    QVariant m_objects;
};

class Pipewire : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(stack::ObjectModel *nodes READ nodes CONSTANT)
    Q_PROPERTY(stack::ObjectModel *linkGroups READ linkGroups CONSTANT)
    Q_PROPERTY(stack::PwNode *defaultAudioSink READ defaultAudioSink NOTIFY defaultsChanged)
    Q_PROPERTY(stack::PwNode *defaultAudioSource READ defaultAudioSource NOTIFY defaultsChanged)
    Q_PROPERTY(stack::PwNode *preferredDefaultAudioSink READ defaultAudioSink WRITE setPreferredDefaultAudioSink NOTIFY defaultsChanged)
    Q_PROPERTY(stack::PwNode *preferredDefaultAudioSource READ defaultAudioSource WRITE setPreferredDefaultAudioSource NOTIFY defaultsChanged)

public:
    static Pipewire *instance();
    static Pipewire *create(QQmlEngine *, QJSEngine *);

    bool ready() const { return m_ready; }
    ObjectModel *nodes() const { return m_nodes; }
    ObjectModel *linkGroups() const { return m_linkGroups; }
    PwNode *defaultAudioSink() const;
    PwNode *defaultAudioSource() const;
    void setPreferredDefaultAudioSink(PwNode *node);
    void setPreferredDefaultAudioSource(PwNode *node);

    void global(quint32 id, const char *type, const void *props);
    void globalRemove(quint32 id);
    void metadataProperty(const char *key, const char *value);
    void synced(int seq);
    void coreError(quint32 id, int res);

signals:
    void readyChanged();
    void defaultsChanged();

private:
    Pipewire();
    void connectCore();
    void disconnectCore();
    void scheduleLinks();
    void rebuildLinks();
    PwNode *byName(const QString &name) const;

    struct Core;
    Core *m_core = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    QTimer m_retry;
    QTimer m_linkTimer;
    bool m_ready = false;
    int m_syncSeq = -1;
    ObjectModel *m_nodes;
    ObjectModel *m_linkGroups;
    QHash<quint32, PwNode *> m_byId;
    QHash<quint32, QPair<quint32, quint32>> m_links;
    QString m_defaultSink;
    QString m_defaultSource;
};

}
