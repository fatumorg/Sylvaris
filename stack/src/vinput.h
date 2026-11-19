#pragma once

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QStringList>

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

signals:
    void availableChanged();

private:
    bool ensureKeyboard();
    bool ensurePointer();
    bool learn(const QList<uint32_t> &syms);
    int codeFor(uint32_t sym);
    void sendKeymap();
    void sendKey(int code, bool pressed);
    void sendMods(uint32_t mask);
    uint32_t now() const;

    zwp_virtual_keyboard_v1 *m_keyboard = nullptr;
    zwlr_virtual_pointer_v1 *m_pointer = nullptr;
    QList<uint32_t> m_syms;
    QHash<uint32_t, int> m_codes;
    QSet<int> m_down;
    QSet<uint32_t> m_buttons;
};

}
