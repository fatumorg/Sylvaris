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

constexpr double MaxStep = 10000;

int realCode(uint32_t sym)
{
    static const QHash<uint32_t, int> codes = [] {
        QHash<uint32_t, int> c;
        const char *rows[] = {"1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"};
        const int starts[] = {KEY_1, KEY_Q, KEY_A, KEY_Z};
        for (int r = 0; r < 4; ++r)
            for (int i = 0; rows[r][i]; ++i)
                c.insert(static_cast<uint32_t>(rows[r][i]), starts[r] + i);
        const std::pair<uint32_t, int> named[] = {
            {XKB_KEY_Escape, KEY_ESC}, {XKB_KEY_minus, KEY_MINUS}, {XKB_KEY_equal, KEY_EQUAL}, {XKB_KEY_BackSpace, KEY_BACKSPACE},
            {XKB_KEY_Tab, KEY_TAB}, {XKB_KEY_bracketleft, KEY_LEFTBRACE}, {XKB_KEY_bracketright, KEY_RIGHTBRACE}, {XKB_KEY_Return, KEY_ENTER},
            {XKB_KEY_semicolon, KEY_SEMICOLON}, {XKB_KEY_apostrophe, KEY_APOSTROPHE}, {XKB_KEY_grave, KEY_GRAVE}, {XKB_KEY_backslash, KEY_BACKSLASH},
            {XKB_KEY_comma, KEY_COMMA}, {XKB_KEY_period, KEY_DOT}, {XKB_KEY_slash, KEY_SLASH}, {XKB_KEY_space, KEY_SPACE},
            {XKB_KEY_Up, KEY_UP}, {XKB_KEY_Down, KEY_DOWN}, {XKB_KEY_Left, KEY_LEFT}, {XKB_KEY_Right, KEY_RIGHT},
            {XKB_KEY_Home, KEY_HOME}, {XKB_KEY_End, KEY_END}, {XKB_KEY_Prior, KEY_PAGEUP}, {XKB_KEY_Next, KEY_PAGEDOWN},
            {XKB_KEY_Delete, KEY_DELETE}, {XKB_KEY_Insert, KEY_INSERT}, {XKB_KEY_Super_L, KEY_LEFTMETA},
            {XKB_KEY_F1, KEY_F1}, {XKB_KEY_F2, KEY_F2}, {XKB_KEY_F3, KEY_F3}, {XKB_KEY_F4, KEY_F4}, {XKB_KEY_F5, KEY_F5}, {XKB_KEY_F6, KEY_F6},
            {XKB_KEY_F7, KEY_F7}, {XKB_KEY_F8, KEY_F8}, {XKB_KEY_F9, KEY_F9}, {XKB_KEY_F10, KEY_F10}, {XKB_KEY_F11, KEY_F11}, {XKB_KEY_F12, KEY_F12}};
        for (const auto &n : named)
            c.insert(n.first, n.second);
        return c;
    }();
    return codes.value(sym, -1);
}

const QList<int> &dynamicCodes()
{
    static const QList<int> pool = [] {
        QList<int> p;
        for (int code = 120; code <= 247; ++code)
            if (code != KEY_LEFTMETA && code != KEY_RIGHTMETA && code != KEY_COMPOSE)
                p.append(code);
        return p;
    }();
    return pool;
}

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
    m_pump.setInterval(0);
    connect(&m_pump, &QTimer::timeout, this, &VirtualInput::pump);
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
    QByteArray map = "xkb_keymap {\nxkb_keycodes \"sylstack\" {\nminimum = 8;\nmaximum = 255;\n";
    for (auto it = m_codes.constBegin(); it != m_codes.constEnd(); ++it)
        map += "<C" + QByteArray::number(it.value()) + "> = " + QByteArray::number(it.value() + 8) + ";\n";
    map += "};\nxkb_types \"sylstack\" { include \"complete\" };\nxkb_compat \"sylstack\" { include \"complete\" };\nxkb_symbols \"sylstack\" {\n";
    for (auto it = m_codes.constBegin(); it != m_codes.constEnd(); ++it) {
        char name[64];
        xkb_keysym_get_name(it.key(), name, sizeof(name));
        map += "key <C" + QByteArray::number(it.value()) + "> {[" + QByteArray(name) + "]};\n";
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
    int dynamic = 0;
    for (const uint32_t sym : syms)
        if (!m_codes.contains(sym) && !fresh.contains(sym)) {
            fresh.append(sym);
            if (realCode(sym) < 0)
                ++dynamic;
        }
    if (fresh.isEmpty())
        return true;
    const QList<int> &pool = dynamicCodes();
    if (dynamic > pool.size())
        return false;
    if (m_dynamic + dynamic > pool.size()) {
        if (!m_queue.isEmpty() || !m_down.isEmpty())
            return false;
        for (auto it = m_codes.begin(); it != m_codes.end();)
            it = realCode(it.key()) < 0 ? m_codes.erase(it) : std::next(it);
        m_dynamic = 0;
    }
    for (const uint32_t sym : fresh) {
        const int real = realCode(sym);
        m_codes.insert(sym, real >= 0 ? real : pool[m_dynamic++]);
    }
    sendKeymap();
    return true;
}

void VirtualInput::enqueue(int code, bool pressed, uint32_t mods)
{
    m_queue.append({code, pressed, mods});
    if (!m_pump.isActive())
        m_pump.start();
}

void VirtualInput::pump()
{
    for (int i = 0; i < 64 && !m_queue.isEmpty(); ++i) {
        const Op op = m_queue.takeFirst();
        if (!m_keyboard)
            continue;
        if (op.code < 0) {
            zwp_virtual_keyboard_v1_modifiers(m_keyboard, op.mods, 0, 0, 0);
            m_mods = op.mods;
            continue;
        }
        zwp_virtual_keyboard_v1_key(m_keyboard, now(), op.code, op.pressed ? WL_KEYBOARD_KEY_STATE_PRESSED : WL_KEYBOARD_KEY_STATE_RELEASED);
        if (op.pressed)
            m_down.insert(op.code);
        else
            m_down.remove(op.code);
    }
    if (m_queue.isEmpty())
        m_pump.stop();
}

bool VirtualInput::type(const QString &text)
{
    if (text.isEmpty() || text.size() > MaxText || m_queue.size() > MaxQueue || !ensureKeyboard())
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
        enqueue(code, true, 0);
        enqueue(code, false, 0);
    }
    return true;
}

bool VirtualInput::key(const QString &keysym, bool pressed)
{
    const uint32_t sym = symFromName(keysym);
    if (sym == XKB_KEY_NoSymbol || m_queue.size() > MaxQueue || !ensureKeyboard() || !learn({sym}))
        return false;
    enqueue(m_codes.value(sym), pressed, 0);
    return true;
}

bool VirtualInput::tap(const QString &keysym, const QStringList &mods)
{
    bool ok = false;
    const uint32_t mask = modMask(mods, &ok);
    const uint32_t sym = symFromName(keysym);
    if (!ok || sym == XKB_KEY_NoSymbol || m_queue.size() > MaxQueue || !ensureKeyboard() || !learn({sym}))
        return false;
    const int code = m_codes.value(sym);
    if (mask)
        enqueue(-1, false, mask);
    enqueue(code, true, 0);
    enqueue(code, false, 0);
    if (mask)
        enqueue(-1, false, 0);
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
    m_queue.clear();
    m_pump.stop();
    if (m_keyboard) {
        for (const int code : m_down.values())
            zwp_virtual_keyboard_v1_key(m_keyboard, now(), code, WL_KEYBOARD_KEY_STATE_RELEASED);
        m_down.clear();
        if (m_mods) {
            zwp_virtual_keyboard_v1_modifiers(m_keyboard, 0, 0, 0, 0);
            m_mods = 0;
        }
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
