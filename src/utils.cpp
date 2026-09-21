#include "utils.h"
#include <QString>
#include <QFileInfo>
#include <QDir>
#include <QImage>
#include <QNetworkConfigurationManager>
#include <QSettings>
#include <QStandardPaths>

#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>

// File-scope state shared between request setup and the reply handler
QString albumArtUrl, albumArtArtist, albumArtAlbum;
QString currentArtist, currentSong;
QString searchServer;

// Workaround for bluetooth headphones playback control issues
void Utils::restartMprisProxy()
{
    QProcess::startDetached("systemctl",
        QStringList() << "--user" << "restart" << "mpris-proxy");
}

// LRC lines start with one or more [mm:ss.xx] or [mm:ss.xxx] timestamps.
// Strip them so the plain-text UI in Lyrics.qml renders cleanly. If you
// later want to highlight the current line, keep the raw text instead and
// parse in QML.
static QString stripLrcTimestamps(const QString &input)
{
    QRegularExpression re("\\[\\d{1,2}:\\d{2}([.:]\\d{1,3})?\\]");
    QString out;
    const QStringList lines = input.split('\n');
    for (const QString &line : lines) {
        QString cleaned = line;
        cleaned.remove(re);
        cleaned = cleaned.trimmed();
        if (!cleaned.isEmpty())
            out += cleaned + "\n";
    }
    return out.trimmed();
}

Utils::Utils(QQuickItem *parent)
    : QQuickItem(parent)
{
    datos = new QNetworkAccessManager(this);
    connect(datos, SIGNAL(finished(QNetworkReply*)), this, SLOT(downloaded(QNetworkReply*)));
    currentLyrics = "";
}

bool Utils::isOnline()
{
    QNetworkConfigurationManager mgr;
    QList<QNetworkConfiguration> activeConfigs = mgr.allConfigurations(QNetworkConfiguration::Active);
    if (activeConfigs.count() > 0)
        return true;
    else
        return false;
}

bool Utils::isFav(QString filename)
{
    return executeQueryCheckCount(QString("select * from tracks where url='%1' and fav=1").arg(filename));
}

void Utils::favSong(QString filename, bool fav)
{
    QString val = fav? "1" : "NULL";
    executeQuery(QString("update tracks set fav=%1 where url='%2'").arg(val).arg(filename));
}

void Utils::readLyrics(QString artist, QString song)
{
    QString art = cleanItem(artist);
    QString sng = cleanItem(song);
    if ( ( art!="" ) && ( sng!="" ) )
    {
        QString th1 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/lyrics/"+art+"-"+sng+".txt";

        if ( QFileInfo(th1).exists() )
        {
            QString lines;
            QFile data(th1);
            if (data.open(QFile::ReadOnly | QFile::Truncate))
            {
                QTextStream out(&data);
                while ( !out.atEnd() )
                    lines += out.readLine()+"\n";
            }
            data.close();
            currentLyrics = lines.replace("\n", "<br>");
            m_noLyrics = false;
        }
        else
        {
            currentLyrics =  tr("No lyrics found");
            m_noLyrics = true;
        }
    }
    m_lyricsonline = false;
    emit lyricsChanged();
}

QString Utils::thumbnail(QString artist, QString album, QString count)
{
    QString art = count=="1"? artist : album;
    QString alb = album;

    QString th1 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(art, alb) + ".jpeg";

    if (!QFileInfo(th1).exists()) {
        QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(alb, alb) + ".jpeg";
        if (QFileInfo(th2).exists())
            return th2;
    }

    return th1;
}

QString Utils::thumbnailArtist(QString artist)
{
    QString th1 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/artist-"+ hash(artist) + ".jpeg";
    return th1;
}

QString Utils::accents(QString data)
{
    QString str = QString::fromUtf8(data.toUtf8());
    str.replace("á", "a");
    str.replace("é", "e");
    str.replace("í", "i");
    str.replace("ó", "o");
    str.replace("ú", "u");
    return str;
}

void Utils::getLyrics(QString artist, QString song, QString album, int duration)
{
    // Offline guard first — bail before touching any request state so
    // the QML side doesn't retry in a loop.
    if (!isOnline()) {
        qDebug() << "getLyrics: no active network connection";
        currentLyrics = tr("No internet connection.") + "<br><br>" +
                        tr("Connect to a network and try again.");
        m_lyricsonline = false;
        m_noLyrics = true;
        emit lyricsChanged();
        return;
    }

    m_lastArtist = artist;
    m_lastSong   = song;
    searchServer = "lrclib-get";

    QString url = "https://lrclib.net/api/get";
    url += "?artist_name=" + QString(QUrl::toPercentEncoding(artist));
    url += "&track_name="  + QString(QUrl::toPercentEncoding(song));
    if (!album.isEmpty())
        url += "&album_name=" + QString(QUrl::toPercentEncoding(album));
    if (duration > 0 && duration < 3600)   // sanity: seconds, not ms
        url += "&duration=" + QString::number(duration);

    qDebug() << "LRCLIB get:" << url;

    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "FlowPlayer/1.0 (https://github.com/sailfishos-applications/flowplayer)");
    reply = datos->get(req);
}

void Utils::downloaded(QNetworkReply *respuesta)
{
    // --- Error paths ---
    if (respuesta->error() != QNetworkReply::NoError)
    {
        const QNetworkReply::NetworkError err = respuesta->error();
        qDebug() << "network error:" << err << "for" << searchServer;

        if (searchServer == "albumart") {
            albumArtUrl = "";
            return;
        }

        // Network-level failures (as opposed to a clean 404) mean we should
        // not fall through to the fuzzy search — it would fail too. Show
        // the user the same friendly message the offline guard emits.
        if (searchServer.startsWith("lrclib")) {
            if (err == QNetworkReply::HostNotFoundError ||
                err == QNetworkReply::TimeoutError ||
                err == QNetworkReply::NetworkSessionFailedError ||
                err == QNetworkReply::TemporaryNetworkFailureError ||
                err == QNetworkReply::UnknownNetworkError)
            {
                currentLyrics = tr("No internet connection.") + "<br><br>" +
                                tr("Connect to a network and try again.");
                m_lyricsonline = false;
                m_noLyrics = true;
                emit lyricsChanged();
                return;
            }
        }

        if (searchServer == "lrclib-get") {
            // Exact match failed (usually 404). Try fuzzy search using the
            // artist/song stored when the request was built.
            qDebug() << "LRCLIB exact miss, searching for"
                     << m_lastArtist << "-" << m_lastSong;

            searchServer = "lrclib-search";
            QString url = "https://lrclib.net/api/search";
            url += "?artist_name=" + QString(QUrl::toPercentEncoding(m_lastArtist));
            url += "&track_name="  + QString(QUrl::toPercentEncoding(m_lastSong));

            QNetworkRequest req{QUrl(url)};
            req.setHeader(QNetworkRequest::UserAgentHeader,
                          "FlowPlayer/1.0 (https://github.com/sailfishos-applications/flowplayer)");
            reply = datos->get(req);
            return;
        }

        if (searchServer == "lrclib-search") {
            currentLyrics = tr("No lyrics found");
            m_lyricsonline = true;
            m_noLyrics = true;
            emit lyricsChanged();
            return;
        }

        // Generic fallback for anything else
        currentLyrics = tr("Error fetching lyrics");
        m_lyricsonline = true;
        m_noLyrics = true;
        emit lyricsChanged();
        return;
    }

    // --- Success paths ---
    if (searchServer == "albumart")
    {
        QString datos1 = respuesta->readAll();
        QString tmp = datos1;
        int x = tmp.indexOf("<image size=\"mega\">");
        tmp.remove(0, x + 19);
        x = tmp.indexOf("<");
        tmp.remove(x, tmp.length() - x);
        tmp = tmp.trimmed();
        if (tmp == "") {
            banner = tr("Album cover not found");
            emit bannerChanged();
            return;
        }
        return;
    }

    if (searchServer == "lrclib-get") {
        applyLrcLibResponse(respuesta->readAll(), false);
        return;
    }

    if (searchServer == "lrclib-search") {
        applyLrcLibResponse(respuesta->readAll(), true);
        return;
    }
}

void Utils::applyLrcLibResponse(const QByteArray &body, bool isArray)
{
    QJsonDocument doc = QJsonDocument::fromJson(body);

    QJsonObject obj;
    if (isArray) {
        QJsonArray arr = doc.array();
        if (arr.isEmpty()) {
            currentLyrics = tr("No lyrics found");
            m_lyricsonline = true;
            m_noLyrics = true;
            emit lyricsChanged();
            return;
        }
        // Prefer first entry that has syncedLyrics; otherwise first entry.
        obj = arr.first().toObject();
        for (const QJsonValue &v : arr) {
            QJsonObject o = v.toObject();
            if (!o.value("syncedLyrics").toString().isEmpty()) {
                obj = o;
                break;
            }
        }
    } else {
        obj = doc.object();
    }

    const bool instrumental = obj.value("instrumental").toBool(false);
    const QString synced = obj.value("syncedLyrics").toString();
    const QString plain  = obj.value("plainLyrics").toString();
    QString text = !synced.isEmpty() ? synced : plain;

    qDebug() << "LRCLIB result: instrumental =" << instrumental
             << "synced len =" << synced.length()
             << "plain len =" << plain.length();

    if (text.isEmpty() || instrumental) {
        currentLyrics = tr("No lyrics found");
        m_noLyrics = true;
    } else {
        text = stripLrcTimestamps(text);
        currentLyrics = text.replace("\n", "<br>");
        m_noLyrics = false;
    }
    m_lyricsonline = true;
    emit lyricsChanged();
}

// ---------------------------------------------------------------------------
// Everything from here down is unchanged from your original file.
// ---------------------------------------------------------------------------

void Utils::saveLyrics(QString artist, QString song, QString lyrics)
{
    QDir d;
    d.mkdir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/lyrics");

    QString art = cleanItem(artist);
    QString sng = cleanItem(song);
    QString f = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/lyrics/"+art+"-"+sng+".txt";

    if ( QFileInfo(f).exists() )
        QFile::remove(f);
    QFile file(f);
    file.open( QIODevice::Truncate | QIODevice::Text | QIODevice::ReadWrite);
    QTextStream out(&file);
    out << lyrics;
    file.close();
    m_lyricsonline = false;
    emit lyricsChanged();
}

void Utils::saveLyrics2(QString artist, QString song, QString lyrics)
{
    QDir d;
    d.mkdir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/lyrics");

    QString art = cleanItem(artist);
    QString sng = cleanItem(song);
    QString f = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/lyrics/"+art+"-"+sng+".txt";

    if ( QFileInfo(f).exists() )
        QFile::remove(f);
    QFile file(f);
    file.open( QIODevice::Truncate | QIODevice::Text | QIODevice::ReadWrite);
    QTextStream out(&file);
    out << lyrics;
    file.close();
}

void Utils::cancelFetching()
{
    if ( reply && reply->isRunning() )
        reply->abort();
    emit fetchCanceled();
}

void Utils::getAlbumArt(QString artist, QString album)
{
    emit downloadingCover();
    searchServer = "albumart";
    albumArtArtist = artist;
    albumArtAlbum = album;
    QString url = "http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=7f338c7458e7d1a9a6204221ff904ba1";
    reply = datos->get(QNetworkRequest(QUrl(url+"&artist="+albumArtArtist+"&album="+albumArtAlbum)));
}

void Utils::Finished(int requestId, bool)
{
    if ( searchServer == "albumart" )
    {
        if (Request==requestId)
        {
            QImage img;
            img.loadFromData(bytes);

            QString th1 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-" + doubleHash(albumArtArtist, albumArtAlbum) + ".jpeg";
            if ( QFileInfo(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/preview.jpeg").exists() )
                removePreview();
            img.save(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/preview.jpeg");
            downloadedAlbumArt = th1;
            emit coverDownloaded();
        }
    }
}

void Utils::removePreview()
{
    QFile f(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/preview.jpeg");
    f.remove();
}

void Utils::setSettings(QString set, QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue(set, val);
    settings.sync();
}

QString Utils::readSettings(QString set, QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value(set, val).toString();
}

QString Utils::showReflection()
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("ShowReflection", "true").toString();
}

QString Utils::viewmode() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("ViewMode", "grid").toString();
}

QString Utils::paging() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("Paging", "multiple").toString();
}

QString Utils::scrobble() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("Scrobble", "false").toString();
}

QString Utils::order() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("SortOrder", "album").toString();
}

QString Utils::lang() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("LastFMlang", "en").toString();
}

QString Utils::updatestart() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("UpdateOnStartup", "no").toString();
}

QString Utils::autosearch() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("AutoSearchLyrics", "yes").toString();
}

QString Utils::cleanqueue() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("CleanQueue", "yes").toString();
}

QString Utils::workoffline() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("WorkOffline", "no").toString();
}

void Utils::setViewMode(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("ViewMode", val);
    settings.sync();
    emit viewmodeChanged();
}

void Utils::setPaging(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("Paging", val);
    settings.sync();
    emit pagingChanged();
}

void Utils::setScrobble(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("Scrobble", val);
    settings.sync();
    emit scrobbleChanged();
}

void Utils::setOrder(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("SortOrder", val);
    settings.sync();
    emit orderChanged();
}

void Utils::setLang(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("LastFMlang", val);
    settings.sync();
    emit langChanged();
}

void Utils::setUpdateStart(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("UpdateOnStartup", val);
    settings.sync();
    emit updateChanged();
}

void Utils::setAutoSearch(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("AutoSearchLyrics", val);
    settings.sync();
    emit autosearchChanged();
}

void Utils::setCleanQueue(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("CleanQueue", val);
    settings.sync();
    emit queueChanged();
}

void Utils::setWorkOffline(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("WorkOffline", val);
    settings.sync();
    emit workofflineChanged();
}

QString Utils::orientation() const
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("Orientation", "auto").toString();
}

void Utils::setOrientation(QString val)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    settings.setValue("Orientation", val);
    settings.sync();
    emit orientationChanged();
}

QString Utils::plainLyrics(QString text)
{
    return text;
}

QString Utils::version()
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    return settings.value("Firmware", "PR10").toString();
}

QString Utils::reemplazar1(QString data)
{
    data.replace("&","&amp;");
    data.replace("<","&lt;");
    data.replace(">","&gt;");
    data.replace("\"","&quot;");
    data.replace("\'","&apos;");
    return data;
}

QString Utils::reemplazar2(QString data)
{
    data.replace("&amp;", "&");
    data.replace("&lt;", "<");
    data.replace("&gt;", ">");
    data.replace("&quot;", "\"");
    data.replace("&apos;", "\'");
    return data;
}

void Utils::createAlbumArt(QString imagepath)
{
    removeAlbumArt();
    QFile::link(imagepath, QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "currentAlbumArt.jpeg");
}

void Utils::removeAlbumArt()
{
    QFile::remove(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "currentAlbumArt.jpeg");
}

void Utils::getFolders()
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QStringList folders = settings.value("Folders","").toString().split("<separator>");
    folders.removeAll("");

    if (folders.count()==0)
        return;

    for (int i=0; i<folders.count(); ++i) {
        QString name = QFileInfo(folders.at(i)).fileName();
        QString path = folders.at(i);
        emit addFolder(name, path);
    }
}

void Utils::getFolderItemsUp(QString path)
{
    if (path.endsWith("/"))
        path.chop(1);
    int i = path.lastIndexOf("/");
    path = path.left(i);
    if (path=="") path = "/";
    getFolderItems(path);
}

void Utils::getFolderItems(QString path)
{
    if (path.isEmpty()) {
        path = QDir::homePath();
    }
    qDebug() << "Loading folder: " << path;

    if (!QFileInfo(path).exists())
        return;

    QDir dir (path);
    QStringList data;

    QFileInfoList entries;
    entries = dir.entryInfoList(QDir::AllEntries | QDir::System | QDir::NoDotAndDotDot ,
                                QDir::Name | QDir::IgnoreCase | QDir::DirsFirst);

    QListIterator<QFileInfo> entriesIterator (entries);
    while(entriesIterator.hasNext())
    {
        QFileInfo fileInfo = entriesIterator.next();

        if (fileInfo.isDir())
            emit appendFile(fileInfo.fileName(), fileInfo.absoluteFilePath(), "folder");
        else if (fileInfo.fileName().endsWith(".mp3") || fileInfo.fileName().endsWith(".m4a") ||
                 fileInfo.fileName().endsWith(".wma") || fileInfo.fileName().endsWith(".ogg") ||
                 fileInfo.fileName().endsWith(".opus") ||
                 fileInfo.fileName().endsWith(".flac") || fileInfo.fileName().endsWith(".wav") ||
                 fileInfo.fileName().endsWith(".asf"))
            emit appendFile(fileInfo.fileName(), fileInfo.absoluteFilePath(), "sounds");
    }

    emit appendFilesDone(path);
}

void Utils::addFolderToList(QString path)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QStringList folders = settings.value("Folders","").toString().split("<separator>");
    folders.removeAll("");
    folders.append(path);
    folders.removeDuplicates();
    settings.setValue("Folders", folders.join("<separator>"));
    settings.sync();
    emit foldersChanged();
}

void Utils::removeFolder(QString path)
{
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QStringList folders = settings.value("Folders","").toString().split("<separator>");
    folders.removeAll("");
    folders.removeAll(path);
    folders.removeDuplicates();
    settings.setValue("Folders", folders.join("<separator>"));
    settings.sync();
}

void Utils::setShuffle(int nitems)
{
    itemstotal = nitems;

    items.clear();
    QList<int> temp;

    for (int i=0; i<itemstotal; ++i)
        temp.append(i);

    std::srand(time(0));
    std::random_shuffle(temp.begin(), temp.end());

    while (!temp.isEmpty()) {
        int i = temp.takeFirst();
        items.append(i);
    }

    qDebug() << "SHUFFLE LIST ORDER::: " << items;
}

int Utils::getShuffleTrack(int current)
{
    items.removeAll(current);

    int res;
    if (items.count()==0)
        setShuffle(itemstotal);

    res = items.takeFirst();
    return res;
}

void Utils::loadPresets()
{
    QSqlQuery query = getQuery("select * from presets order by name");

    while( query.next() )
        emit appendPreset(query.value(0).toString());
}

void Utils::removePreset(QString name)
{
    bool res = executeQuery(QString("delete from presets where name='%1'").arg(name));
    qDebug() << "Removing preset " << name << res;
}

void Utils::updateSongDuration(QString source, int duration)
{
    QString d = QString::number(duration);

    QString qr = QString("UPDATE tracks SET duration='%1' where url='%2'").arg(d).arg(source);
    executeQuery(qr);

    qr = QString("UPDATE playlists SET duration='%1' where url='%2'").arg(d).arg(source);
    executeQuery(qr);

    qr = QString("UPDATE queue SET duration='%1' where url='%2'").arg(d).arg(source);
    executeQuery(qr);
}
