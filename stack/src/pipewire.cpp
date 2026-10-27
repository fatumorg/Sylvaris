#include "pipewire.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

#include <cmath>
#include <pipewire/extensions/metadata.h>
#include <pipewire/pipewire.h>
#include <spa/param/props.h>
#include <spa/pod/builder.h>
#include <spa/pod/iter.h>

namespace stack {

struct Pipewire::Core {
    pw_loop *loop = nullptr;
    pw_context *context = nullptr;
    pw_core *core = nullptr;
    pw_registry *registry = nullptr;
    pw_metadata *metadata = nullptr;
    spa_hook coreHook {};
    spa_hook registryHook {};
    spa_hook metadataHook {};
};

namespace {

QVariantMap toMap(const spa_dict *dict)
{
    QVariantMap out;
    if (!dict)
        return out;
    const spa_dict_item *item;
    spa_dict_for_each(item, dict)
    {
        if (item->key && item->value)
            out.insert(QString::fromUtf8(item->key), QString::fromUtf8(item->value));
    }
    return out;
}

void onGlobal(void *, uint32_t id, uint32_t, const char *type, uint32_t, const spa_dict *props)
{
    Pipewire::instance()->global(id, type, props);
}

void onGlobalRemove(void *, uint32_t id)
{
    Pipewire::instance()->globalRemove(id);
}

const pw_registry_events registryEvents = {
    .version = PW_VERSION_REGISTRY_EVENTS,
    .global = onGlobal,
    .global_remove = onGlobalRemove,
};

void onCoreDone(void *, uint32_t id, int seq)
{
    if (id == PW_ID_CORE)
        Pipewire::instance()->synced(seq);
}

void onCoreError(void *, uint32_t id, int, int res, const char *)
{
    Pipewire::instance()->coreError(id, res);
}

const pw_core_events coreEvents = {
    .version = PW_VERSION_CORE_EVENTS,
    .done = onCoreDone,
    .error = onCoreError,
};

int onMetadata(void *, uint32_t subject, const char *key, const char *, const char *value)
{
    if (subject == PW_ID_CORE && key)
        Pipewire::instance()->metadataProperty(key, value);
    return 0;
}

const pw_metadata_events metadataEvents = {
    .version = PW_VERSION_METADATA_EVENTS,
    .property = onMetadata,
};

void onNodeInfo(void *data, const pw_node_info *info)
{
    auto *node = static_cast<PwNode *>(data);
    if (info && (info->change_mask & PW_NODE_CHANGE_MASK_PROPS))
        node->setProps(toMap(info->props));
}

void onNodeParam(void *data, int, uint32_t id, uint32_t, uint32_t, const spa_pod *param)
{
    if (id == SPA_PARAM_Props && param)
        static_cast<PwNode *>(data)->param(param);
}

const pw_node_events nodeEvents = {
    .version = PW_VERSION_NODE_EVENTS,
    .info = onNodeInfo,
    .param = onNodeParam,
};

QString nameFromJson(const char *value)
{
    if (!value)
        return {};
    return QJsonDocument::fromJson(QByteArray(value)).object().value(QStringLiteral("name")).toString();
}

bool haveWpctl()
{
    static const bool have = !QStandardPaths::findExecutable(QStringLiteral("wpctl")).isEmpty();
    return have;
}

}

PwNodeAudio::PwNodeAudio(PwNode *node)
    : QObject(node)
    , m_node(node)
{
}

qreal PwNodeAudio::volume() const
{
    if (m_volumes.isEmpty())
        return 0;
    qreal sum = 0;
    for (qreal v : m_volumes)
        sum += v;
    return sum / m_volumes.size();
}

void PwNodeAudio::setVolume(qreal volume)
{
    const qreal v = std::clamp<qreal>(volume, 0, 1.5);
    QList<qreal> next(std::max<qsizetype>(1, m_volumes.size()), v);
    if (next == m_volumes)
        return;
    m_volumes = next;
    m_node->sendVolumes(next);
    emit changed();
}

void PwNodeAudio::setMuted(bool muted)
{
    if (muted == m_muted)
        return;
    m_muted = muted;
    m_node->sendMute(muted);
    emit changed();
}

void PwNodeAudio::update(const QList<qreal> &volumes, bool muted)
{
    if (volumes == m_volumes && muted == m_muted)
        return;
    m_volumes = volumes;
    m_muted = muted;
    emit changed();
}

PwNode::PwNode(quint32 id, QObject *parent)
    : QObject(parent)
    , m_id(id)
{
}

PwNode::~PwNode()
{
    if (m_hook) {
        auto *hook = static_cast<spa_hook *>(m_hook);
        if (m_proxy)
            spa_hook_remove(hook);
        delete hook;
    }
    if (m_proxy)
        pw_proxy_destroy(m_proxy);
}

bool PwNode::isSink() const
{
    const QString mc = mediaClass();
    return mc == QStringLiteral("Audio/Sink") || mc == QStringLiteral("Audio/Duplex") || mc.startsWith(QStringLiteral("Stream/Output/"));
}

bool PwNode::isStream() const
{
    return mediaClass().startsWith(QStringLiteral("Stream/"));
}

void PwNode::setProps(const QVariantMap &props)
{
    QVariantMap next = m_props;
    for (auto it = props.cbegin(); it != props.cend(); ++it)
        next.insert(it.key(), it.value());
    if (next == m_props)
        return;
    m_props = next;
    emit changed();
}

void PwNode::bind(void *registry)
{
    if (m_proxy || !mediaClass().contains(QStringLiteral("Audio")))
        return;
    m_audio = new PwNodeAudio(this);
    auto *node = static_cast<pw_node *>(pw_registry_bind(static_cast<pw_registry *>(registry), m_id, PW_TYPE_INTERFACE_Node, PW_VERSION_NODE, 0));
    if (!node)
        return;
    m_proxy = reinterpret_cast<pw_proxy *>(node);
    auto *hook = new spa_hook {};
    m_hook = hook;
    pw_node_add_listener(node, hook, &nodeEvents, this);
    uint32_t ids[] = {SPA_PARAM_Props};
    pw_node_subscribe_params(node, ids, 1);
    emit changed();
}

void PwNode::param(const void *data)
{
    const auto *pod = static_cast<const spa_pod *>(data);
    if (!m_audio || !spa_pod_is_object_type(pod, SPA_TYPE_OBJECT_Props))
        return;
    const spa_pod_prop *vols = spa_pod_find_prop(pod, nullptr, SPA_PROP_channelVolumes);
    const spa_pod_prop *mute = spa_pod_find_prop(pod, nullptr, SPA_PROP_mute);
    if (!vols && !mute)
        return;
    QList<qreal> volumes = m_audio->volumes();
    bool muted = m_audio->muted();
    if (vols) {
        float buf[64];
        const uint32_t n = spa_pod_copy_array(&vols->value, SPA_TYPE_Float, buf, 64);
        if (n > 0) {
            volumes.clear();
            for (uint32_t i = 0; i < n; i++)
                volumes << std::cbrt(std::max(0.0f, buf[i]));
        }
    }
    if (mute)
        spa_pod_get_bool(&mute->value, &muted);
    m_audio->update(volumes, muted);
}

void PwNode::wpctl(const QStringList &args)
{
    if (m_running) {
        m_pendingArgs = args;
        return;
    }
    m_running = true;
    auto *p = new QProcess(this);
    p->setStandardInputFile(QProcess::nullDevice());
    p->setStandardOutputFile(QProcess::nullDevice());
    p->setStandardErrorFile(QProcess::nullDevice());
    connect(p, &QProcess::finished, this, [this, p] {
        p->deleteLater();
        m_running = false;
        if (!m_pendingArgs.isEmpty()) {
            const QStringList next = m_pendingArgs;
            m_pendingArgs.clear();
            wpctl(next);
        }
    });
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            p->deleteLater();
            m_running = false;
        }
    });
    p->start(QStringLiteral("wpctl"), args);
}

void PwNode::sendVolumes(const QList<qreal> &volumes)
{
    if (haveWpctl()) {
        qreal sum = 0;
        for (qreal v : volumes)
            sum += v;
        const qreal avg = volumes.isEmpty() ? 0 : sum / volumes.size();
        wpctl({QStringLiteral("set-volume"), QString::number(m_id), QString::number(avg, 'f', 4)});
        return;
    }
    if (!m_proxy)
        return;
    float cubes[64];
    const int n = std::min<int>(64, static_cast<int>(volumes.size()));
    for (int i = 0; i < n; i++)
        cubes[i] = static_cast<float>(volumes[i] * volumes[i] * volumes[i]);
    uint8_t buffer[1024];
    spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    auto *pod = static_cast<spa_pod *>(spa_pod_builder_add_object(&b, SPA_TYPE_OBJECT_Props, SPA_PARAM_Props, SPA_PROP_channelVolumes,
                                                                  SPA_POD_Array(sizeof(float), SPA_TYPE_Float, n, cubes)));
    pw_node_set_param(reinterpret_cast<pw_node *>(m_proxy), SPA_PARAM_Props, 0, pod);
}

void PwNode::sendMute(bool muted)
{
    if (haveWpctl()) {
        wpctl({QStringLiteral("set-mute"), QString::number(m_id), muted ? QStringLiteral("1") : QStringLiteral("0")});
        return;
    }
    if (!m_proxy)
        return;
    uint8_t buffer[256];
    spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    auto *pod = static_cast<spa_pod *>(spa_pod_builder_add_object(&b, SPA_TYPE_OBJECT_Props, SPA_PARAM_Props, SPA_PROP_mute, SPA_POD_Bool(muted)));
    pw_node_set_param(reinterpret_cast<pw_node *>(m_proxy), SPA_PARAM_Props, 0, pod);
}

Pipewire::Pipewire()
    : m_nodes(new ObjectModel(this))
    , m_linkGroups(new ObjectModel(this))
{
    pw_init(nullptr, nullptr);
    m_retry.setSingleShot(true);
    m_retry.setInterval(2000);
    connect(&m_retry, &QTimer::timeout, this, &Pipewire::connectCore);
    m_linkTimer.setSingleShot(true);
    m_linkTimer.setInterval(0);
    connect(&m_linkTimer, &QTimer::timeout, this, &Pipewire::rebuildLinks);
    connectCore();
}

Pipewire *Pipewire::instance()
{
    static Pipewire *self = new Pipewire();
    return self;
}

Pipewire *Pipewire::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

void Pipewire::connectCore()
{
    if (m_core)
        return;
    auto *c = new Core();
    c->loop = pw_loop_new(nullptr);
    if (!c->loop) {
        delete c;
        m_retry.start();
        return;
    }
    c->context = pw_context_new(c->loop, nullptr, 0);
    c->core = c->context ? pw_context_connect(c->context, nullptr, 0) : nullptr;
    if (!c->core) {
        if (c->context)
            pw_context_destroy(c->context);
        pw_loop_destroy(c->loop);
        delete c;
        m_retry.start();
        return;
    }
    m_core = c;
    pw_loop_enter(c->loop);
    pw_core_add_listener(c->core, &c->coreHook, &coreEvents, this);
    c->registry = pw_core_get_registry(c->core, PW_VERSION_REGISTRY, 0);
    pw_registry_add_listener(c->registry, &c->registryHook, &registryEvents, this);
    m_syncSeq = pw_core_sync(c->core, PW_ID_CORE, 0);
    m_notifier = new QSocketNotifier(pw_loop_get_fd(c->loop), QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, [this] {
        if (m_core)
            pw_loop_iterate(m_core->loop, 0);
    });
    pw_loop_iterate(c->loop, 0);
}

void Pipewire::disconnectCore()
{
    if (!m_core)
        return;
    Core *c = m_core;
    m_core = nullptr;
    delete m_notifier;
    m_notifier = nullptr;
    const auto nodes = m_byId;
    m_byId.clear();
    m_links.clear();
    m_nodes->replace({});
    rebuildLinks();
    for (PwNode *n : nodes)
        delete n;
    if (c->metadata) {
        spa_hook_remove(&c->metadataHook);
        pw_proxy_destroy(reinterpret_cast<pw_proxy *>(c->metadata));
    }
    spa_hook_remove(&c->registryHook);
    pw_proxy_destroy(reinterpret_cast<pw_proxy *>(c->registry));
    spa_hook_remove(&c->coreHook);
    pw_core_disconnect(c->core);
    pw_context_destroy(c->context);
    pw_loop_leave(c->loop);
    pw_loop_destroy(c->loop);
    delete c;
    if (m_ready) {
        m_ready = false;
        emit readyChanged();
    }
    emit defaultsChanged();
}

void Pipewire::global(quint32 id, const char *type, const void *propsData)
{
    if (!m_core || !type)
        return;
    const auto *props = static_cast<const spa_dict *>(propsData);
    if (std::strcmp(type, PW_TYPE_INTERFACE_Node) == 0) {
        auto *node = new PwNode(id, this);
        node->setProps(toMap(props));
        node->bind(m_core->registry);
        m_byId.insert(id, node);
        m_nodes->insert(node);
        scheduleLinks();
        emit defaultsChanged();
    } else if (std::strcmp(type, PW_TYPE_INTERFACE_Link) == 0) {
        const char *out = spa_dict_lookup(props, PW_KEY_LINK_OUTPUT_NODE);
        const char *in = spa_dict_lookup(props, PW_KEY_LINK_INPUT_NODE);
        if (out && in) {
            m_links.insert(id, {static_cast<quint32>(std::strtoul(out, nullptr, 10)), static_cast<quint32>(std::strtoul(in, nullptr, 10))});
            scheduleLinks();
        }
    } else if (std::strcmp(type, PW_TYPE_INTERFACE_Metadata) == 0 && !m_core->metadata) {
        const char *name = spa_dict_lookup(props, PW_KEY_METADATA_NAME);
        if (name && std::strcmp(name, "default") == 0) {
            m_core->metadata = static_cast<pw_metadata *>(pw_registry_bind(m_core->registry, id, PW_TYPE_INTERFACE_Metadata, PW_VERSION_METADATA, 0));
            if (m_core->metadata)
                pw_metadata_add_listener(m_core->metadata, &m_core->metadataHook, &metadataEvents, this);
        }
    }
}

void Pipewire::globalRemove(quint32 id)
{
    if (PwNode *node = m_byId.take(id)) {
        m_nodes->remove(node);
        scheduleLinks();
        emit defaultsChanged();
        node->deleteLater();
    } else if (m_links.remove(id)) {
        scheduleLinks();
    }
}

void Pipewire::metadataProperty(const char *key, const char *value)
{
    if (std::strcmp(key, "default.audio.sink") == 0)
        m_defaultSink = nameFromJson(value);
    else if (std::strcmp(key, "default.audio.source") == 0)
        m_defaultSource = nameFromJson(value);
    else
        return;
    emit defaultsChanged();
}

void Pipewire::synced(int seq)
{
    if (seq == m_syncSeq && !m_ready) {
        m_ready = true;
        emit readyChanged();
    }
}

void Pipewire::coreError(quint32 id, int res)
{
    if (id == PW_ID_CORE && res == -EPIPE) {
        QMetaObject::invokeMethod(this, [this] {
            disconnectCore();
            m_retry.start();
        }, Qt::QueuedConnection);
    }
}

PwNode *Pipewire::byName(const QString &name) const
{
    if (name.isEmpty())
        return nullptr;
    for (PwNode *n : m_byId) {
        if (n->name() == name)
            return n;
    }
    return nullptr;
}

PwNode *Pipewire::defaultAudioSink() const
{
    return byName(m_defaultSink);
}

PwNode *Pipewire::defaultAudioSource() const
{
    return byName(m_defaultSource);
}

void Pipewire::setPreferredDefaultAudioSink(PwNode *node)
{
    if (!node || !m_core || !m_core->metadata)
        return;
    const QByteArray json = QJsonDocument(QJsonObject {{QStringLiteral("name"), node->name()}}).toJson(QJsonDocument::Compact);
    pw_metadata_set_property(m_core->metadata, PW_ID_CORE, "default.configured.audio.sink", "Spa:String:JSON", json.constData());
}

void Pipewire::setPreferredDefaultAudioSource(PwNode *node)
{
    if (!node || !m_core || !m_core->metadata)
        return;
    const QByteArray json = QJsonDocument(QJsonObject {{QStringLiteral("name"), node->name()}}).toJson(QJsonDocument::Compact);
    pw_metadata_set_property(m_core->metadata, PW_ID_CORE, "default.configured.audio.source", "Spa:String:JSON", json.constData());
}

void Pipewire::scheduleLinks()
{
    m_linkTimer.start();
}

void Pipewire::rebuildLinks()
{
    QSet<QPair<quint32, quint32>> pairs;
    for (const auto &p : std::as_const(m_links))
        pairs.insert(p);
    QList<QObject *> next;
    QList<QObject *> keep;
    for (QObject *o : m_linkGroups->values()) {
        auto *g = static_cast<PwLinkGroup *>(o);
        const QPair<quint32, quint32> key {g->source() ? g->source()->m_id : 0, g->target() ? g->target()->m_id : 0};
        if (g->source() && g->target() && pairs.remove(key))
            keep << g;
    }
    next = keep;
    for (const auto &p : pairs) {
        PwNode *source = m_byId.value(p.first);
        PwNode *target = m_byId.value(p.second);
        if (source && target)
            next << new PwLinkGroup(source, target, this);
    }
    const QList<QObject *> old = m_linkGroups->values();
    m_linkGroups->replace(next);
    for (QObject *o : old) {
        if (!next.contains(o))
            o->deleteLater();
    }
}

}
