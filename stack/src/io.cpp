#include "io.h"

#include "scope.h"
#include "stack.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMultiHash>
#include <QSaveFile>
#include <QTimer>
#include <QUrl>

#include <csignal>
#include <sys/stat.h>
#include <unistd.h>

namespace stack {

void StdioCollector::parse(const QByteArray &bytes)
{
    m_buffer.append(bytes);
    if (!m_waitForEnd) {
        m_data = m_buffer;
        emit dataChanged();
    }
}

void StdioCollector::end()
{
    if (m_waitForEnd || m_data != m_buffer) {
        m_data = m_buffer;
        emit dataChanged();
    }
    m_buffer.clear();
    emit streamFinished();
}

void SplitParser::setSplitMarker(const QString &marker)
{
    if (marker == m_marker)
        return;
    m_marker = marker;
    emit splitMarkerChanged();
}

void SplitParser::parse(const QByteArray &bytes)
{
    m_buffer.append(bytes);
    if (m_marker.isEmpty()) {
        const QString all = QString::fromUtf8(m_buffer);
        m_buffer.clear();
        emit read(all);
        return;
    }
    const QByteArray marker = m_marker.toUtf8();
    QPointer<SplitParser> self(this);
    qsizetype at;
    while (self && (at = m_buffer.indexOf(marker)) >= 0) {
        const QString piece = QString::fromUtf8(m_buffer.constData(), at);
        m_buffer.remove(0, at + marker.size());
        emit read(piece);
    }
}

void SplitParser::end()
{
    if (!m_buffer.isEmpty()) {
        const QString rest = QString::fromUtf8(m_buffer);
        m_buffer.clear();
        emit read(rest);
    }
}

Process::~Process()
{
    if (m_process) {
        QProcess *p = m_process;
        m_process = nullptr;
        p->disconnect(this);
        p->setParent(nullptr);
        QObject::connect(p, &QProcess::finished, p, &QObject::deleteLater);
        p->kill();
    }
}

void Process::setCommand(const QStringList &command)
{
    if (command == m_command)
        return;
    m_command = command;
    emit commandChanged();
}

void Process::setRunning(bool running)
{
    m_want = running;
    if (running)
        startIfWanted();
    else if (m_process)
        m_process->terminate();
}

void Process::setStdoutParser(DataStreamParser *parser)
{
    if (parser == m_stdout)
        return;
    m_stdout = parser;
    emit stdoutChanged();
}

void Process::setStderrParser(DataStreamParser *parser)
{
    if (parser == m_stderr)
        return;
    m_stderr = parser;
    emit stderrChanged();
}

QVariant Process::processId() const
{
    if (!m_process)
        return QVariant::fromValue(nullptr);
    return QVariant::fromValue(m_process->processId());
}

void Process::componentComplete()
{
    m_complete = true;
    Stack::instance()->whenReady(this, [this] { startIfWanted(); });
}

QProcessEnvironment Process::environmentFor() const
{
    QProcessEnvironment e = m_clearEnvironment ? QProcessEnvironment() : QProcessEnvironment::systemEnvironment();
    for (auto it = m_environment.cbegin(); it != m_environment.cend(); ++it) {
        if (it.value().isNull())
            e.remove(it.key());
        else
            e.insert(it.key(), it.value().toString());
    }
    return e;
}

void Process::startIfWanted()
{
    if (m_process || !m_want || !m_complete || !Stack::instance()->isReady())
        return;
    if (m_command.isEmpty() || m_command.first().isEmpty()) {
        qWarning("sylstack: cannot start a process with an empty command");
        m_want = false;
        return;
    }
    m_want = false;
    m_process = new QProcess(this);
    QProcess *p = m_process;
    if (!m_workingDirectory.isEmpty())
        p->setWorkingDirectory(m_workingDirectory);
    if (m_clearEnvironment || !m_environment.isEmpty())
        p->setProcessEnvironment(environmentFor());
    if (m_stdout)
        m_stdout->reset();
    else
        p->setStandardOutputFile(QProcess::nullDevice());
    if (m_stderr)
        m_stderr->reset();
    else
        p->setStandardErrorFile(QProcess::nullDevice());
    if (!m_stdinEnabled)
        p->setStandardInputFile(QProcess::nullDevice());
    connect(p, &QProcess::started, this, [this] {
        emit runningChanged();
        emit started();
    });
    connect(p, &QProcess::readyReadStandardOutput, this, [this, p] {
        const QByteArray bytes = p->readAllStandardOutput();
        if (m_stdout)
            m_stdout->parse(bytes);
    });
    connect(p, &QProcess::readyReadStandardError, this, [this, p] {
        const QByteArray bytes = p->readAllStandardError();
        if (m_stderr)
            m_stderr->parse(bytes);
    });
    connect(p, &QProcess::finished, this, &Process::finished);
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || p != m_process)
            return;
        qWarning("sylstack: could not start %s", qPrintable(m_command.first()));
        m_process = nullptr;
        p->deleteLater();
        emit runningChanged();
    });
    QStringList args = m_command;
    const QString program = args.takeFirst();
    p->start(program, args);
}

void Process::finished(int code, QProcess::ExitStatus status)
{
    QProcess *p = m_process;
    if (!p)
        return;
    const QByteArray out = m_stdout ? p->readAllStandardOutput() : QByteArray();
    const QByteArray err = m_stderr ? p->readAllStandardError() : QByteArray();
    m_process = nullptr;
    p->deleteLater();
    if (m_stdout) {
        if (!out.isEmpty())
            m_stdout->parse(out);
        m_stdout->end();
    }
    if (m_stderr) {
        if (!err.isEmpty())
            m_stderr->parse(err);
        m_stderr->end();
    }
    emit exited(code, static_cast<int>(status));
    emit runningChanged();
    startIfWanted();
}

void Process::setStdinEnabled(bool enabled)
{
    if (enabled == m_stdinEnabled)
        return;
    m_stdinEnabled = enabled;
    if (!enabled && m_process)
        m_process->closeWriteChannel();
    emit stdinEnabledChanged();
}

void Process::write(const QString &data)
{
    if (m_process && m_stdinEnabled)
        m_process->write(data.toUtf8());
}

void Process::signal(int sig)
{
    if (m_process && m_process->processId() > 0)
        ::kill(static_cast<pid_t>(m_process->processId()), sig);
}

void Process::startDetached()
{
    if (m_command.isEmpty() || m_command.first().isEmpty())
        return;
    QProcess p;
    QStringList args = m_command;
    p.setProgram(args.takeFirst());
    p.setArguments(args);
    if (!m_workingDirectory.isEmpty())
        p.setWorkingDirectory(m_workingDirectory);
    if (m_clearEnvironment || !m_environment.isEmpty())
        p.setProcessEnvironment(environmentFor());
    p.setStandardInputFile(QProcess::nullDevice());
    p.setStandardOutputFile(QProcess::nullDevice());
    p.setStandardErrorFile(QProcess::nullDevice());
    p.startDetached();
}

void Process::exec(const QJSValue &context)
{
    setRunning(false);
    QJSValue list = context;
    if (!context.isArray() && context.isObject()) {
        list = context.property(QStringLiteral("command"));
        if (context.hasProperty(QStringLiteral("workingDirectory")))
            m_workingDirectory = context.property(QStringLiteral("workingDirectory")).toString();
        if (context.hasProperty(QStringLiteral("environment")))
            m_environment = context.property(QStringLiteral("environment")).toVariant().toMap();
        if (context.hasProperty(QStringLiteral("clearEnvironment")))
            m_clearEnvironment = context.property(QStringLiteral("clearEnvironment")).toBool();
    }
    if (list.isArray()) {
        QStringList words;
        const int n = list.property(QStringLiteral("length")).toInt();
        for (int i = 0; i < n; i++)
            words << list.property(i).toString();
        setCommand(words);
    }
    setRunning(true);
}

namespace {

class FileWatch : public QObject
{
public:
    static FileWatch *instance()
    {
        static FileWatch *self = new FileWatch();
        return self;
    }

    void add(FileViewCore *view, const QString &path)
    {
        if (path.isEmpty())
            return;
        const QString dir = QFileInfo(path).absolutePath();
        if (!m_files.contains(path, view))
            m_files.insert(path, view);
        if (!m_dirs.contains(dir, view))
            m_dirs.insert(dir, view);
        if (QFileInfo::exists(path) && !m_watcher.files().contains(path))
            m_watcher.addPath(path);
        if (QFileInfo::exists(dir) && !m_watcher.directories().contains(dir))
            m_watcher.addPath(dir);
    }

    void remove(FileViewCore *view, const QString &path)
    {
        if (path.isEmpty())
            return;
        const QString dir = QFileInfo(path).absolutePath();
        m_files.remove(path, view);
        m_dirs.remove(dir, view);
        if (!m_files.contains(path))
            m_watcher.removePath(path);
        if (!m_dirs.contains(dir))
            m_watcher.removePath(dir);
    }

private:
    FileWatch()
    {
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) { touched(m_files.values(path)); });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &dir) { touched(m_dirs.values(dir)); });
    }

    void touched(const QList<FileViewCore *> &views)
    {
        for (FileViewCore *v : views) {
            const QString path = m_files.key(v);
            if (!path.isEmpty() && QFileInfo::exists(path) && !m_watcher.files().contains(path))
                m_watcher.addPath(path);
        }
        for (FileViewCore *v : views)
            QMetaObject::invokeMethod(v, [v] { v->checkChanged(); }, Qt::QueuedConnection);
    }

    QFileSystemWatcher m_watcher;
    QMultiHash<QString, FileViewCore *> m_files;
    QMultiHash<QString, FileViewCore *> m_dirs;
};

QString localPath(const QString &path)
{
    if (path.startsWith(QStringLiteral("file:")))
        return QUrl(path).toLocalFile();
    return path;
}

}

FileViewCore::~FileViewCore()
{
    if (m_watch)
        FileWatch::instance()->remove(this, m_path);
}

void FileViewCore::setPath(const QString &path)
{
    const QString local = localPath(path);
    if (local == m_path)
        return;
    if (m_watch)
        FileWatch::instance()->remove(this, m_path);
    m_path = local;
    if (m_watch)
        FileWatch::instance()->add(this, m_path);
    m_dirty = true;
    emit pathChanged();
    if (m_path.isEmpty()) {
        m_loadedPath.clear();
        if (!m_text.isEmpty()) {
            m_text.clear();
            emit textChanged();
        }
        return;
    }
    if (m_preload)
        schedule();
}

void FileViewCore::setWatchChanges(bool watch)
{
    if (watch == m_watch)
        return;
    m_watch = watch;
    if (m_watch)
        FileWatch::instance()->add(this, m_path);
    else
        FileWatch::instance()->remove(this, m_path);
    emit optionsChanged();
}

void FileViewCore::componentComplete()
{
    m_complete = true;
    if (m_dirty && m_preload)
        schedule();
}

QString FileViewCore::text()
{
    if (m_dirty && !m_path.isEmpty() && (m_blockLoading || !m_preload || m_loadedPath.isEmpty()))
        load();
    return m_text;
}

void FileViewCore::reload()
{
    m_dirty = true;
    schedule();
}

void FileViewCore::schedule()
{
    if (m_scheduled || !m_complete)
        return;
    m_scheduled = true;
    QMetaObject::invokeMethod(this, [this] {
        m_scheduled = false;
        if (m_dirty)
            load();
    }, Qt::QueuedConnection);
}

QByteArray FileViewCore::signature() const
{
    struct stat st {};
    if (::stat(QFile::encodeName(m_path).constData(), &st) != 0)
        return QByteArrayLiteral("missing");
    return QByteArray::number(static_cast<qulonglong>(st.st_ino)) + ':' + QByteArray::number(static_cast<qlonglong>(st.st_size)) + ':'
        + QByteArray::number(static_cast<qlonglong>(st.st_mtim.tv_sec)) + '.' + QByteArray::number(static_cast<qlonglong>(st.st_mtim.tv_nsec));
}

void FileViewCore::checkChanged()
{
    if (m_path.isEmpty())
        return;
    const QByteArray next = signature();
    if (next == m_signature)
        return;
    m_signature = next;
    emit fileChanged();
}

void FileViewCore::load()
{
    m_dirty = false;
    if (m_path.isEmpty())
        return;
    m_signature = signature();
    QFile file(m_path);
    const QFileInfo info(m_path);
    int error = FileViewError::Success;
    if (!info.exists())
        error = FileViewError::FileNotFound;
    else if (!info.isFile())
        error = FileViewError::NotAFile;
    else if (!file.open(QIODevice::ReadOnly))
        error = file.error() == QFileDevice::PermissionsError ? FileViewError::PermissionDenied : FileViewError::Unknown;
    if (error != FileViewError::Success) {
        if (m_printErrors && error != FileViewError::FileNotFound)
            qWarning("sylstack: could not read %s", qPrintable(m_path));
        m_loadedPath.clear();
        if (!m_text.isEmpty()) {
            m_text.clear();
            emit textChanged();
        }
        emit loadFailed(error);
        return;
    }
    const QString next = QString::fromUtf8(file.readAll());
    m_loadedPath = m_path;
    if (next != m_text) {
        m_text = next;
        emit textChanged();
    }
    emit loaded();
}

void FileViewCore::setText(const QString &text)
{
    if (m_path.isEmpty())
        return;
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    const QByteArray bytes = text.toUtf8();
    bool ok = false;
    QFileDevice::FileError err = QFileDevice::NoError;
    if (m_atomicWrites) {
        QSaveFile file(m_path);
        ok = file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size() && file.commit();
        err = file.error();
    } else {
        QFile file(m_path);
        ok = file.open(QIODevice::WriteOnly | QIODevice::Truncate) && file.write(bytes) == bytes.size();
        err = file.error();
    }
    if (!ok) {
        if (m_printErrors)
            qWarning("sylstack: could not write %s", qPrintable(m_path));
        emit saveFailed(err == QFileDevice::PermissionsError ? FileViewError::PermissionDenied : FileViewError::Unknown);
        return;
    }
    m_loadedPath = m_path;
    m_dirty = false;
    if (text != m_text) {
        m_text = text;
        emit textChanged();
    }
    if (m_watch)
        FileWatch::instance()->add(this, m_path);
    emit saved();
}

Socket::~Socket()
{
    if (m_socket) {
        m_socket->disconnect(this);
        m_socket->abort();
        m_socket->deleteLater();
    }
}

void Socket::setConnected(bool connected)
{
    if (!connected && m_socket) {
        m_socket->flush();
        m_socket->disconnectFromServer();
    }
}

void Socket::setParser(DataStreamParser *parser)
{
    if (parser == m_parser)
        return;
    m_parser = parser;
    if (m_parser)
        m_parser->reset();
    emit parserChanged();
}

void Socket::attach(QLocalSocket *socket)
{
    m_socket = socket;
    socket->setParent(this);
    connect(socket, &QLocalSocket::readyRead, this, [this] {
        if (!m_socket)
            return;
        const QByteArray bytes = m_socket->readAll();
        if (m_parser)
            m_parser->parse(bytes);
    });
    connect(socket, &QLocalSocket::disconnected, this, [this] {
        if (m_parser)
            m_parser->end();
        emit connectedChanged();
        deleteLater();
    });
    connect(socket, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError e) {
        if (e != QLocalSocket::PeerClosedError)
            emit error(static_cast<int>(e));
    });
    emit connectedChanged();
}

void Socket::write(const QString &data)
{
    if (m_socket && m_socket->state() == QLocalSocket::ConnectedState)
        m_socket->write(data.toUtf8());
}

void Socket::flush()
{
    if (m_socket)
        m_socket->flush();
}

SocketServer::~SocketServer()
{
    if (m_server) {
        m_server->close();
        QLocalServer::removeServer(m_path);
    }
}

void SocketServer::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;
    emit activeChanged();
    sync();
}

void SocketServer::setPath(const QString &path)
{
    if (path == m_path)
        return;
    if (m_server) {
        m_server->close();
        QLocalServer::removeServer(m_path);
        delete m_server;
        m_server = nullptr;
    }
    m_path = path;
    emit pathChanged();
    sync();
}

void SocketServer::setHandler(QQmlComponent *handler)
{
    if (handler == m_handler)
        return;
    m_handler = handler;
    emit handlerChanged();
}

void SocketServer::componentComplete()
{
    m_complete = true;
    sync();
}

bool SocketServer::privateParent() const
{
    const QByteArray dir = QFile::encodeName(QFileInfo(m_path).absolutePath());
    mkdir(dir.constData(), 0700);
    struct stat st {};
    if (lstat(dir.constData(), &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != getuid() || (st.st_mode & 022)) {
        qWarning("sylstack: refusing to listen on %s, its directory is not private", qPrintable(m_path));
        return false;
    }
    return true;
}

void SocketServer::sync()
{
    if (!m_complete)
        return;
    if (m_active && !m_path.isEmpty() && !m_server) {
        if (!privateParent())
            return;
        m_server = new QLocalServer(this);
        m_server->setSocketOptions(QLocalServer::UserAccessOption);
        QLocalServer::removeServer(m_path);
        connect(m_server, &QLocalServer::newConnection, this, &SocketServer::accept);
        if (!m_server->listen(m_path)) {
            qWarning("sylstack: could not listen on %s: %s", qPrintable(m_path), qPrintable(m_server->errorString()));
            delete m_server;
            m_server = nullptr;
        }
    } else if ((!m_active || m_path.isEmpty()) && m_server) {
        m_server->close();
        QLocalServer::removeServer(m_path);
        delete m_server;
        m_server = nullptr;
    }
}

void SocketServer::accept()
{
    while (m_server && m_server->hasPendingConnections()) {
        QLocalSocket *conn = m_server->nextPendingConnection();
        Socket *socket = m_handler ? qobject_cast<Socket *>(createFrom(m_handler, this, {})) : nullptr;
        if (!socket) {
            conn->abort();
            conn->deleteLater();
            continue;
        }
        socket->attach(conn);
        if (conn->bytesAvailable() > 0)
            emit conn->readyRead();
    }
}

}
