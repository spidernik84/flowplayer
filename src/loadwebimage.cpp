#include "loadwebimage.h"
#include "utils.h"

#include <QCryptographicHash>
#include <QUrl>
#include <qstring.h>
#include <qfileinfo.h>
#include <qdir.h>
#include <QImage>
#include <QDebug>
#include <QDateTime>
#include <QStandardPaths>
#include <QJsonArray>
#include <QJsonDocument>
#include <QString>
#include <QJsonObject>

QString hmacSha1(QByteArray key, QByteArray baseString)
{
    int blockSize = 64; // HMAC-SHA-1 block size, defined in SHA-1 standard
    if (key.length() > blockSize) { // if key is longer than block size (64), reduce key length with SHA-1 compression
        key = QCryptographicHash::hash(key, QCryptographicHash::Sha1);
    }

    QByteArray innerPadding(blockSize, char(0x36)); // initialize inner padding with char "6"
    QByteArray outerPadding(blockSize, char(0x5c)); // initialize outer padding with char "\"
    // ascii characters 0x36 ("6") and 0x5c ("\") are selected because they have large
    // Hamming distance (http://en.wikipedia.org/wiki/Hamming_distance)

    for (int i = 0; i < key.length(); i++) {
        innerPadding[i] = innerPadding[i] ^ key.at(i); // XOR operation between every byte in key and innerpadding, of key length
        outerPadding[i] = outerPadding[i] ^ key.at(i); // XOR operation between every byte in key and outerpadding, of key length
    }

    // result = hash ( outerPadding CONCAT hash ( innerPadding CONCAT baseString ) ).toBase64
    QByteArray total = outerPadding;
    QByteArray part = innerPadding;
    part.append(baseString);
    total.append(QCryptographicHash::hash(part, QCryptographicHash::Sha1));
    QByteArray hashed = QCryptographicHash::hash(total, QCryptographicHash::Sha1);
    return hashed.toBase64();
}

WebThread::WebThread()
{
    wdatos = new QNetworkAccessManager(this);
    connect(wdatos, SIGNAL(finished(QNetworkReply*)), this, SLOT(downloaded(QNetworkReply*)));

}

WebThread::~WebThread()
{

}

void WebThread::addFile(QString artist, QString album, int index)
{
    QStringList m;
    m.append(artist);
    m.append(album);
    m.append(QString::number(index));
    //qDebug() << "Adding missing: " << m;
    files.append(m);
}

void WebThread::run()
{

}

bool WebThread::checkInternal()
{
    bool res = false;

    QString artist = files[0][0];
    QString album = files[0][1];

    QSqlQuery query = getQuery(QString("select url from tracks where artist='%1' and album='%2' limit 1").arg(artist).arg(album));
    while( query.next() )
    {
        QString dir = QFileInfo(query.value(0).toString()).path();

        if (QFileInfo(dir + "/folder.jpg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/folder.jpg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

        else if (QFileInfo(dir + "/folder.jpeg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/folder.jpeg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

        else if (QFileInfo(dir + "/cover.jpg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/cover.jpg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

        if (QFileInfo(dir + "/Folder.jpg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/Folder.jpg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

        else if (QFileInfo(dir + "/Folder.jpeg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/Folder.jpeg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

        else if (QFileInfo(dir + "/Cover.jpg").exists())
        {
            QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";
            QImage image(dir + "/Cover.jpg");
            image.save(th2, "JPEG");
            emit imgLoaded(th2, files[0][2].toInt());
            res = true;
        }

    }
    return res;
}

void WebThread::checkAll()
{
    if (checkInternal())
    {
        files.removeAt(0);

        if (files.count()>0)
            checkAll();
        else
            emit downloadDone();

        return;
    }

    QString artist = files[0][0];
    QString album = files[0][1];


    QString url = "http://ws.audioscrobbler.com/2.0/?method=album.getinfo";
    url += "&api_key=7f338c7458e7d1a9a6204221ff904ba1";
    url += "&artist=" + QUrl::toPercentEncoding(artist);
    url += "&album=" + QUrl::toPercentEncoding(album);

    action = "link";
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, "FlowPlayer/1.0");
    wdatos->get(req);

}

void WebThread::downloaded(QNetworkReply *respuesta)
{
    if (canceled)
        return;

    int current = 0;
    if (files.count() > 0)
        current = files[0][2].toInt();
    else
        current = curImageIndex;

    // --- Stage 1: last.fm query ---
    if (action == "link")
    {
        bool gotLink = false;

        if (respuesta->error() == QNetworkReply::NoError) {
            QString body = QString::fromUtf8(respuesta->readAll());
            QString mega;
            int x = body.indexOf("<image size=\"mega\">");
            if (x >= 0) {
                body.remove(0, x + 19);
                x = body.indexOf("<");
                if (x >= 0)
                    body.remove(x, body.length() - x);
                mega = body.trimmed();
            }
            if (!mega.isEmpty() && mega.startsWith("http")) {
                qDebug() << "last.fm link for" << files[0][0] << files[0][1] << mega;
                downloadImage(mega);   // sets action = "image"
                gotLink = true;
            }
        } else {
            qDebug() << "last.fm error:" << files[0][0] << files[0][1]
                     << respuesta->error();
        }

        if (!gotLink) {
            qDebug() << "last.fm miss, trying iTunes for"
                     << files[0][0] << files[0][1];
            QString url = "https://itunes.apple.com/search?";
            url += "term=" + QUrl::toPercentEncoding(files[0][0] + " " + files[0][1])
                   + "&entity=album&limit=1";
            action = "link-fallback";
            QNetworkRequest req{QUrl(url)};
            req.setHeader(QNetworkRequest::UserAgentHeader, "FlowPlayer/1.0");
            wdatos->get(req);
        }
        return;
    }

    // --- Stage 2: iTunes fallback query ---
    if (action == "link-fallback")
    {
        bool gotLink = false;

        if (respuesta->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(respuesta->readAll());
            QJsonArray results = doc.object().value("results").toArray();
            if (!results.isEmpty()) {
                QString art = results.first().toObject()
                                   .value("artworkUrl100").toString();
                art.replace("100x100bb", "600x600bb");
                art.replace("100x100", "600x600");
                if (!art.isEmpty()) {
                    qDebug() << "iTunes link for" << files[0][0] << files[0][1] << art;
                    downloadImage(art);   // sets action = "image"
                    gotLink = true;
                }
            }
        } else {
            qDebug() << "iTunes error:" << files[0][0] << files[0][1]
                     << respuesta->error();
        }

        if (!gotLink) {
            qDebug() << "both sources failed for" << files[0][0] << files[0][1];
            emit imgLoaded("ERROR", current);
            files.removeAt(0);
            if (files.count() > 0)
                checkAll();
            else
                emit downloadDone();
        }
        return;
    }

    // --- Stage 3: image download (unchanged, but the error path now lives here) ---
    if (action == "image")
    {
        if (respuesta->error() != QNetworkReply::NoError) {
            qDebug() << "image download failed:" << files[0][0] << files[0][1]
                     << respuesta->error();
            emit imgLoaded("ERROR", current);
            files.removeAt(0);
            if (files.count() > 0)
                checkAll();
            else
                emit downloadDone();
            return;
        }

        qDebug() << "saving image for" << files[0][0] << files[0][1];
        QString tmp = saveToDisk(respuesta);
        emit imgLoaded(tmp, current);
        files.removeAt(0);
        if (files.count() > 0)
            checkAll();
        else
            emit downloadDone();
        return;
    }

    // --- Stage 4: external image download (used by artist images) ---
    if (action == "imageextern")
    {
        qDebug() << "saving image for" << curImage;
        QString tmp = saveToDiskExtern(respuesta);
        emit imgLoaded(tmp, current);
        return;
    }
}

void WebThread::cancel()
{
    files.clear();
}

void WebThread::downloadImage(QString link)
{
    action = "image";
    curImage = link;
    wdatos->get(QNetworkRequest(QUrl(link)));
}

void WebThread::downloadImageExtern(QString link, int index)
{
    action = "imageextern";
    curImage = link;
    curImageIndex = index;
    qDebug() << "downloading extern image" << link;
    wdatos->get(QNetworkRequest(QUrl(link)));
}

QString WebThread::saveToDisk(QIODevice *reply)
{

    QString art = files[0][0];
    QString alb = files[0][1];
    QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(art, alb) + ".jpeg";

    QImage image = QImage::fromData(reply->readAll());
    image.save(th2, "JPEG");

    return th2;
}

QString WebThread::saveToDiskExtern(QIODevice *reply)
{
    QImage image = QImage::fromData(reply->readAll());

    QString path = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/flowplayer/" + hash(curImage) + ".jpeg";

    image.save(path, "JPEG");

    return path;
}

