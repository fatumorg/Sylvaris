#pragma once

#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QSocketNotifier>

namespace stack {

class Gamepad : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool grabbed READ grabbed WRITE setGrabbed NOTIFY grabbedChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit Gamepad(QObject *parent = nullptr);
    ~Gamepad() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool on);
    bool grabbed() const { return m_grabbed; }
    void setGrabbed(bool on);
    int count() const { return m_pads.size(); }

signals:
    void enabledChanged();
    void grabbedChanged();
    void countChanged();
    void pressed(const QString &button);

private:
    struct Axis {
        int min = 0;
        int max = 0;
        int dir = 0;
    };
    struct Pad {
        int fd = -1;
        QSocketNotifier *notifier = nullptr;
        Axis x;
        Axis y;
        int hatX = 0;
        int hatY = 0;
        bool select = false;
        bool start = false;
        bool owned = false;
    };

    void scan();
    void closeAll();
    void drop(const QString &path);
    void readPad(const QString &path);
    void stick(Axis &axis, int value, const char *minus, const char *plus);
    void button(Pad &pad, int code, int value);
    void tryGrab(Pad &pad);

    bool m_enabled = false;
    bool m_grabbed = false;
    QHash<QString, Pad> m_pads;
    QFileSystemWatcher m_watcher;
};

}
