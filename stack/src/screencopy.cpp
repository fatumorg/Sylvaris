#include "screencopy.h"

#include "toplevel.h"

#include <QQuickWindow>
#include <QSGImageNode>
#include <QSGTexture>
#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandintegration_p.h>
#include <QtWaylandClient/private/qwaylandshm_p.h>

#include <sys/mman.h>
#include <unistd.h>

#include "qwayland-hyprland-toplevel-export-v1.h"

namespace stack {

namespace {

constexpr int LiveInterval = 250;

class ExportManager : public QWaylandClientExtensionTemplate<ExportManager>, public QtWayland::hyprland_toplevel_export_manager_v1
{
public:
    ExportManager()
        : QWaylandClientExtensionTemplate<ExportManager>(2)
    {
        initialize();
    }
};

ExportManager *manager()
{
    static ExportManager *m = new ExportManager();
    return m->isActive() && m->QWaylandClientExtension::version() >= 2 ? m : nullptr;
}

::wl_shm *shm()
{
    auto *integration = QtWaylandClient::QWaylandIntegration::instance();
    if (!integration || !integration->display() || !integration->display()->shm())
        return nullptr;
    return integration->display()->shm()->object();
}

}

class ExportFrame : public QtWayland::hyprland_toplevel_export_frame_v1
{
public:
    ExportFrame(struct ::hyprland_toplevel_export_frame_v1 *frame, ScreencopyView *view)
        : QtWayland::hyprland_toplevel_export_frame_v1(frame)
        , m_view(view)
    {
    }

    ~ExportFrame() override
    {
        if (m_buffer)
            wl_buffer_destroy(m_buffer);
        if (m_data)
            munmap(m_data, m_size);
        if (object())
            destroy();
    }

    ScreencopyView *m_view;

protected:
    void hyprland_toplevel_export_frame_v1_buffer(uint32_t format, uint32_t width, uint32_t height, uint32_t stride) override
    {
        if (m_format >= 0)
            return;
        if (format != WL_SHM_FORMAT_ARGB8888 && format != WL_SHM_FORMAT_XRGB8888)
            return;
        if (width == 0 || height == 0 || width > 16384 || height > 16384 || stride < width * 4 || stride > width * 4 + 256)
            return;
        m_format = static_cast<int>(format);
        m_width = static_cast<int>(width);
        m_height = static_cast<int>(height);
        m_stride = static_cast<int>(stride);
    }

    void hyprland_toplevel_export_frame_v1_buffer_done() override
    {
        ::wl_shm *s = shm();
        if (m_format < 0 || !s) {
            m_view->frameFailed();
            return;
        }
        m_size = static_cast<size_t>(m_stride) * static_cast<size_t>(m_height);
        const int fd = memfd_create("sylstack-shot", MFD_CLOEXEC | MFD_ALLOW_SEALING);
        if (fd < 0 || ftruncate(fd, static_cast<off_t>(m_size)) != 0) {
            if (fd >= 0)
                close(fd);
            m_view->frameFailed();
            return;
        }
        void *data = mmap(nullptr, m_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (data == MAP_FAILED) {
            close(fd);
            m_view->frameFailed();
            return;
        }
        m_data = data;
        wl_shm_pool *pool = wl_shm_create_pool(s, fd, static_cast<int32_t>(m_size));
        m_buffer = wl_shm_pool_create_buffer(pool, 0, m_width, m_height, m_stride, static_cast<uint32_t>(m_format));
        wl_shm_pool_destroy(pool);
        close(fd);
        copy(m_buffer, 1);
    }

    void hyprland_toplevel_export_frame_v1_flags(uint32_t flags) override
    {
        m_invert = flags & flags_y_invert;
    }

    void hyprland_toplevel_export_frame_v1_ready(uint32_t, uint32_t, uint32_t) override
    {
        const QImage::Format fmt = m_format == WL_SHM_FORMAT_ARGB8888 ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32;
        QImage image(static_cast<const uchar *>(m_data), m_width, m_height, m_stride, fmt);
        image = m_invert ? image.mirrored(false, true) : image.copy();
        m_view->frameReady(image);
    }

    void hyprland_toplevel_export_frame_v1_failed() override
    {
        m_view->frameFailed();
    }

private:
    int m_format = -1;
    int m_width = 0;
    int m_height = 0;
    int m_stride = 0;
    bool m_invert = false;
    size_t m_size = 0;
    void *m_data = nullptr;
    ::wl_buffer *m_buffer = nullptr;
};

ScreencopyView::ScreencopyView(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
    m_next.setSingleShot(true);
    connect(&m_next, &QTimer::timeout, this, &ScreencopyView::captureFrame);
}

ScreencopyView::~ScreencopyView()
{
    delete m_frame;
}

QObject *ScreencopyView::captureSource() const
{
    return m_source;
}

void ScreencopyView::setCaptureSource(QObject *source)
{
    auto *toplevel = qobject_cast<Toplevel *>(source);
    if (toplevel == m_source)
        return;
    m_source = toplevel;
    emit captureSourceChanged();
    reset();
    if (m_source)
        schedule(0);
}

void ScreencopyView::setLive(bool live)
{
    if (live == m_live)
        return;
    m_live = live;
    emit liveChanged();
    if (m_live && m_source && !m_frame)
        schedule(0);
}

void ScreencopyView::setConstraintSize(const QSizeF &size)
{
    if (size == m_constraint)
        return;
    m_constraint = size;
    emit constraintSizeChanged();
}

void ScreencopyView::reset()
{
    m_next.stop();
    delete m_frame;
    m_frame = nullptr;
    const bool had = !m_image.isNull();
    m_image = QImage();
    m_dirty = true;
    if (had)
        emit hasContentChanged();
    update();
}

void ScreencopyView::schedule(int delay)
{
    if (!m_next.isActive())
        m_next.start(delay);
}

void ScreencopyView::captureFrame()
{
    if (m_frame || !m_source || !m_source->object())
        return;
    ExportManager *m = manager();
    if (!m)
        return;
    m_frame = new ExportFrame(m->capture_toplevel_with_wlr_toplevel_handle(0, m_source->object()), this);
}

QSize ScreencopyView::target() const
{
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    QSizeF box = m_constraint.isEmpty() ? size() : m_constraint;
    if (box.isEmpty())
        box = QSizeF(320, 200);
    return (box * dpr).toSize();
}

void ScreencopyView::frameReady(const QImage &image)
{
    delete m_frame;
    m_frame = nullptr;
    const QSize box = target();
    QImage scaled = image;
    if (image.width() > box.width() * 2 || image.height() > box.height() * 2)
        scaled = scaled.scaled(box * 2, Qt::KeepAspectRatio, Qt::FastTransformation);
    if (scaled.width() > box.width() || scaled.height() > box.height())
        scaled = scaled.scaled(box, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const bool had = !m_image.isNull();
    m_image = scaled;
    m_dirty = true;
    if (image.size() != m_sourceSize) {
        m_sourceSize = image.size();
        emit sourceSizeChanged();
    }
    if (!had)
        emit hasContentChanged();
    update();
    if (m_live)
        schedule(LiveInterval);
}

void ScreencopyView::frameFailed()
{
    delete m_frame;
    m_frame = nullptr;
    if (m_live)
        schedule(1000);
}

void ScreencopyView::itemChange(ItemChange change, const ItemChangeData &value)
{
    if (change == ItemVisibleHasChanged && value.boolValue && m_source && !m_frame)
        schedule(0);
    QQuickItem::itemChange(change, value);
}

QSGNode *ScreencopyView::updatePaintNode(QSGNode *old, UpdatePaintNodeData *)
{
    auto *node = static_cast<QSGImageNode *>(old);
    if (m_image.isNull() || !window()) {
        delete node;
        return nullptr;
    }
    if (!node) {
        node = window()->createImageNode();
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
        m_dirty = true;
    }
    if (m_dirty) {
        node->setTexture(window()->createTextureFromImage(m_image));
        m_dirty = false;
    }
    const QSizeF fit = QSizeF(m_image.size()).scaled(size(), Qt::KeepAspectRatio);
    node->setRect(QRectF(QPointF((width() - fit.width()) / 2, (height() - fit.height()) / 2), fit));
    return node;
}

}
