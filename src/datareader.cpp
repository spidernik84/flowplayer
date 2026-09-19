#include "datareader.h"
#include "globalutils.h"

#include <id3v2tag.h>
#include <attachedpictureframe.h>
#include <flacpicture.h>
#include <mp4tag.h>
#include <mp4coverart.h>

#include <mpegfile.h>
#include <flacfile.h>
#include <tlist.h>
#include <vorbisfile.h>
#include <opusfile.h>
#include <mp4file.h>
#include <wavfile.h>
#include <speexfile.h>
#include <oggflacfile.h>
#include <aifffile.h>
#include <wavpackfile.h>
#include <trueaudiofile.h>
#include <asffile.h>
#include <apefile.h>
#include <mpcfile.h>
#include <modfile.h>
#include <xmfile.h>
#include <tpropertymap.h>


#include <QDir>
#include <QDirIterator>
#include <QString>
#include <QStringList>
#include <QSettings>
#include <QDebug>
#include <QStandardPaths>

extern bool databaseWorking;
extern bool isDBOpened;

DataReader::DataReader()
{

}

void DataReader::openDB()
{
    if (!isDBOpened) openDatabase();

    if (isDBOpened)
    {
        executeQuery("create table tracks (url text, artist text, album text, "
            "title text, year integer, tracknum integer, discnum integer, "
            "duration integer, fav integer)");

        executeQuery("create table playlists (playlist text, url text, artist text, album text, "
                   "title text, duration integer)");

        executeQuery("create table queue (url text, artist text, album text, "
                   "title text, duration integer)");

        executeQuery("create table temp (url text, artist text, album text, "
                   "title text, year integer, tracknum integer, duration integer, fav integer)");

        // Migration: ensure the "discnum" column exists on databases created
        // by older versions of the app. CREATE TABLE above is a no-op when the
        // table already exists, so we must ALTER older tables explicitly.
        QSqlQuery info = getQuery("pragma table_info(tracks)");
        bool hasDiscnum = false;
        while (info.next()) {
            if (info.value(1).toString() == "discnum") {
                hasDiscnum = true;
                break;
            }
        }
        if (!hasDiscnum) {
            qDebug() << "MIGRATING tracks table: adding discnum column";
            executeQuery("alter table tracks add discnum integer");
        }
    }
}

void DataReader::insertData(QString url, QString artist, QString album,
    QString title, int year, int tracknum, int discnum, int duration)
{

    QVariantMap m;
    m.insert("url", url);
    m.insert("artist", artist);
    m.insert("album", album);
    m.insert("title", title);
    m.insert("year", year);
    m.insert("tracknum", tracknum);
    m.insert("discnum", discnum);
    m.insert("duration", duration);

    if (favFiles.indexOf(url)>-1)
        m.insert("fav", "1");
    else
        m.insert("fav", "");

    map.append(m);

    if (map.count()==50)
    {
        saveData();
        map.clear();
    }
}

void DataReader::saveData()
{
    if (map.count()==0)
        return;

    if (!isDBOpened) openDatabase();

    QString qr = "insert into tracks";

    for (int i=0; i<map.count(); ++i)
    {
        if (i==0)
        {
            qr += QString(" select '%1' as url, '%2' as artist, '%3' as album, '%4' as title, "
                    "%5 as year, %6 as tracknum, %7 as discnum, %8 as duration, '%9' as fav")
                    .arg(map.at(i).value("url","").toString())
                    .arg(map.at(i).value("artist","").toString())
                    .arg(map.at(i).value("album","").toString())
                    .arg(map.at(i).value("title","").toString())
                    .arg(map.at(i).value("year",0).toInt())
                    .arg(map.at(i).value("tracknum",0).toInt())
                    .arg(map.at(i).value("discnum",0).toInt())
                    .arg(map.at(i).value("duration",0).toInt())
                    .arg(map.at(i).value("fav","").toString());
        }
        else
        {
            qr += QString(" union select '%1', '%2','%3', '%4',%5, %6, %7, %8, '%9'")
                          .arg(map.at(i).value("url","").toString())
                          .arg(map.at(i).value("artist","").toString())
                          .arg(map.at(i).value("album","").toString())
                          .arg(map.at(i).value("title","").toString())
                          .arg(map.at(i).value("year",0).toInt())
                          .arg(map.at(i).value("tracknum",0).toInt())
                          .arg(map.at(i).value("discnum",0).toInt())
                          .arg(map.at(i).value("duration",0).toInt())
                          .arg(map.at(i).value("fav","").toInt());
        }
    }

    bool res = executeQuery(qr);

    qDebug() << "APPENDING ITEMS: " << res;
}

QString DataReader::reemplazar1(QString data)
{
    data.replace("&","&amp;");
    data.replace("<","&lt;");
    data.replace(">","&gt;");
    data.replace("\"","&quot;");
    data.replace("\'","&apos;");
    return data;
}

QString DataReader::reemplazar2(QString data)
{
    data.replace("&amp;", "&");
    data.replace("&lt;", "<");
    data.replace("&gt;", ">");
    data.replace("&quot;", "\"");
    data.replace("&apos;", "\'");
    return data;
}

TagLib::File* DataReader::getFileByMimeType(QString file)
{
    file = file.remove("file://");
    QString str = file.toLower();

    if(str.endsWith(".mp3")) {
        return new TagLib::MPEG::File(file.toUtf8());
    } else if(str.endsWith(".flac")) {
        return new TagLib::FLAC::File(file.toUtf8());
    } else if(str.endsWith(".ogg")) {
        return new TagLib::Ogg::Vorbis::File(file.toUtf8());
    } else if(str.endsWith(".opus")) {
        return new TagLib::Ogg::Opus::File(file.toUtf8());
    } else if(str.endsWith(".wav")) {
        return new TagLib::RIFF::WAV::File(file.toUtf8());
    } else if(str.endsWith(".m4a")) {
        return new TagLib::MP4::File(file.toUtf8());
    } else if(str.endsWith(".wma") ||
              str.endsWith(".asf")) {
        return new TagLib::ASF::File(file.toUtf8());
    } else if(str.endsWith(".mod")) {
        return new TagLib::Mod::File(file.toUtf8());
    } else if(str.endsWith(".xm")) {
        return new TagLib::XM::File(file.toUtf8());
    }
    return 0;
}


// Extract the first embedded cover image from a TagLib::File, if any.
// Returns an empty ByteVector when the file has no embedded art, or when
// the format isn't one we handle. Support is intentionally limited to the
// three formats that carry art in a way TagLib exposes cleanly: MP3,
// FLAC, and MP4/M4A. Vorbis, Opus, WMA, WAV, AIFF and the tracker
// formats return nothing here; folder-cover fallback still applies to them.
static TagLib::ByteVector extractEmbeddedCover(TagLib::File* tf)
{
    // MP3: ID3v2 APIC frame
    if (auto* mpeg = dynamic_cast<TagLib::MPEG::File*>(tf)) {
        if (TagLib::ID3v2::Tag* tag = mpeg->ID3v2Tag()) {
            TagLib::ID3v2::FrameList apic = tag->frameList("APIC");
            if (!apic.isEmpty()) {
                auto* frame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(apic.front());
                if (frame)
                    return frame->picture();
            }
        }
        return TagLib::ByteVector();
    }

    // FLAC: native PICTURE metadata block
    if (auto* flac = dynamic_cast<TagLib::FLAC::File*>(tf)) {
        const TagLib::List<TagLib::FLAC::Picture*>& pics = flac->pictureList();
        if (!pics.isEmpty() && pics.front())
            return pics.front()->data();
        return TagLib::ByteVector();
    }

    // MP4 / M4A: "covr" atom
    if (auto* mp4 = dynamic_cast<TagLib::MP4::File*>(tf)) {
        if (TagLib::MP4::Tag* tag = mp4->tag()) {
            TagLib::MP4::ItemMap items = tag->itemMap();
            auto it = items.find("covr");
            if (it != items.end()) {
                TagLib::MP4::CoverArtList covers = it->second.toCoverArtList();
                if (!covers.isEmpty())
                    return covers.front().data();
            }
        }
        return TagLib::ByteVector();
    }

    return TagLib::ByteVector();
}





void DataReader::readFile(QString file)
{
    file.remove("file://");
    TagLib::File* tf = getFileByMimeType(file);

    QString error = "";
    if (tf)
    {
        tagFile = new TagLib::FileRef(tf);

        if (!tagFile->isNull())
        {
            m_title = QString::fromUtf8(tagFile->tag()->title().toCString(true));
            m_album = QString::fromUtf8(tagFile->tag()->album().toCString(true));
            m_artist = QString::fromUtf8(tagFile->tag()->artist().toCString(true));
            m_year = QString::number(tagFile->tag()->year());
            m_tracknum = QString::number(tagFile->tag()->track());

            // Disc number: TagLib::Tag has no disc() accessor, so read it from
            // the File's PropertyMap. TagLib normalises ID3v2's TPOS frame to
            // the key "DISCNUMBER", but keeps the raw "N/M" value, so always
            // take the part before the slash.
            TagLib::PropertyMap props = tf->properties();
            qDebug() << "=== DISC DEBUG" << file;
            qDebug() << "  props.isEmpty():" << props.isEmpty();
            for (auto it = props.begin(); it != props.end(); ++it) {
                const TagLib::StringList &values = it->second;
                QString joined;
                for (const auto &v : values) {
                    if (!joined.isEmpty()) joined += " | ";
                    joined += QString::fromStdString(v.to8Bit(true));
                }
                qDebug() << "   key:"
                         << QString::fromStdString(it->first.to8Bit(true))
                         << "= " << joined;
            }


            QString discStr;
            if (props.contains("DISCNUMBER"))
                discStr = QString::fromStdString(props["DISCNUMBER"].toString().to8Bit(true));
            else if (props.contains("TPOS"))
                discStr = QString::fromStdString(props["TPOS"].toString().to8Bit(true));

            int discnum = 0;
            if (!discStr.isEmpty())
                discnum = discStr.split("/").first().trimmed().toInt();

            qDebug() << "=== PARSED discnum =" << discnum
                     << "from discStr =" << discStr;

            m_discnum = QString::number(discnum);
            if (m_title=="") m_title = QFileInfo(file).baseName();

            // Cover art priority: embedded > cover.jpg/folder.jpg > user-downloaded.
            // "User-downloaded" happens later from the UI, and only if we don't leave
            // anything in the cache slot here.
            if (m_artist != "" && m_album != "") {
                const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
                const QString dest = cacheDir + "/media-art/album-" + doubleHash(m_artist, m_album) + ".jpeg";

                // Only populate the slot on first sight; leave existing (possibly
                // downloaded) art untouched across re-scans.
                if (!QFile::exists(dest)) {
                    bool wrote = false;

                    // 1. Embedded art
                    TagLib::ByteVector art = extractEmbeddedCover(tf);
                    if (!art.isEmpty()) {
                        QFile f(dest);
                        if (f.open(QIODevice::WriteOnly)) {
                            f.write(art.data(), art.size());
                            f.close();
                            wrote = true;
                            qDebug() << "EXTRACTED EMBEDDED ART:" << file << m_artist << m_album
                                     << art.size() << "bytes";
                        } else {
                            qDebug() << "FAILED TO WRITE EMBEDDED ART TO" << dest;
                        }
                    }

                    // 2. Folder fallback
                    if (!wrote) {
                        QFileInfo info(file);
                        QDirIterator iterator(info.dir());
                        while (iterator.hasNext()) {
                            iterator.next();
                            if (iterator.fileInfo().isFile() &&
                                (iterator.fileInfo().suffix() == "jpeg" ||
                                 iterator.fileInfo().suffix() == "jpg") &&
                                (iterator.fileInfo().baseName() == "cover" ||
                                 iterator.fileInfo().baseName() == "folder")) {
                                qDebug() << "COPYING FILE ART:" << iterator.filePath() << m_artist << m_album;
                                QFile::copy(iterator.filePath(), dest);
                                break;
                            }
                        }
                    }
                }
            }

            if (m_artist=="") m_artist = tr("Unknown artist");
            if (m_album=="") m_album = tr("Unknown album");

            TagLib::AudioProperties *properties = tf->audioProperties();

            m_duration = QString::number(properties->length());

            insertData(reemplazar1(file), reemplazar1(m_artist), reemplazar1(m_album),
                       reemplazar1(m_title), m_year.toInt(), m_tracknum.toInt(),
                       m_discnum.toInt(), m_duration.toInt());

        }
        else
        {
            error = "INVALID TAG";
        }
        delete tagFile;
    }
    else
    {
        error = "INVALID FILE";
    }
    qDebug() << "PROCESSING FILE: " << file << (error==""? "OK" : error);

}

void DataReader::addFile(QString file)
{
    files.append(file);
}

void DataReader::run()
{
    forceFinish = false;

    files.clear();
    favFiles.clear();
    map.clear();

    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QStringList folders = settings.value("Folders","").toString().split("<separator>");
    folders.removeAll("");

    for (int i=0; i<folders.count(); ++i)
    {
        QDir dir(folders.at(i));
        QDirIterator iterator(dir.absolutePath(), QDirIterator::Subdirectories);
        while (iterator.hasNext()) {
            iterator.next();
            if (!iterator.fileInfo().isDir()) {
                if ( iterator.filePath().toLower().endsWith(".mp3") ||
                     iterator.filePath().toLower().endsWith(".m4a") ||
                     iterator.filePath().toLower().endsWith(".flac") ||
                     iterator.filePath().toLower().endsWith(".ogg") ||
                     iterator.filePath().toLower().endsWith(".opus") ||
                     iterator.filePath().toLower().endsWith(".wma") ||
                     iterator.filePath().toLower().endsWith(".asg") ||
                     iterator.filePath().toLower().endsWith(".wav") )
                {
                    files.append(iterator.filePath());
                    if (forceFinish) {
                        emit finished();
                        break;
                    }
                }
                if ( (iterator.filePath().toLower().endsWith(".mod") ||
                     iterator.filePath().toLower().endsWith(".xm")) &&
                     QFileInfo("/usr/lib/libmodplug.so.1").exists() )
                {
                    files.append(iterator.filePath());
                    if (forceFinish) {
                        emit finished();
                        break;
                    }
                }
            }
        }

        if (forceFinish) {
            emit finished();
            break;
        }

    }

    files.removeDuplicates();
    emit total(files.count());

    QSqlQuery query = getQuery("select * from tracks where fav=1");
    while( query.next() )
    {
        favFiles.append(query.value(0).toString());
    }

    executeQuery(QString("delete from tracks"));

    if (forceFinish) {
        emit finished();
        return;
    }

    for (int i=0; i<files.count(); ++i)
    {
        emit percent(i);
        readFile(files.at(i));

        if (forceFinish) {
            emit finished();
            break;
        }

    }
    saveData();

    executeQuery("create table tmp as select * from tracks group by url");
    executeQuery("drop table tracks");
    executeQuery("create table tracks as select * from tmp");
    executeQuery("drop table tmp");

    files.clear();
    favFiles.clear();
    map.clear();

    emit finished();

}

void DataReader::clearFiles()
{
    files.clear();
}
