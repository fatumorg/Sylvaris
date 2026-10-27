#pragma once

#include <QJSValue>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QScreen>
#include <QVariant>

#include <functional>

class QTimer;

namespace stack {

class ShellScreen : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("screens come from Stack.screens")
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString model READ model CONSTANT)
    Q_PROPERTY(QString manufacturer READ manufacturer CONSTANT)
    Q_PROPERTY(QString serialNumber READ serialNumber CONSTANT)
    Q_PROPERTY(int x READ x NOTIFY geometryChanged)
    Q_PROPERTY(int y READ y NOTIFY geometryChanged)
    Q_PROPERTY(int width READ width NOTIFY geometryChanged)
    Q_PROPERTY(int height READ height NOTIFY geometryChanged)
    Q_PROPERTY(qreal devicePixelRatio READ devicePixelRatio NOTIFY geometryChanged)

public:
    ShellScreen(QScreen *screen, QObject *parent);

    QScreen *screen() const { return m_screen; }
    QString name() const;
    QString model() const;
    QString manufacturer() const;
    QString serialNumber() const;
    int x() const;
    int y() const;
    int width() const;
    int height() const;
    qreal devicePixelRatio() const;

signals:
    void geometryChanged();

private:
    QPointer<QScreen> m_screen;
    QString m_name;
};

class Stack : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList screens READ screens NOTIFY screensChanged)
    Q_PROPERTY(QString shellDir READ shellDir CONSTANT)
    Q_PROPERTY(QString clipboardText READ clipboardText WRITE setClipboardText NOTIFY clipboardTextChanged)
    Q_PROPERTY(qint64 processId READ processId CONSTANT)

public:
    static Stack *instance();
    static Stack *create(QQmlEngine *, QJSEngine *);

    QVariantList screens() const;
    QString shellDir() const { return m_shellDir; }
    void setShellDir(const QString &dir) { m_shellDir = dir; }
    QString clipboardText() const;
    void setClipboardText(const QString &text);
    qint64 processId() const;

    ShellScreen *screenFor(QScreen *screen) const;
    void whenReady(QObject *context, std::function<void()> fn);
    bool isReady() const { return m_ready; }
    void setReady(bool ready);
    void trimSoon();

    Q_INVOKABLE QVariant env(const QString &name) const;
    Q_INVOKABLE void execDetached(const QJSValue &command) const;
    Q_INVOKABLE QString iconPath(const QString &name, bool check = false) const;
    Q_INVOKABLE void reload(bool hard = false);

signals:
    void screensChanged();
    void clipboardTextChanged();
    void reloadRequested();

private:
    explicit Stack(QObject *parent = nullptr);
    void addScreen(QScreen *screen);
    void removeScreen(QScreen *screen);

    QList<ShellScreen *> m_screens;
    QString m_shellDir;
    bool m_ready = false;
    QList<QPair<QPointer<QObject>, std::function<void()>>> m_pending;
    QTimer *m_trim = nullptr;
};

}
