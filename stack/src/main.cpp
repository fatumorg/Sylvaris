#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QSocketNotifier>
#include <QTimer>
#include <QUrl>

#include <cerrno>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <string>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#include "desktop.h"
#include "stack.h"

namespace {

int signalPipe[2] = {-1, -1};

void onSignal(int sig)
{
    const char c = static_cast<char>(sig);
    [[maybe_unused]] auto n = write(signalPipe[1], &c, 1);
}

std::string runtimeRoot()
{
    const char *xdg = std::getenv("XDG_RUNTIME_DIR");
    std::string base = xdg && *xdg ? std::string(xdg) + "/sylstack" : "/tmp/sylstack-" + std::to_string(getuid());
    mkdir(base.c_str(), 0700);
    struct stat st {};
    if (lstat(base.c_str(), &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != getuid()) {
        std::fprintf(stderr, "sylstack: %s is not a private directory\n", base.c_str());
        std::exit(1);
    }
    chmod(base.c_str(), 0700);
    return base;
}

bool writeAll(int fd, const char *data, size_t len)
{
    while (len > 0) {
        const ssize_t n = write(fd, data, len);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            return false;
        }
        data += n;
        len -= static_cast<size_t>(n);
    }
    return true;
}

int message(int argc, char **argv)
{
    bool follow = false;
    int i = 2;
    if (i < argc && std::strcmp(argv[i], "-f") == 0) {
        follow = true;
        i++;
    }
    if (i >= argc) {
        std::fprintf(stderr, "usage: sylstack msg [-f] SOCKET [PAYLOAD]\n");
        return 2;
    }
    const char *path = argv[i++];
    sockaddr_un addr {};
    addr.sun_family = AF_UNIX;
    if (std::strlen(path) >= sizeof(addr.sun_path)) {
        std::fprintf(stderr, "sylstack: socket path too long\n");
        return 2;
    }
    std::strcpy(addr.sun_path, path);
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) != 0) {
        std::fprintf(stderr, "sylstack: cannot connect to %s: %s\n", path, std::strerror(errno));
        return 2;
    }
    std::string payload;
    if (i < argc) {
        payload = argv[i];
    } else {
        char buf[4096];
        ssize_t n;
        while ((n = read(STDIN_FILENO, buf, sizeof(buf))) > 0)
            payload.append(buf, static_cast<size_t>(n));
        while (!payload.empty() && payload.back() == '\n')
            payload.pop_back();
    }
    payload.push_back('\n');
    if (!writeAll(fd, payload.data(), payload.size())) {
        close(fd);
        return 2;
    }
    if (!follow)
        shutdown(fd, SHUT_WR);
    pollfd p {fd, POLLIN, 0};
    char buf[65536];
    for (;;) {
        const int r = poll(&p, 1, follow ? -1 : 5000);
        if (r < 0 && errno == EINTR)
            continue;
        if (r <= 0)
            break;
        const ssize_t n = read(fd, buf, sizeof(buf));
        if (n < 0 && errno == EINTR)
            continue;
        if (n <= 0)
            break;
        if (!writeAll(STDOUT_FILENO, buf, static_cast<size_t>(n)))
            break;
    }
    close(fd);
    return 0;
}

bool singleInstance(const std::string &root, const QString &entry)
{
    const QByteArray hash = QCryptographicHash::hash(entry.toUtf8(), QCryptographicHash::Sha256).toHex().left(16);
    const std::string lock = root + "/" + hash.toStdString() + ".lock";
    const int fd = open(lock.c_str(), O_RDWR | O_CREAT | O_CLOEXEC, 0600);
    return fd >= 0 && flock(fd, LOCK_EX | LOCK_NB) == 0;
}

QString linkShell(const std::string &root, const QString &shellDir)
{
    const QByteArray hash = QCryptographicHash::hash(shellDir.toUtf8(), QCryptographicHash::Sha256).toHex().left(16);
    const QString base = QString::fromStdString(root) + QStringLiteral("/") + QString::fromLatin1(hash);
    QDir().mkpath(base);
    const QString link = base + QStringLiteral("/qs");
    if (QFileInfo(link).symLinkTarget() != shellDir) {
        const QString tmp = link + QStringLiteral(".") + QString::number(getpid());
        QFile::remove(tmp);
        if (symlink(shellDir.toLocal8Bit().constData(), tmp.toLocal8Bit().constData()) != 0
            || rename(tmp.toLocal8Bit().constData(), link.toLocal8Bit().constData()) != 0) {
            QFile::remove(tmp);
            if (QFileInfo(link).symLinkTarget() != shellDir) {
                std::fprintf(stderr, "sylstack: cannot link %s\n", qPrintable(link));
                std::exit(1);
            }
        }
    }
    return base;
}

void usage()
{
    std::printf("Usage: sylstack [-n] -p PATH\n"
                "       sylstack msg [-f] SOCKET [PAYLOAD]\n"
                "       sylstack --version\n\n"
                "  -p PATH   shell directory (loads shell.qml) or a .qml file inside it\n"
                "  -n        exit when this entry is already running\n"
                "  msg       send PAYLOAD (or stdin) to a unix socket and print the reply\n");
}

}

int main(int argc, char **argv)
{
    if (argc >= 2 && std::strcmp(argv[1], "msg") == 0)
        return message(argc, argv);

    QString path;
    bool once = false;
    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
            path = QString::fromLocal8Bit(argv[++i]);
        } else if (std::strcmp(argv[i], "-n") == 0) {
            once = true;
        } else if (std::strcmp(argv[i], "--version") == 0 || std::strcmp(argv[i], "-V") == 0) {
            std::printf("SylStack %s (Qt %s)\n", SYLSTACK_VERSION, qVersion());
            return 0;
        } else if (std::strcmp(argv[i], "-h") == 0 || std::strcmp(argv[i], "--help") == 0) {
            usage();
            return 0;
        } else {
            std::fprintf(stderr, "sylstack: unknown argument %s\n", argv[i]);
            usage();
            return 2;
        }
    }
    if (path.isEmpty()) {
        usage();
        return 2;
    }

    QFileInfo info(path);
    if (info.isDir())
        info = QFileInfo(QDir(info.absoluteFilePath()).filePath(QStringLiteral("shell.qml")));
    if (!info.isFile()) {
        std::fprintf(stderr, "sylstack: %s does not exist\n", qPrintable(info.filePath()));
        return 1;
    }
    const QString entry = info.canonicalFilePath();
    const QString shellDir = info.canonicalPath();
    const std::string root = runtimeRoot();
    if (once && !singleInstance(root, entry)) {
        std::fprintf(stderr, "sylstack: %s is already running\n", qPrintable(entry));
        return 0;
    }
    const QString importBase = linkShell(root, shellDir);

    struct stat err {};
    struct stat null {};
    if (fstat(STDERR_FILENO, &err) == 0 && !(stat("/dev/null", &null) == 0 && err.st_rdev == null.st_rdev && S_ISCHR(err.st_mode)))
        qputenv("QT_FORCE_STDERR_LOGGING", "1");
    if (qEnvironmentVariableIsEmpty("QT_MESSAGE_PATTERN"))
        qputenv("QT_MESSAGE_PATTERN", "%{if-warning}WARN %{endif}%{if-critical}ERROR %{endif}%{if-fatal}FATAL %{endif}%{message}");

    QQuickWindow::setDefaultAlphaBuffer(true);
    QGuiApplication::setDesktopFileName(QStringLiteral("sylvaris"));
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("sylstack"));
    QGuiApplication::setApplicationVersion(QStringLiteral(SYLSTACK_VERSION));
    QGuiApplication::setQuitOnLastWindowClosed(false);

    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, signalPipe) == 0) {
        auto *notifier = new QSocketNotifier(signalPipe[0], QSocketNotifier::Read, &app);
        QObject::connect(notifier, &QSocketNotifier::activated, &app, [] {
            char c;
            [[maybe_unused]] auto n = read(signalPipe[0], &c, 1);
            QCoreApplication::quit();
        });
        struct sigaction sa {};
        sa.sa_handler = onSignal;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = SA_RESTART;
        sigaction(SIGTERM, &sa, nullptr);
        sigaction(SIGINT, &sa, nullptr);
        sigaction(SIGHUP, &sa, nullptr);
    }
    std::signal(SIGPIPE, SIG_IGN);

    auto *stack = stack::Stack::instance();
    stack->setShellDir(shellDir);
    const QUrl url = QUrl::fromLocalFile(importBase + QStringLiteral("/qs/") + info.fileName());

    QQmlEngine *engine = nullptr;
    QObject *rootObject = nullptr;
    auto load = [&]() -> bool {
        engine = new QQmlEngine();
        engine->addImportPath(importBase);
        engine->addImageProvider(QStringLiteral("icon"), new stack::IconProvider());
        engine->addImageProvider(QStringLiteral("sylstack"), new stack::ImageStore());
        QObject::connect(engine, &QQmlEngine::quit, &app, &QCoreApplication::quit);
        QObject::connect(engine, &QQmlEngine::exit, &app, &QCoreApplication::exit);
        QQmlComponent component(engine, url);
        if (component.isError()) {
            for (const auto &e : component.errors())
                std::fprintf(stderr, "%s\n", qPrintable(e.toString()));
            return false;
        }
        rootObject = component.create();
        if (!rootObject) {
            for (const auto &e : component.errors())
                std::fprintf(stderr, "%s\n", qPrintable(e.toString()));
            return false;
        }
        stack->setReady(true);
        return true;
    };
    auto unload = [&] {
        stack->setReady(false);
        delete rootObject;
        rootObject = nullptr;
        delete engine;
        engine = nullptr;
    };

    if (!load()) {
        unload();
        return 1;
    }

    QObject::connect(stack, &stack::Stack::reloadRequested, &app, [&] {
        QTimer::singleShot(0, &app, [&] {
            unload();
            if (!load()) {
                std::fprintf(stderr, "sylstack: reload failed\n");
                QCoreApplication::exit(1);
            }
        });
    });

    const int code = app.exec();
    unload();
    return code;
}
