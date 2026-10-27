#pragma once

#include "model.h"

#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QTimer>

namespace stack {

class DesktopEntry : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("entries come from DesktopEntries")
    Q_PROPERTY(QString id MEMBER id CONSTANT)
    Q_PROPERTY(QString name MEMBER name CONSTANT)
    Q_PROPERTY(QString genericName MEMBER genericName CONSTANT)
    Q_PROPERTY(QString comment MEMBER comment CONSTANT)
    Q_PROPERTY(QString icon MEMBER icon CONSTANT)
    Q_PROPERTY(QString execString MEMBER execString CONSTANT)
    Q_PROPERTY(QStringList command MEMBER command CONSTANT)
    Q_PROPERTY(QString workingDirectory MEMBER workingDirectory CONSTANT)
    Q_PROPERTY(QStringList keywords MEMBER keywords CONSTANT)
    Q_PROPERTY(QStringList categories MEMBER categories CONSTANT)
    Q_PROPERTY(QString startupClass MEMBER startupClass CONSTANT)
    Q_PROPERTY(bool noDisplay MEMBER noDisplay CONSTANT)
    Q_PROPERTY(bool runInTerminal MEMBER runInTerminal CONSTANT)

public:
    using QObject::QObject;
    Q_INVOKABLE void execute() const;

    QString id;
    QString name;
    QString genericName;
    QString comment;
    QString icon;
    QString execString;
    QStringList command;
    QString workingDirectory;
    QStringList keywords;
    QStringList categories;
    QString startupClass;
    bool noDisplay = false;
    bool runInTerminal = false;
};

class DesktopEntries : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::ObjectModel *applications READ applications CONSTANT)

public:
    static DesktopEntries *create(QQmlEngine *, QJSEngine *);
    ObjectModel *applications();
    Q_INVOKABLE stack::DesktopEntry *byId(const QString &id);
    Q_INVOKABLE stack::DesktopEntry *heuristicLookup(const QString &name);

    static QStringList splitExec(const QString &exec);

private:
    DesktopEntries();
    void scan();

    ObjectModel *m_model;
    QHash<QString, DesktopEntry *> m_byId;
    QFileSystemWatcher m_watcher;
    QTimer m_rescan;
    bool m_scanned = false;
};

class ImageStore : public QQuickImageProvider
{
public:
    ImageStore();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    static QString put(const QString &key, const QImage &image);
    static void drop(const QString &key);
    static QImage decode(const QByteArray &data, int maxSide);
};

class IconProvider : public QQuickImageProvider
{
public:
    IconProvider();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};

}
