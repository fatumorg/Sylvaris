#pragma once

#include <QFileSystemWatcher>
#include <QJSValue>
#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlParserStatus>

namespace stack {

class DataStreamParser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("use StdioCollector or SplitParser")

public:
    using QObject::QObject;
    virtual void reset() = 0;
    virtual void parse(const QByteArray &bytes) = 0;
    virtual void end() = 0;
};

class StdioCollector : public DataStreamParser
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString text READ text NOTIFY dataChanged)
    Q_PROPERTY(QByteArray data READ data NOTIFY dataChanged)
    Q_PROPERTY(bool waitForEnd MEMBER m_waitForEnd NOTIFY waitForEndChanged)

public:
    using DataStreamParser::DataStreamParser;
    QString text() const { return QString::fromUtf8(m_data); }
    QByteArray data() const { return m_data; }
    void reset() override { m_buffer.clear(); }
    void parse(const QByteArray &bytes) override;
    void end() override;

signals:
    void dataChanged();
    void streamFinished();
    void waitForEndChanged();

private:
    QByteArray m_buffer;
    QByteArray m_data;
    bool m_waitForEnd = true;
};

class SplitParser : public DataStreamParser
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString splitMarker READ splitMarker WRITE setSplitMarker NOTIFY splitMarkerChanged)

public:
    using DataStreamParser::DataStreamParser;
    QString splitMarker() const { return m_marker; }
    void setSplitMarker(const QString &marker);
    void reset() override { m_buffer.clear(); }
    void parse(const QByteArray &bytes) override;
    void end() override;

signals:
    void read(const QString &data);
    void splitMarkerChanged();

private:
    QString m_marker = QStringLiteral("\n");
    QByteArray m_buffer;
};

class Process : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QStringList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(QString workingDirectory MEMBER m_workingDirectory NOTIFY workingDirectoryChanged)
    Q_PROPERTY(QVariantMap environment MEMBER m_environment NOTIFY environmentChanged)
    Q_PROPERTY(bool clearEnvironment MEMBER m_clearEnvironment NOTIFY clearEnvironmentChanged)
    Q_PROPERTY(bool stdinEnabled READ stdinEnabled WRITE setStdinEnabled NOTIFY stdinEnabledChanged)
    Q_PROPERTY(stack::DataStreamParser *stdout READ stdoutParser WRITE setStdoutParser NOTIFY stdoutChanged)
    Q_PROPERTY(stack::DataStreamParser *stderr READ stderrParser WRITE setStderrParser NOTIFY stderrChanged)
    Q_PROPERTY(QVariant processId READ processId NOTIFY runningChanged)

public:
    using QObject::QObject;
    ~Process() override;

    QStringList command() const { return m_command; }
    void setCommand(const QStringList &command);
    bool running() const { return m_process != nullptr; }
    bool stdinEnabled() const { return m_stdinEnabled; }
    void setStdinEnabled(bool enabled);
    void setRunning(bool running);
    DataStreamParser *stdoutParser() const { return m_stdout; }
    void setStdoutParser(DataStreamParser *parser);
    DataStreamParser *stderrParser() const { return m_stderr; }
    void setStderrParser(DataStreamParser *parser);
    QVariant processId() const;

    Q_INVOKABLE void write(const QString &data);
    Q_INVOKABLE void signal(int sig);
    Q_INVOKABLE void startDetached();
    Q_INVOKABLE void exec(const QJSValue &context);

    void classBegin() override {}
    void componentComplete() override;

signals:
    void started();
    void exited(int exitCode, int exitStatus);
    void commandChanged();
    void runningChanged();
    void workingDirectoryChanged();
    void environmentChanged();
    void clearEnvironmentChanged();
    void stdinEnabledChanged();
    void stdoutChanged();
    void stderrChanged();

private:
    void startIfWanted();
    void finished(int code, QProcess::ExitStatus status);
    QProcessEnvironment environmentFor() const;

    QStringList m_command;
    QString m_workingDirectory;
    QVariantMap m_environment;
    bool m_clearEnvironment = false;
    bool m_stdinEnabled = false;
    bool m_want = false;
    bool m_complete = false;
    QPointer<DataStreamParser> m_stdout;
    QPointer<DataStreamParser> m_stderr;
    QProcess *m_process = nullptr;
};

namespace FileViewError {
Q_NAMESPACE
QML_ELEMENT
enum Enum { Success = 0, Unknown = 1, FileNotFound = 2, PermissionDenied = 3, NotAFile = 4 };
Q_ENUM_NS(Enum)
}

class FileViewCore : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool preload MEMBER m_preload NOTIFY optionsChanged)
    Q_PROPERTY(bool blockLoading MEMBER m_blockLoading NOTIFY optionsChanged)
    Q_PROPERTY(bool blockAllReads MEMBER m_blockLoading NOTIFY optionsChanged)
    Q_PROPERTY(bool blockWrites MEMBER m_blockWrites NOTIFY optionsChanged)
    Q_PROPERTY(bool atomicWrites MEMBER m_atomicWrites NOTIFY optionsChanged)
    Q_PROPERTY(bool printErrors MEMBER m_printErrors NOTIFY optionsChanged)
    Q_PROPERTY(bool watchChanges READ watchChanges WRITE setWatchChanges NOTIFY optionsChanged)
    Q_PROPERTY(QString __text READ text NOTIFY textChanged)

public:
    using QObject::QObject;
    ~FileViewCore() override;

    QString path() const { return m_path; }
    void setPath(const QString &path);
    bool watchChanges() const { return m_watch; }
    void setWatchChanges(bool watch);
    QString text();

    Q_INVOKABLE void reload();
    Q_INVOKABLE void setText(const QString &text);

    void classBegin() override {}
    void componentComplete() override;
    void checkChanged();

signals:
    void pathChanged();
    void optionsChanged();
    void textChanged();
    void loaded();
    void loadFailed(int error);
    void saved();
    void saveFailed(int error);
    void fileChanged();

private:
    void schedule();
    void load();
    QByteArray signature() const;

    QString m_path;
    QString m_text;
    QString m_loadedPath;
    QByteArray m_signature;
    bool m_preload = true;
    bool m_blockLoading = false;
    bool m_blockWrites = false;
    bool m_atomicWrites = true;
    bool m_printErrors = true;
    bool m_watch = false;
    bool m_complete = false;
    bool m_scheduled = false;
    bool m_dirty = false;
};

class Socket : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool connected READ connected WRITE setConnected NOTIFY connectedChanged)
    Q_PROPERTY(stack::DataStreamParser *parser READ parser WRITE setParser NOTIFY parserChanged)

public:
    using QObject::QObject;
    ~Socket() override;

    bool connected() const { return m_socket && m_socket->state() == QLocalSocket::ConnectedState; }
    void setConnected(bool connected);
    DataStreamParser *parser() const { return m_parser; }
    void setParser(DataStreamParser *parser);
    void attach(QLocalSocket *socket);

    Q_INVOKABLE void write(const QString &data);
    Q_INVOKABLE void flush();

signals:
    void connectedChanged();
    void parserChanged();
    void error(int error);

private:
    QPointer<QLocalSocket> m_socket;
    QPointer<DataStreamParser> m_parser;
};

class SocketServer : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    QML_ELEMENT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QQmlComponent *handler READ handler WRITE setHandler NOTIFY handlerChanged)

public:
    using QObject::QObject;
    ~SocketServer() override;

    bool active() const { return m_active; }
    void setActive(bool active);
    QString path() const { return m_path; }
    void setPath(const QString &path);
    QQmlComponent *handler() const { return m_handler; }
    void setHandler(QQmlComponent *handler);

    void classBegin() override {}
    void componentComplete() override;

signals:
    void activeChanged();
    void pathChanged();
    void handlerChanged();

private:
    bool privateParent() const;
    void sync();
    void accept();

    bool m_active = false;
    bool m_complete = false;
    QString m_path;
    QPointer<QQmlComponent> m_handler;
    QLocalServer *m_server = nullptr;
};

}
