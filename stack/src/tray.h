#pragma once

#include "model.h"

#include <QDBusAbstractAdaptor>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantMap>

class QDBusArgument;

namespace stack {

namespace QsMenuButtonType {
Q_NAMESPACE
QML_ELEMENT
enum Enum { None = 0, CheckBox = 1, RadioButton = 2 };
Q_ENUM_NS(Enum)
}

class DBusMenu;

class MenuEntry : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("entries come from tray menus")
    Q_PROPERTY(int id READ id CONSTANT)
    Q_PROPERTY(QString text MEMBER m_text NOTIFY changed)
    Q_PROPERTY(QString icon MEMBER m_icon NOTIFY changed)
    Q_PROPERTY(bool enabled MEMBER m_enabled NOTIFY changed)
    Q_PROPERTY(bool visible MEMBER m_visible NOTIFY changed)
    Q_PROPERTY(bool isSeparator MEMBER m_separator NOTIFY changed)
    Q_PROPERTY(bool hasChildren MEMBER m_hasChildren NOTIFY changed)
    Q_PROPERTY(int buttonType MEMBER m_buttonType NOTIFY changed)
    Q_PROPERTY(int checkState MEMBER m_checkState NOTIFY changed)
    Q_PROPERTY(stack::ObjectModel *children READ children CONSTANT)

public:
    MenuEntry(int id, DBusMenu *menu);
    ~MenuEntry() override;
    int id() const { return m_id; }
    ObjectModel *children() const { return m_children; }
    void setProps(const QVariantMap &props);
    void setHasChildren(bool has);
    bool loaded() const { return m_loaded; }
    void setLoaded(bool loaded) { m_loaded = loaded; }
    QString iconKey() const;
    QList<int> kids() const { return m_kids; }
    void setKids(const QList<int> &kids) { m_kids = kids; }

    Q_INVOKABLE void triggered();
    Q_INVOKABLE void load();

signals:
    void changed();

private:
    int m_id;
    DBusMenu *m_menu;
    ObjectModel *m_children;
    QString m_text;
    QString m_icon;
    bool m_enabled = true;
    bool m_visible = true;
    bool m_separator = false;
    bool m_hasChildren = false;
    int m_buttonType = QsMenuButtonType::None;
    int m_checkState = Qt::Unchecked;
    bool m_loaded = false;
    QList<int> m_kids;
};

class DBusMenu : public QObject
{
    Q_OBJECT

public:
    DBusMenu(const QString &service, const QString &path, QObject *parent);
    MenuEntry *root() const { return m_root; }
    void load(MenuEntry *entry);
    void click(int id);
    MenuEntry *entry(int id);

private slots:
    void layoutUpdated(uint revision, int parent);
    void propertiesUpdated(const QDBusArgument &updated, const QDBusArgument &removed);

private:
    void applyLayout(MenuEntry *parent, const QDBusArgument &arg);
    void drop(MenuEntry *parent, int id);

    QString m_service;
    QString m_path;
    MenuEntry *m_root;
    QHash<int, MenuEntry *> m_entries;
};

class QsMenuOpener : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *menu READ menu WRITE setMenu NOTIFY menuChanged)
    Q_PROPERTY(stack::ObjectModel *children READ children NOTIFY menuChanged)

public:
    using QObject::QObject;
    QObject *menu() const { return m_menu; }
    void setMenu(QObject *menu);
    ObjectModel *children() const;

signals:
    void menuChanged();

private:
    QPointer<MenuEntry> m_menu;
    ObjectModel *m_none = new ObjectModel(this);
};

class SystemTrayItem : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("items come from SystemTray")
    Q_PROPERTY(QString id MEMBER m_id NOTIFY changed)
    Q_PROPERTY(QString title MEMBER m_title NOTIFY changed)
    Q_PROPERTY(QString status MEMBER m_status NOTIFY changed)
    Q_PROPERTY(QString icon MEMBER m_icon NOTIFY changed)
    Q_PROPERTY(QString tooltipTitle MEMBER m_tooltipTitle NOTIFY changed)
    Q_PROPERTY(QString tooltipDescription MEMBER m_tooltipDescription NOTIFY changed)
    Q_PROPERTY(bool onlyMenu MEMBER m_onlyMenu NOTIFY changed)
    Q_PROPERTY(bool hasMenu READ hasMenu NOTIFY changed)
    Q_PROPERTY(QObject *menu READ menu NOTIFY changed)

public:
    SystemTrayItem(const QString &service, const QString &path, QObject *parent);
    ~SystemTrayItem() override;
    QString key() const { return m_service + m_path; }
    bool hasMenu() const { return !m_menuPath.isEmpty() && m_menuPath != QStringLiteral("/"); }
    QObject *menu();

    Q_INVOKABLE void activate();
    Q_INVOKABLE void secondaryActivate();
    Q_INVOKABLE void scroll(int delta, bool horizontal);
    Q_INVOKABLE void display(QObject *window, int x, int y);

signals:
    void changed();

private slots:
    void refresh();

private:
    void apply(const QVariantMap &props);
    void call(const QString &method, const QVariantList &args);

    QString m_service;
    QString m_path;
    QString m_id;
    QString m_title;
    QString m_status;
    QString m_icon;
    QString m_tooltipTitle;
    QString m_tooltipDescription;
    QString m_menuPath;
    bool m_onlyMenu = false;
    QTimer m_debounce;
    DBusMenu *m_menu = nullptr;
};

class SystemTray : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(stack::ObjectModel *items READ items CONSTANT)

public:
    static SystemTray *instance();
    static SystemTray *create(QQmlEngine *, QJSEngine *);
    ObjectModel *items() const { return m_items; }

    void registerItem(const QString &spec, const QString &sender);
    QStringList registered() const;

private slots:
    void itemRegistered(const QString &spec);
    void itemUnregistered(const QString &spec);

private:
    SystemTray();
    void add(const QString &service, const QString &path);
    void removeService(const QString &service);
    void becomeHost();

    ObjectModel *m_items;
    QHash<QString, SystemTrayItem *> m_byKey;
    QDBusServiceWatcher m_watcher;
    bool m_isWatcher = false;
};

class TrayWatcherAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    Q_PROPERTY(QStringList RegisteredStatusNotifierItems READ items)
    Q_PROPERTY(bool IsStatusNotifierHostRegistered READ hostRegistered)
    Q_PROPERTY(int ProtocolVersion READ protocolVersion)

public:
    explicit TrayWatcherAdaptor(QObject *parent);
    QStringList items() const;
    bool hostRegistered() const { return true; }
    int protocolVersion() const { return 0; }

public slots:
    void RegisterStatusNotifierItem(const QString &service, const QDBusMessage &message);
    void RegisterStatusNotifierHost(const QString &service);

signals:
    void StatusNotifierItemRegistered(const QString &service);
    void StatusNotifierItemUnregistered(const QString &service);
    void StatusNotifierHostRegistered();
    void StatusNotifierHostUnregistered();
};

}
