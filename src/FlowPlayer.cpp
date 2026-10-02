
#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <QtQuick>
#include <sailfishapp.h>
#include <QObject>
#include <QTextCodec>
#include <QSettings>
#include <QStandardPaths>

#include "version.h"

#include "playlistmanager.h"
#include "utils.h"
#include "coversearch.h"
#include "meta.h"
#include "lfm.h"
#include "datos.h"
#include "missing.h"
#include "database.h"
#include "radios.h"
#include "player.h"

bool isDBOpened;
bool databaseWorking;

int main(int argc, char *argv[])
{
    QTextCodec *linuxCodec = QTextCodec::codecForName("UTF-8");
    QTextCodec::setCodecForLocale(linuxCodec);

    QGuiApplication *app = SailfishApp::application(argc, argv);
    // Must match OrganizationName/ApplicationName in the [X-Sailjail] section of
    // the .desktop file: the sandbox only exposes ~/.config, ~/.cache and
    // ~/.local/share/<OrganizationName>/<ApplicationName>.
    app->setOrganizationName("io.github.spidernik84");
    app->setApplicationName("flowplayer-ng");

    QString lang;
    QTranslator translator;

    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    lang = settings.value("Language", "undefined").toString();

    // One-time config migration: default TrackOrder changed from "title" to "number".
    // Runs before any QML loads, so loadSongs() sees the new value on first launch.
    if (!settings.contains("ConfigVersion")) {
        const QString existingTrackOrder = settings.value("TrackOrder", "").toString();
        if (existingTrackOrder.isEmpty() || existingTrackOrder == "title") {
            settings.setValue("TrackOrder", "number");
        }
        settings.setValue("ConfigVersion", 1);
        settings.sync();
    }


    if (lang=="undefined")
    {
        lang=  QLocale().name();
        qDebug() << "Getting language from locale:" << lang;
    }
    else
    {
        qDebug() << "Stored language: " << lang;
    }

    const QString translationsDir = SailfishApp::pathTo("translations").toLocalFile();
    if (QFile::exists(translationsDir + "/" + lang + ".qm"))
        translator.load(translationsDir + "/" + lang);
    else
        translator.load(translationsDir + "/en");

    app->installTranslator(&translator);

    // ensure the media cache dir is created
    const QString mediaCacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art";
    QDir().mkpath(mediaCacheDir);

    QScopedPointer<QQuickView> window(SailfishApp::createView());
    window->setTitle("FlowPlayer NG");

    window->engine()->addImportPath(SailfishApp::pathTo("qml").toLocalFile());
    window->rootContext()->setContextProperty("appVersion", VERSION);
    bool hasPickers = false;
    for (const QString &path : window->engine()->importPathList()) {
        hasPickers = hasPickers || QFile::exists(path + "/Sailfish/Pickers");
    }
    window->rootContext()->setContextProperty("hasPickers", hasPickers);

    qmlRegisterType<Utils>("FlowPlayer", 1, 0, "Utils");
    qmlRegisterType<CoverSearch>("FlowPlayer", 1, 0, "CoverSearch");
    qmlRegisterType<Meta>("FlowPlayer", 1, 0, "Meta");
    qmlRegisterType<LFM>("FlowPlayer", 1, 0, "LFM");
    qmlRegisterType<Datos>("FlowPlayer", 1, 0, "Datos");
    qmlRegisterType<PlaylistManager>("FlowPlayer", 1, 0, "MyPlaylistManager");
    qmlRegisterType<Missing>("FlowPlayer", 1, 0, "Missing");
    qmlRegisterType<Database>("FlowPlayer", 1, 0, "Database");
    qmlRegisterType<Radios>("FlowPlayer", 1, 0, "Radios");

    qmlRegisterType<Player>("FlowPlayer", 1, 0, "Player");

    //qmlRegisterType<Playlist>("FlowPlayer", 1, 0, "Playlist");
    //qmlRegisterType<MyPlaylist>("FlowPlayer", 1, 0, "MyPlaylist");
    //qmlRegisterType<MyPlaylists>("FlowPlayer", 1, 0, "MyPlaylists");
    //qmlRegisterType<MusicModel>("FlowPlayer", 1, 0, "MusicModel");

    window->setSource(SailfishApp::pathTo("qml/harbour-flowplayer-ng.qml"));

    window->showFullScreen();
    return app->exec();
    qDebug() << "Good bye!";
}

