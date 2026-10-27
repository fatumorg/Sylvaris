#pragma once

#include <QImage>
#include <QPointer>
#include <QQmlEngine>
#include <QQuickItem>
#include <QTimer>

struct wl_buffer;

namespace stack {

class Toplevel;
class ExportFrame;

class ScreencopyView : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *captureSource READ captureSource WRITE setCaptureSource NOTIFY captureSourceChanged)
    Q_PROPERTY(bool live READ live WRITE setLive NOTIFY liveChanged)
    Q_PROPERTY(QSizeF constraintSize READ constraintSize WRITE setConstraintSize NOTIFY constraintSizeChanged)
    Q_PROPERTY(bool hasContent READ hasContent NOTIFY hasContentChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)

public:
    explicit ScreencopyView(QQuickItem *parent = nullptr);
    ~ScreencopyView() override;

    QObject *captureSource() const;
    void setCaptureSource(QObject *source);
    bool live() const { return m_live; }
    void setLive(bool live);
    QSizeF constraintSize() const { return m_constraint; }
    void setConstraintSize(const QSizeF &size);
    bool hasContent() const { return !m_image.isNull(); }
    QSize sourceSize() const { return m_sourceSize; }

    Q_INVOKABLE void captureFrame();

    void frameReady(const QImage &image);
    void frameFailed();

signals:
    void captureSourceChanged();
    void liveChanged();
    void constraintSizeChanged();
    void hasContentChanged();
    void sourceSizeChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    void reset();
    void schedule(int delay);
    QSize target() const;

    QPointer<Toplevel> m_source;
    bool m_live = false;
    QSizeF m_constraint;
    QSize m_sourceSize;
    QImage m_image;
    bool m_dirty = false;
    ExportFrame *m_frame = nullptr;
    QTimer m_next;
};

}
