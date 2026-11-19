#include "vinput.h"

#include <QElapsedTimer>
#include <QGuiApplication>
#include <QtWaylandClient/QWaylandClientExtensionTemplate>

#include <wayland-client-protocol.h>
#include <xkbcommon/xkbcommon.h>

#include <linux/input-event-codes.h>
#include <sys/mman.h>
#include <unistd.h>

#include <algorithm>
#include <cmath>

#include "qwayland-virtual-keyboard-unstable-v1.h"
#include "qwayland-wlr-virtual-pointer-unstable-v1.h"

namespace stack {

namespace {

constexpr int FirstCode = 9;
constexpr int MaxCodes = 240;
constexpr double MaxStep = 10000;

class KeyboardManager : public QWaylandClientExtensionTemplate<KeyboardManager>, public QtWayland::zwp_virtual_keyboard_manager_v1
{
public:
    KeyboardManager()
        : QWaylandClientExtensionTemplate<KeyboardManager>(1)
    {
        initialize();
    }
};

class PointerManager : public QWaylandClientExtensionTemplate<PointerManager>, public QtWayland::zwlr_virtual_pointer_manager_v1
{
public:
    PointerManager()
        : QWaylandClientExtensionTemplate<PointerManager>(2)
    {
        initialize();
    }
};

KeyboardManager *keyboardManager()
{
    static KeyboardManager *m = new KeyboardManager();
    return m;
}

PointerManager *pointerManager()
{
    static PointerManager *m = new PointerManager();
    return m;
}

wl_seat *seat()
{
    auto *app = qGuiApp ? qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>() : nullptr;
    return app ? app->seat() : nullptr;
}

uint32_t symFromName(const QString &name)
{
    if (name.isEmpty() || name.size() > 64)
        return XKB_KEY_NoSymbol;
    return xkb_keysym_from_name(name.toUtf8().constData(), XKB_KEYSYM_NO_FLAGS);
}

uint32_t modMask(const QStringList &mods, bool *ok)
{
    uint32_t mask = 0;
    *ok = true;
    for (const QString &m : mods) {
        if (m == QLatin1String("shift"))
            mask |= 1u << 0;
        else if (m == QLatin1String("ctrl"))
            mask |= 1u << 2;
        else if (m == QLatin1String("alt"))
            mask |= 1u << 3;
        else if (m == QLatin1String("super"))
            mask |= 1u << 6;
        else
            *ok = false;
    }
    return mask;
}

}

VirtualInput::VirtualInput(QObject *parent)
    : QObject(parent)
{
    const auto ready = [this] {
        ensureKeyboard();
        ensurePointer();
        emit availableChanged();
    };
    connect(keyboardManager(), &QWaylandClientExtension::activeChanged, this, ready);
    connect(pointerManager(), &QWaylandClientExtension::activeChanged, this, ready);
    ready();
}

VirtualInput::~VirtualInput()
{
    releaseAll();
    if (m_keyboard)
        zwp_virtual_keyboard_v1_destroy(m_keyboard);
    if (m_pointer)
        zwlr_virtual_pointer_v1_destroy(m_pointer);
}

bool VirtualInput::available() const
{
    return keyboardManager()->isActive();
}

bool VirtualInput::pointerAvailable() const
{
    return pointerManager()->isActive();
}

uint32_t VirtualInput::now() const
{
    static QElapsedTimer clock;
    if (!clock.isValid())
        clock.start();
    return static_cast<uint32_t>(clock.elapsed());
}

bool VirtualInput::ensureKeyboard()
{
    if (m_keyboard)
        return true;
    wl_seat *s = seat();
    if (!keyboardManager()->isActive() || !s)
        return false;
    m_keyboard = keyboardManager()->create_virtual_keyboard(s);
    if (m_keyboard)
        sendKeymap();
    return m_keyboard != nullptr;
}

bool VirtualInput::ensurePointer()
{
    if (m_pointer)
        return true;
    wl_seat *s = seat();
    if (!pointerManager()->isActive() || !s)
        return false;
    m_pointer = pointerManager()->create_virtual_pointer(s);
    return m_pointer != nullptr;
}

void VirtualInput::sendKeymap()
{
    QByteArray map = "xkb_keymap {\nxkb_keycodes \"sylstack\" {\nminimum = 8;\nmaximum = " + QByteArray::number(FirstCode + MaxCodes) + ";\n";
    for (int i = 0; i < m_syms.size(); ++i)
        map += "<K" + QByteArray::number(i) + "> = " + QByteArray::number(FirstCode + i) + ";\n";
    map += "};\nxkb_types \"sylstack\" { include \"complete\" };\nxkb_compat \"sylstack\" { include \"complete\" };\nxkb_symbols \"sylstack\" {\n";
    for (int i = 0; i < m_syms.size(); ++i) {
        char name[64];
        xkb_keysym_get_name(m_syms[i], name, sizeof(name));
        map += "key <K" + QByteArray::number(i) + "> {[" + QByteArray(name) + "]};\n";
    }
    map += "};\n};\n";
    const int fd = memfd_create("sylstack-keymap", MFD_CLOEXEC);
    if (fd < 0)
        return;
    const QByteArray bytes = map + '\0';
    qsizetype done = 0;
    while (done < bytes.size()) {
        const ssize_t n = ::write(fd, bytes.constData() + done, bytes.size() - done);
        if (n <= 0)
            break;
        done += n;
    }
    if (done == bytes.size())
        zwp_virtual_keyboard_v1_keymap(m_keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, bytes.size());
    ::close(fd);
}

bool VirtualInput::learn(const QList<uint32_t> &syms)
{
    QList<uint32_t> fresh;
    for (const uint32_t sym : syms)
        if (!m_codes.contains(sym) && !fresh.contains(sym))
            fresh.append(sym);
    if (fresh.isEmpty())
        return true;
    if (fresh.size() > MaxCodes)
        return false;
    if (m_syms.size() + fresh.size() > MaxCodes) {
        releaseAll();
        m_syms.clear();
        m_codes.clear();
    }
    for (const uint32_t sym : fresh) {
        m_codes.insert(sym, m_syms.size());
        m_syms.append(sym);
    }
    sendKeymap();
    return true;
}

int VirtualInput::codeFor(uint32_t sym)
{
    learn({sym});
    return m_codes.value(sym);
}

void VirtualInput::sendKey(int code, bool pressed)
{
    zwp_virtual_keyboard_v1_key(m_keyboard, now(), code + FirstCode - 8, pressed ? WL_KEYBOARD_KEY_STATE_PRESSED : WL_KEYBOARD_KEY_STATE_RELEASED);
    if (pressed)
        m_down.insert(code);
    else
        m_down.remove(code);
}

void VirtualInput::sendMods(uint32_t mask)
{
    zwp_virtual_keyboard_v1_modifiers(m_keyboard, mask, 0, 0, 0);
}

bool VirtualInput::type(const QString &text)
{
    if (text.isEmpty() || text.size() > MaxText || !ensureKeyboard())
        return false;
    QList<uint32_t> syms;
    for (const char32_t cp : text.toUcs4()) {
        const uint32_t sym = cp == U'\n' ? XKB_KEY_Return : cp == U'\t' ? XKB_KEY_Tab : xkb_utf32_to_keysym(cp);
        if (sym != XKB_KEY_NoSymbol)
            syms.append(sym);
    }
    if (!learn(syms))
        return false;
    for (const uint32_t sym : syms) {
        const int code = m_codes.value(sym);
        sendKey(code, true);
        sendKey(code, false);
    }
    return true;
}

bool VirtualInput::key(const QString &keysym, bool pressed)
{
    const uint32_t sym = symFromName(keysym);
    if (sym == XKB_KEY_NoSymbol || !ensureKeyboard())
        return false;
    const int code = codeFor(sym);
    if (pressed || m_down.contains(code))
        sendKey(code, pressed);
    return true;
}

bool VirtualInput::tap(const QString &keysym, const QStringList &mods)
{
    bool ok = false;
    const uint32_t mask = modMask(mods, &ok);
    const uint32_t sym = symFromName(keysym);
    if (!ok || sym == XKB_KEY_NoSymbol || !ensureKeyboard())
        return false;
    const int code = codeFor(sym);
    if (mask)
        sendMods(mask);
    sendKey(code, true);
    sendKey(code, false);
    if (mask)
        sendMods(0);
    return true;
}

void VirtualInput::move(double dx, double dy)
{
    if (!std::isfinite(dx) || !std::isfinite(dy) || !ensurePointer())
        return;
    zwlr_virtual_pointer_v1_motion(m_pointer, now(), wl_fixed_from_double(std::clamp(dx, -MaxStep, MaxStep)), wl_fixed_from_double(std::clamp(dy, -MaxStep, MaxStep)));
    zwlr_virtual_pointer_v1_frame(m_pointer);
}

bool VirtualInput::button(const QString &name, bool pressed)
{
    const uint32_t code = name == QLatin1String("left") ? BTN_LEFT : name == QLatin1String("right") ? BTN_RIGHT : name == QLatin1String("middle") ? BTN_MIDDLE : 0;
    if (!code || !ensurePointer())
        return false;
    if (!pressed && !m_buttons.contains(code))
        return true;
    zwlr_virtual_pointer_v1_button(m_pointer, now(), code, pressed ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(m_pointer);
    if (pressed)
        m_buttons.insert(code);
    else
        m_buttons.remove(code);
    return true;
}

void VirtualInput::scroll(double dx, double dy)
{
    if (!std::isfinite(dx) || !std::isfinite(dy) || (dx == 0 && dy == 0) || !ensurePointer())
        return;
    const uint32_t t = now();
    zwlr_virtual_pointer_v1_axis_source(m_pointer, WL_POINTER_AXIS_SOURCE_FINGER);
    if (dy != 0)
        zwlr_virtual_pointer_v1_axis(m_pointer, t, WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(std::clamp(dy, -MaxStep, MaxStep)));
    if (dx != 0)
        zwlr_virtual_pointer_v1_axis(m_pointer, t, WL_POINTER_AXIS_HORIZONTAL_SCROLL, wl_fixed_from_double(std::clamp(dx, -MaxStep, MaxStep)));
    zwlr_virtual_pointer_v1_frame(m_pointer);
}

void VirtualInput::releaseAll()
{
    if (m_keyboard) {
        for (const int code : m_down.values())
            sendKey(code, false);
        sendMods(0);
    }
    if (m_pointer) {
        for (const uint32_t b : m_buttons.values())
            zwlr_virtual_pointer_v1_button(m_pointer, now(), b, WL_POINTER_BUTTON_STATE_RELEASED);
        if (!m_buttons.isEmpty())
            zwlr_virtual_pointer_v1_frame(m_pointer);
        m_buttons.clear();
    }
}

}
