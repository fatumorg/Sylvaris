#include "gamepad.h"

#include <QDir>

#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <cerrno>
#include <climits>

namespace stack {

namespace {

const QString InputDir = QStringLiteral("/dev/input");

bool hasBit(const unsigned long *bits, int bit)
{
    constexpr int per = sizeof(unsigned long) * CHAR_BIT;
    return (bits[bit / per] >> (bit % per)) & 1UL;
}

bool isPad(int fd)
{
    unsigned long keys[(KEY_MAX + 1) / (sizeof(unsigned long) * CHAR_BIT) + 1] = {};
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keys)), keys) < 0)
        return false;
    return hasBit(keys, BTN_SOUTH) || hasBit(keys, BTN_GAMEPAD);
}

bool buttonsHeld(int fd)
{
    unsigned long keys[(KEY_MAX + 1) / (sizeof(unsigned long) * CHAR_BIT) + 1] = {};
    if (ioctl(fd, EVIOCGKEY(sizeof(keys)), keys) < 0)
        return true;
    for (int b = BTN_SOUTH; b <= BTN_THUMBR; ++b)
        if (hasBit(keys, b))
            return true;
    for (int b = BTN_DPAD_UP; b <= BTN_DPAD_RIGHT; ++b)
        if (hasBit(keys, b))
            return true;
    return false;
}

bool absRange(int fd, int code, int *min, int *max)
{
    input_absinfo info {};
    if (ioctl(fd, EVIOCGABS(code), &info) < 0 || info.maximum <= info.minimum)
        return false;
    *min = info.minimum;
    *max = info.maximum;
    return true;
}

}

Gamepad::Gamepad(QObject *parent)
    : QObject(parent)
{
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Gamepad::scan);
}

Gamepad::~Gamepad()
{
    closeAll();
}

void Gamepad::setEnabled(bool on)
{
    if (on == m_enabled)
        return;
    m_enabled = on;
    if (on) {
        m_watcher.addPath(InputDir);
        scan();
    } else {
        m_watcher.removePaths(m_watcher.directories());
        closeAll();
    }
    emit enabledChanged();
}

void Gamepad::setGrabbed(bool on)
{
    if (on == m_grabbed)
        return;
    m_grabbed = on;
    for (Pad &pad : m_pads) {
        if (on) {
            tryGrab(pad);
        } else if (pad.owned) {
            ioctl(pad.fd, EVIOCGRAB, 0);
            pad.owned = false;
        }
    }
    emit grabbedChanged();
}

void Gamepad::tryGrab(Pad &pad)
{
    if (pad.owned || !m_grabbed)
        return;
    if (pad.hatX != 0 || pad.hatY != 0 || pad.x.dir != 0 || pad.y.dir != 0 || buttonsHeld(pad.fd))
        return;
    pad.owned = ioctl(pad.fd, EVIOCGRAB, 1) == 0;
}

void Gamepad::scan()
{
    if (!m_enabled)
        return;
    const int before = m_pads.size();
    for (auto it = m_pads.begin(); it != m_pads.end();) {
        if (!QFile::exists(it.key())) {
            it->notifier->setEnabled(false);
            it->notifier->deleteLater();
            ::close(it->fd);
            it = m_pads.erase(it);
        } else {
            ++it;
        }
    }
    const QStringList names = QDir(InputDir).entryList({QStringLiteral("event*")}, QDir::System);
    for (const QString &name : names) {
        const QString path = InputDir + QLatin1Char('/') + name;
        if (m_pads.contains(path))
            continue;
        const int fd = ::open(QFile::encodeName(path).constData(), O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0)
            continue;
        if (!isPad(fd)) {
            ::close(fd);
            continue;
        }
        Pad pad;
        pad.fd = fd;
        absRange(fd, ABS_X, &pad.x.min, &pad.x.max);
        absRange(fd, ABS_Y, &pad.y.min, &pad.y.max);
        tryGrab(pad);
        pad.notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
        connect(pad.notifier, &QSocketNotifier::activated, this, [this, path] { readPad(path); });
        m_pads.insert(path, pad);
    }
    if (m_pads.size() != before)
        emit countChanged();
}

void Gamepad::closeAll()
{
    const bool had = !m_pads.isEmpty();
    for (const Pad &pad : std::as_const(m_pads)) {
        pad.notifier->setEnabled(false);
        pad.notifier->deleteLater();
        ::close(pad.fd);
    }
    m_pads.clear();
    if (had)
        emit countChanged();
}

void Gamepad::drop(const QString &path)
{
    auto it = m_pads.find(path);
    if (it == m_pads.end())
        return;
    it->notifier->setEnabled(false);
    it->notifier->deleteLater();
    ::close(it->fd);
    m_pads.erase(it);
    emit countChanged();
}

void Gamepad::stick(Axis &axis, int value, const char *minus, const char *plus)
{
    if (axis.max <= axis.min)
        return;
    const double half = (axis.max - axis.min) / 2.0;
    const double pos = (value - axis.min - half) / half;
    if (axis.dir == 0 && (pos > 0.6 || pos < -0.6)) {
        axis.dir = pos > 0 ? 1 : -1;
        emit pressed(QString::fromLatin1(axis.dir > 0 ? plus : minus));
    } else if (axis.dir != 0 && pos < 0.3 && pos > -0.3) {
        axis.dir = 0;
    }
}

void Gamepad::button(Pad &pad, int code, int value)
{
    if (code == BTN_SELECT)
        pad.select = value != 0;
    if (code == BTN_START)
        pad.start = value != 0;
    if (value != 1)
        return;
    const char *name = nullptr;
    switch (code) {
    case BTN_SOUTH: name = "a"; break;
    case BTN_EAST: name = "b"; break;
    case BTN_NORTH: name = "x"; break;
    case BTN_WEST: name = "y"; break;
    case BTN_SELECT: name = "select"; break;
    case BTN_START: name = "start"; break;
    case BTN_DPAD_UP: name = "up"; break;
    case BTN_DPAD_DOWN: name = "down"; break;
    case BTN_DPAD_LEFT: name = "left"; break;
    case BTN_DPAD_RIGHT: name = "right"; break;
    default: return;
    }
    const bool combo = pad.select && pad.start && (code == BTN_SELECT || code == BTN_START);
    emit pressed(QString::fromLatin1(name));
    if (combo)
        emit pressed(QStringLiteral("combo"));
}

void Gamepad::readPad(const QString &path)
{
    auto it = m_pads.find(path);
    if (it == m_pads.end())
        return;
    input_event events[64];
    for (;;) {
        const ssize_t n = ::read(it->fd, events, sizeof(events));
        if (n < 0 && (errno == EAGAIN || errno == EINTR))
            return;
        if (n <= 0 || n % static_cast<ssize_t>(sizeof(input_event)) != 0) {
            drop(path);
            return;
        }
        const int count = static_cast<int>(n / static_cast<ssize_t>(sizeof(input_event)));
        for (int i = 0; i < count; ++i) {
            const input_event &e = events[i];
            if (e.type == EV_KEY) {
                button(*it, e.code, e.value);
            } else if (e.type == EV_ABS) {
                if (e.code == ABS_HAT0X) {
                    const int was = it->hatX;
                    it->hatX = e.value;
                    if (e.value != 0 && was == 0)
                        emit pressed(QString::fromLatin1(e.value > 0 ? "right" : "left"));
                } else if (e.code == ABS_HAT0Y) {
                    const int was = it->hatY;
                    it->hatY = e.value;
                    if (e.value != 0 && was == 0)
                        emit pressed(QString::fromLatin1(e.value > 0 ? "down" : "up"));
                } else if (e.code == ABS_X) {
                    stick(it->x, e.value, "left", "right");
                } else if (e.code == ABS_Y) {
                    stick(it->y, e.value, "up", "down");
                }
            }
            it = m_pads.find(path);
            if (it == m_pads.end())
                return;
        }
        tryGrab(*it);
    }
}

}
