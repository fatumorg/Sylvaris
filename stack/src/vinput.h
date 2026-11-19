#pragma once

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QStringList>
#include <QTimer>

#include <cstdint>

struct zwp_virtual_keyboard_v1;
struct zwlr_virtual_pointer_v1;

namespace stack {

class VirtualInput : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool pointerAvailable READ pointerAvailable NOTIFY availableChanged)

public:
    explicit VirtualInput(QObject *parent = nullptr);
    ~VirtualInput() override;

    bool available() const;
    bool pointerAvailable() const;

    Q_INVOKABLE bool type(const QString &text);
    Q_INVOKABLE bool key(const QString &keysym, bool pressed);
    Q_INVOKABLE bool tap(const QString &keysym, const QStringList &mods = {});
    Q_INVOKABLE void move(double dx, double dy);
    Q_INVOKABLE bool button(const QString &name, bool pressed);
    Q_INVOKABLE void scroll(double dx, double dy);
    Q_INVOKABLE void releaseAll();

    static constexpr int MaxText = 4096;
    static constexpr int MaxQueue = 4 * MaxText;

signals:
    void availableChanged();

private:
    bool ensureKeyboard();
    bool ensurePointer();
    struct Op {
        int code;
        bool pressed;
        uint32_t mods;
    };

    bool learn(const QList<uint32_t> &syms);
    void sendKeymap();
    void enqueue(int code, bool pressed, uint32_t mods);
    void pump();
    uint32_t now() const;

    zwp_virtual_keyboard_v1 *m_keyboard = nullptr;
    zwlr_virtual_pointer_v1 *m_pointer = nullptr;
    QHash<uint32_t, int> m_codes;
    int m_dynamic = 0;
    uint32_t m_mods = 0;
    QList<Op> m_queue;
    QTimer m_pump;
    QSet<int> m_down;
    QSet<uint32_t> m_buttons;
};

}
