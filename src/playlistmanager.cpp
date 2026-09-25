#include "playlistmanager.h"

#include <QSettings>
#include <QStandardPaths>
#include <QFileInfo>
#include <QXmlStreamReader>
#include <QDir>

extern bool databaseWorking;
extern bool isDBOpened;

PlaylistManager::PlaylistManager(QQuickItem *parent)
    : QQuickItem(parent)
{

}

void PlaylistManager::loadList(QString list)
{
    list = list.trimmed();
    listado.clear();
    if (!isDBOpened) openDatabase();

    QString qr;
    if (list=="00000000000000000000")
        qr = "select artist, album, title, duration, url from queue";
    else if (list=="00000000000000000001")
        qr = "select artist, album, title, duration, url from tracks where fav=1";
    else
        qr = QString("select artist, album, title, duration, url "
                     "from playlists where playlist='%1'").arg(xmlin(list));

    QSqlQuery query = getQuery(qr);

    while( query.next() )
    {
        QString dato1, dato2, dato3, dato4, dato5;
        dato1 = query.value(0).toString();
        dato2 = query.value(1).toString();
        dato5 = query.value(4).toString();
        dato3 = query.value(2).toString();
        if (dato3=="") dato3 = QFileInfo(dato5).baseName();
        dato4 = query.value(3).toString();

        QStringList l1;
        l1.append(xmlout(dato1));
        l1.append(xmlout(dato2));
        l1.append(xmlout(dato3));
        l1.append(dato4);
        l1.append(xmlout(dato5));
        if ( dato5!="")
            listado.append(l1);
    }

}

void PlaylistManager::addToList(QString artist, QString album, QString title, QString link, QString time)
{
    //loadList(list);

    bool add = true;
    for (int f=0; f<listado.count(); f++)
    {
        if ( listado[f][4] == link ) {
            add = false;
            break;
        }
    }

    if ( add == true )
    {
        //qDebug() << "Adding file:" << link << " - total files: " << listado.count();
        QStringList l1;
        l1.append(artist);
        l1.append(album);
        l1.append(title);
        l1.append(time);
        l1.append(link);
        listado.append(l1);

    }

    //saveList(list);
}

void PlaylistManager::addAlbumToList(QString list, QString artist, QString album, QString various, QString song)
{

    qDebug() << "ADDING ALBUM TO LIST: " << list << artist << album;

    if (!isDBOpened) openDatabase();

    QSettings sets(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QString torder = sets.value("TrackOrder", "number").toString();
    QString order;
    if (torder=="title") order="title";
    else if (torder=="number") order="album, COALESCE(discnum,1), tracknum";
    else if (torder=="filename") order="url";

    QString qr;
    if (list=="00000000000000000000") {

        if (artist=="ALL" && album=="ALL")
            qr = QString("insert into queue (url, artist, album, title, duration) select url, artist, album, title, duration "
                         "from tracks order by %1 collate nocase").arg(order);

        else if (song=="" && various=="1" && album!="")
            qr = QString("insert into queue (url, artist, album, title, duration) select url, artist, album, title, duration from tracks "
                         "where album='%1' and artist='%2' order by %3 collate nocase").arg(xmlin(album)).arg(xmlin(artist)).arg(order);

        else if (song=="" && various=="1" && album=="")
            qr = QString("insert into queue (url, artist, album, title, duration) select url, artist, album, title, duration from tracks "
                         "where artist='%1' order by year, %2 collate nocase").arg(xmlin(artist)).arg(order);

        else if (song=="" && various!="1" && album!="")
            qr = QString("insert into queue (url, artist, album, title, duration) select url, artist, album, title, duration from tracks "
                         "where album='%1' order by %2 collate nocase").arg(xmlin(album)).arg(order);

        else if (song!="")
            qr = QString("insert into queue (url, artist, album, title, duration) select url, artist, album, title, duration from tracks "
                         "where url='%1' collate nocase").arg(xmlin(song));
    }

    else
    {
     //insert into playlists (playlist, url, artist, album, title, duration) select 'pepepepe', url, artist, album, title, duration from tracks
        if (artist=="ALL" && album=="ALL")
            qr = QString("insert into playlists (playlist, url, artist, album, title, duration) select '%1', url, artist, album, title, duration "
                         "from tracks order by %2 collate nocase").arg(list).arg(order);

        else if (song=="" && various=="1" && album!="")
            qr = QString("insert into playlists (playlist, url, artist, album, title, duration) select '%1', url, artist, album, title, duration from tracks "
                         "where album='%2' and artist='%3' order by %4 collate nocase").arg(list).arg(xmlin(album)).arg(xmlin(artist)).arg(order);

        else if (song=="" && various=="1" && album=="")
            qr = QString("insert into playlists (playlist, url, artist, album, title, duration) select '%1', url, artist, album, title, duration from tracks "
                         "where artist='%2' order by year, %3 collate nocase").arg(list).arg(xmlin(artist)).arg(order);

        else if (song=="" && various!="1" && album!="")
            qr = QString("insert into playlists (playlist, url, artist, album, title, duration) select '%1', url, artist, album, title, duration from tracks "
                         "where album='%2' order by %3 collate nocase").arg(list).arg(xmlin(album)).arg(order);

        else if (song!="")
            qr = QString("insert into playlists (playlist, url, artist, album, title, duration) select '%1', url, artist, album, title, duration from tracks "
                         "where url='%2' collate nocase").arg(list).arg(xmlin(song));
    }



    executeQuery(qr);

    /*QSqlQuery query = getQuery(qr);

    while( query.next() )
    {
        QString dato1, dato2, dato3, dato4, dato5;
        dato1 = query.value(0).toString();
        dato2 = query.value(1).toString();
        dato3 = query.value(2).toString();
        dato4 = query.value(3).toString();
        dato5 = query.value(4).toString();

        QString qr;
        if (list=="00000000000000000000")
            qr = QString("insert into queue values('%1','%2','%3','%4', %5)")
                    .arg(dato1).arg(dato2).arg(dato3).arg(dato4).arg(dato5);
        else
            qr = QString("insert into playlists values('%1','%2','%3','%4', '%5', %6)")
                    .arg(list).arg(dato1).arg(dato2).arg(dato3).arg(dato4).arg(dato5);

        executeQuery(qr);
    }*/

}

void PlaylistManager::copyListToQueue(QString source)
{
    qDebug() << "COPY TO QUEUE FROM " << source;

    if (!isDBOpened) openDatabase();

    listado.clear();
    executeQuery("delete from queue");

    QString qr;

    if (source=="00000000000000000001")
        qr = QString("insert into queue (url, artist, album, title, duration) "
                     "select url, artist, album, title, duration from tracks where fav=1");
    else
        qr = QString("insert into queue (url, artist, album, title, duration) "
                         "select url, artist, album, title, duration from playlists where playlist='%1'")
                         .arg(xmlin(source));

    executeQuery(qr);

}

bool PlaylistManager::isInQueue(QString url)
{
    if (!isDBOpened) openDatabase();

    return executeQueryCheckCount(QString("select url from queue where url='%1' limit 1").arg(xmlin(url)));
}

// Inserts tracks, in the given order, into the stored queue at the given
// position (-1 appends). Existing copies of the tracks are removed first, so
// they get moved. The queue table has no order column: rows are kept in rowid
// order, so the table is rebuilt around the new tracks.
void PlaylistManager::insertIntoQueue(QStringList urls, int position)
{
    qDebug() << "INSERTING INTO QUEUE AT" << position << urls;

    if (urls.isEmpty()) return;
    if (!isDBOpened) openDatabase();

    QStringList links;
    for (int i=0; i<urls.count(); ++i)
        links.append(QString("'%1'").arg(xmlin(urls[i])));

    executeQuery("begin transaction");
    executeQuery("drop table if exists queue_tmp");
    executeQuery(QString("create temp table queue_tmp as select * from queue "
                         "where url not in (%1) order by rowid").arg(links.join(",")));
    executeQuery("delete from queue");

    if (position < 0)
        executeQuery("insert into queue select * from queue_tmp order by rowid");
    else
        executeQuery(QString("insert into queue select * from queue_tmp order by rowid limit %1").arg(position));

    for (int i=0; i<links.count(); ++i)
        executeQuery(QString("insert into queue (url, artist, album, title, duration) "
                             "select url, artist, album, title, duration from tracks "
                             "where url=%1 collate nocase limit 1").arg(links[i]));

    if (position >= 0)
        executeQuery(QString("insert into queue select * from queue_tmp order by rowid limit -1 offset %1").arg(position));

    executeQuery("drop table queue_tmp");
    executeQuery("commit");
}

// Returns the tracks of an album, in the same order as loadAlbum()
QVariantList PlaylistManager::getAlbumTracks(QString artist, QString album, QString various)
{
    if (!isDBOpened) openDatabase();

    QVariantList tracks;
    QSqlQuery query = getQuery(albumQuery(artist, album, various));

    while( query.next() )
    {
        QString url = query.value(4).toString();
        if (url=="") continue;

        QString title = query.value(2).toString();
        if (title=="") title = QFileInfo(url).baseName();

        QVariantMap map;
        map.insert("artist", xmlout(query.value(0).toString()));
        map.insert("album", xmlout(query.value(1).toString()));
        map.insert("title", xmlout(title));
        map.insert("duration", query.value(3).toString());
        map.insert("url", xmlout(url));
        tracks.append(map);
    }
    return tracks;
}

void PlaylistManager::saveList(QString list)
{
    list = list.trimmed();

    if (list=="00000000000000000001")
        return;

    if (!isDBOpened) openDatabase();

    if (list=="00000000000000000000")
        executeQuery("delete from queue");
    else
        executeQuery(QString("delete from playlists where playlist='%1'").arg(xmlin(list)));

    for ( int i=0; i < listado.count(); ++i)
    {
        QString qr;
        if (list=="00000000000000000000")
            qr = QString("insert into queue values('%1','%2','%3','%4', %5)")
                    .arg(xmlin(listado[i][4])).arg(xmlin(listado[i][0]))
                    .arg(xmlin(listado[i][1])).arg(xmlin(listado[i][2]))
                    .arg(listado[i][3]);
        else
            qr = QString("insert into playlists values('%1','%2','%3','%4', '%5', %6)")
                    .arg(xmlin(list)).arg(xmlin(listado[i][4])).arg(xmlin(listado[i][0]))
                    .arg(xmlin(listado[i][1])).arg(xmlin(listado[i][2]))
                    .arg(listado[i][3]);

        executeQuery(qr);
    }
    if (list!="00000000000000000000" && listado.count()==0)
    {
        //qDebug() << "CREATING EMPTY LIST";
        QString qr = QString("insert into playlists values('%1','%2','%3','%4', '%5', '%6')")
                .arg(xmlin(list)).arg("").arg("").arg("").arg("").arg("");

        executeQuery(qr);
    }

}

void PlaylistManager::removeFromList(QString link)
{
    qDebug() << "REMOVING "<< link;

    for (int f=0; f<listado.count(); f++)
    {
        if ( listado[f][4] == link )
        {
            listado.removeAt(f);
            break;
        }
    }
    //qDebug() << "REMOVE OK";
}

void PlaylistManager::removeList(QString name)
{
    if (!isDBOpened) openDatabase();

    if (name=="00000000000000000000")
        executeQuery("delete from queue");
    else
        executeQuery(QString("delete from playlists where playlist='%1'").arg(xmlin(name)));

}

void PlaylistManager::clearList(QString list)
{
    if (list=="00000000000000000001")
    {
        executeQuery("update tracks set fav=NULL where fav=1");
    }
    else
    {
        listado.clear();
        saveList(list);
    }
}

QString PlaylistManager::xmlin(QString data)
{
    QString tmp = data;
    tmp.replace("&", "&amp;");
    tmp.replace("\"", "&quot;");
    tmp.replace("<", "&lt;");
    tmp.replace(">", "&gt;");
    tmp.replace("\'", "&apos;");
    return tmp;
}

QString PlaylistManager::xmlout(QString data)
{
    QString tmp = data;
    tmp.replace("&amp;", "&");
    tmp.replace("&quot;", "\"");
    tmp.replace("&lt;", "<");
    tmp.replace("&gt;", ">");
    tmp.replace("&apos;", "\'");
    return tmp;
}

void PlaylistManager::renameList(QString oldname, QString newname)
{
    newname = newname.trimmed();
    if (!isDBOpened) openDatabase();

    QString qr = QString("UPDATE playlists SET playlist='%1' where playlist='%2'")
                .arg(xmlin(newname)).arg(xmlin(oldname));

    executeQuery(qr);

}

void PlaylistManager::loadPlaylists()
{
    if (!isDBOpened) openDatabase();

    QSqlQuery query = getQuery(QString("select title, count(distinct url) as songs from queue"));

    while( query.next() )
    {
        QVariantMap map;
        map.insert("name", "00000000000000000000");
        map.insert("count", query.value(1).toString());
        map.insert("type", "");
        emit addPlaylist(map);
    }

    query = getQuery(QString("select title, count(distinct url) as songs from tracks where fav=1"));

    while( query.next() )
    {
        QVariantMap map;
        map.insert("name", "00000000000000000001");
        map.insert("type", "");
        map.insert("count", query.value(1).toString());
        emit addPlaylist(map);
    }

    query = getQuery(QString("select playlist, (case when (title='') then 0"
                             " else (count(distinct url)) end) as status from playlists group by playlist"));

    while( query.next() )
    {
        QVariantMap map;
        map.insert("name", query.value(0).toString());
        map.insert("type", tr("Custom playlists"));
        map.insert("count", query.value(1).toString());
        emit addPlaylist(map);
    }

}

void PlaylistManager::loadPlaylist(QString name)
{
    if (!isDBOpened) openDatabase();

    QString qr;
    if (name=="00000000000000000000")
        qr = "select artist, album, title, duration, url from queue";
    else if (name=="00000000000000000001")
        qr = "select artist, album, title, duration, url from tracks where fav=1";
    else
        qr = QString("select artist, album, title, duration, url "
                     "from playlists where playlist='%1'").arg(xmlin(name));

    QSqlQuery query = getQuery(qr);

    while( query.next() )
    {
        QString dato1, dato2, dato3, dato4, dato5;
        dato5 = query.value(4).toString();
        dato1 = query.value(0).toString();
        dato2 = query.value(1).toString();
        dato3 = query.value(2).toString();
        if (dato3=="") dato3 = QFileInfo(dato5).baseName();
        dato4 = query.value(3).toString();

        if ( dato5!="") {
            QVariantMap map;
            map.insert("artist", xmlout(dato1));
            map.insert("album", xmlout(dato2));
            map.insert("title", xmlout(dato3));
            map.insert("duration", dato4);
            map.insert("url", xmlout(dato5));

            emit addItemToList(name, map);
        }
    }
    emit addItemToListDone(name);

}

void PlaylistManager::loadArtist(QString artist)
{
    artist = xmlin(artist);

    listado.clear();

    if (!isDBOpened) openDatabase();


    QSqlQuery query = getQuery(QString("select album, count(distinct title) as songs from tracks "
                                       "where artist='%1' group by album order by year").arg(artist));

    int totalsongs = 0;

    while( query.next() )
    {
        QString dato1, dato2;
        dato1 = query.value(0).toString();
        dato2 = query.value(1).toString();

        QVariantMap map;
        map.insert("artist", xmlout(artist));
        map.insert("album", xmlout(dato1));
        map.insert("songs", dato2);

        totalsongs += dato2.toInt();

        emit addItemToArtist(map);
    }
    emit artistLoaded(totalsongs);

}

// Builds the query listing an album's tracks, ordered by the TrackOrder setting
QString PlaylistManager::albumQuery(QString artist, QString album, QString various)
{
    album = xmlin(album);
    artist = xmlin(artist);

    QSettings sets(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QString torder = sets.value("TrackOrder", "number").toString();
    QString order;
    if (torder=="title") order="title";
    else if (torder=="number") order="album, COALESCE(discnum,1), tracknum";
    else if (torder=="filename") order="url";


    QString qr;

    if (artist=="ALL" && album=="ALL" && various=="ALL")
        qr = QString("select artist, album, title, duration, url, tracknum, year, fav, discnum "
                     "from tracks order by %1 collate nocase").arg(order);

    else if (various=="1")
        qr = QString("select artist, album, title, duration, url, tracknum, year, fav, discnum "
                     "from tracks where artist='%1' and album='%2' order by %3 collate nocase")
                    .arg(artist).arg(album).arg(order);

    else
        qr = QString("select artist, album, title, duration, url, tracknum, year, fav, discnum "
                     "from tracks where album='%1' order by %2 collate nocase")
                     .arg(album).arg(order);

    return qr;
}

void PlaylistManager::loadAlbum(QString artist, QString album, QString various)
{
    listado.clear();

    if (!isDBOpened) openDatabase();

    QSqlQuery query = getQuery(albumQuery(artist, album, various));

    int totaltime = 0;

    while( query.next() )
    {
        QString dato1, dato2, dato3, dato4, dato5, dato6, dato7, dato8, dato9;
        dato1 = query.value(0).toString();   // artist
        dato2 = query.value(1).toString();   // album
        dato3 = query.value(2).toString();   // title
        dato4 = query.value(3).toString();   // duration
        dato5 = query.value(4).toString();   // url
        dato6 = query.value(5).toString();   // tracknum
        dato7 = query.value(6).toString();   // year
        dato8 = query.value(7).toString();   // fav
        dato9 = query.value(8).toString();   // discnum

        if ( dato5!="") {
            QVariantMap map;
            map.insert("artist", xmlout(dato1));
            map.insert("album", xmlout(dato2));
            if (dato3=="") dato3 = QFileInfo(dato5).baseName();
            map.insert("title", xmlout(dato3));
            map.insert("duration", dato4);
            map.insert("url", xmlout(dato5));
            map.insert("fav", dato8);
            map.insert("tracknum", dato6.toInt());
            map.insert("discnum", dato9.toInt());

            totaltime += dato4.toInt();

            emit addItemToAlbum(map);
        }
    }
}
