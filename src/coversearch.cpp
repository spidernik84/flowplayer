#include "coversearch.h"

//#include <QDeclarativeView>
#include <QDebug>
#include <QDir>
#include <QString>
#include <QStringList>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>
#include <QUrlQuery>

#define AUDIODB_URL "https://www.theaudiodb.com/api/v1/json/123/search.php"
#define AUDIODB_ALBUM_URL "https://www.theaudiodb.com/api/v1/json/123/searchalbum.php"

struct CoverSearchItem
{
    QString name;
    QString desc;
    QString art;
};

class CoverSearch::CoverSearchPrivate
{
public:
    CoverSearchPrivate(CoverSearch * parent);
    ~CoverSearchPrivate();
    void populateItems();
    QList <CoverSearchItem * > items;
    CoverSearch * const q;
    QStringList foundedCovers;
    QString searchArt, searchAlb, searchData;
    int searchTry, curDown;

};

CoverSearch::CoverSearchPrivate::CoverSearchPrivate(CoverSearch * parent) : q(parent)
{
    q->datos = new QNetworkAccessManager(parent);
    //connect(q->datos, SIGNAL(finished(QNetworkReply*)), parent, SLOT(downloaded(QNetworkReply*)));

    //q->pepe = new WebThread();
    //connect (q->pepe, SIGNAL(imgLoaded(QString,int)), parent, SLOT(paintImg(QString,int)) );

    // Ensure that download destination exists.
    QDir d;
    d.mkpath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
}

CoverSearch::CoverSearchPrivate::~CoverSearchPrivate()
{
    while(!items.isEmpty())
    {
        delete items.takeFirst();
    }
}

void CoverSearch::CoverSearchPrivate::populateItems()
{
    foundedCovers.removeAll("");
    foundedCovers.removeDuplicates();

    int itemsCount = items.count();
    int entriesCount = foundedCovers.count();

    //qDebug() << "Items: " << itemsCount << " - Entries: " << entriesCount;

    if(entriesCount < itemsCount)
    {
        q->beginRemoveRows(QModelIndex() , entriesCount , itemsCount);

        for (int i = entriesCount ; i < itemsCount ; i++)
            delete items.takeLast();

        q->endRemoveRows();
    }
    else if (entriesCount > itemsCount)
    {
        q->beginInsertRows(QModelIndex() , itemsCount , entriesCount - 1);

        for(int i = itemsCount ; i < entriesCount ; i++)
            items.append(new CoverSearchItem);

        q->endInsertRows();
    }

    QListIterator<QString> entriesIterator (foundedCovers);
    QListIterator<CoverSearchItem *> itemsIterator(items);

    while(entriesIterator.hasNext() && itemsIterator.hasNext())
    {
        CoverSearchItem * item = itemsIterator.next();
        item->name = entriesIterator.next();
        item->desc = item->name;
        item->art = "loading"; //item->name;
    }

    emit(q->countChanged());

    emit(q->dataChanged(q->index(0) , q->index(entriesCount - 1)));

}

CoverSearch::CoverSearch(QObject * parent) :
        QAbstractListModel(parent) , d (new CoverSearchPrivate(this))
{
    // Roles
    QHash <int, QByteArray> roles;
    roles.insert(NameRole , "name");
    roles.insert(DescRole , "date");
    roles.insert(ArtRole , "art");
    d->q->setRoleNames(roles);

}

QHash<int, QByteArray> CoverSearch::roleNames() const {
    return m_roles;
}

void CoverSearch::setRoleNames(const QHash<int, QByteArray>& roles) {
    m_roles = roles;
}

CoverSearch::~CoverSearch()
{
    delete d;
}

int CoverSearch::rowCount(const QModelIndex & parent) const
{
    Q_UNUSED(parent)
    return d->items.size();
}

QVariant CoverSearch::data(const QModelIndex & index , int role) const
{
    if(index.row() < 0 or index.row() > count())
    {
        return QVariant();
    }

    CoverSearchItem * item = d->items.at(index.row());
    switch(role)
    {
    case NameRole:
        return item->name;
        break;
    case DescRole:
        return item->desc;
        break;
    case ArtRole:
        return item->art;
        break;
    default:
        return QVariant();
        break;
    }
}

int CoverSearch::count() const
{
    return rowCount();
}

void CoverSearch::remove(const QString &file)
{
    QString nf = file;
    if ( nf.startsWith("//") )
        nf.remove(0, 1);
    QSettings settings(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/flowplayer.conf", QSettings::NativeFormat);
    QStringList entries = settings.value("CoverSearch","").toStringList();
    QStringList newfiles;
    for (int i=0; i< entries.count(); ++i)
    {
        if ( entries.at(i) != nf )
            newfiles.append( entries.at(i) );
    }
    settings.setValue("CoverSearch", newfiles);
    settings.sync();
    d->populateItems();
}

void CoverSearch::searchCover(QString artist, QString album, QString data)
{
    d->searchArt = artist;
    d->searchAlb = album;
    d->searchData = data;
    d->searchTry = 1;

    disconnect(datos, 0, 0, 0);
    connect(datos, SIGNAL(finished(QNetworkReply*)), this, SLOT(downloaded(QNetworkReply*)));

    QUrl url(AUDIODB_ALBUM_URL);
    QUrlQuery q;
    q.addQueryItem("s", d->searchArt);
    q.addQueryItem("a", d->searchAlb);
    url.setQuery(q);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "FlowPlayer/1.0");
    reply = datos->get(req);
}

// Artist pictures come from TheAudioDB, like the bulk download
void CoverSearch::searchArtist(QString data)
{
    d->searchData = data;
    d->searchTry = 4;

    disconnect(datos, 0, 0, 0);
    connect(datos, SIGNAL(finished(QNetworkReply*)), this, SLOT(downloaded(QNetworkReply*)));

    QUrl url(AUDIODB_URL);
    QUrlQuery q;
    q.addQueryItem("s", data);
    url.setQuery(q);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, "FlowPlayer/1.0");
    reply = datos->get(req);
}

void CoverSearch::downloaded(QNetworkReply *respuesta)
{
    if ( d->searchTry == 4 )
    {
        d->foundedCovers.clear();

        if (respuesta->error() != QNetworkReply::NoError)
        {
            qDebug() << "error: " << respuesta->error();
        }
        else
        {
            QJsonArray artists = QJsonDocument::fromJson(respuesta->readAll()).object().value("artists").toArray();
            foreach (const QJsonValue &artist, artists)
            {
                QJsonObject a = artist.toObject();
                d->foundedCovers.append(a.value("strArtistThumb").toString());
                d->foundedCovers.append(a.value("strArtistFanart").toString());
                d->foundedCovers.append(a.value("strArtistFanart2").toString());
                d->foundedCovers.append(a.value("strArtistFanart3").toString());
                d->foundedCovers.append(a.value("strArtistFanart4").toString());
            }
        }

        d->populateItems();

        if ( d->foundedCovers.count() > 0 )
        {
            d->curDown = 0;
            d->searchTry = 3;
            reply = datos->get(QNetworkRequest(QUrl(d->foundedCovers.at(0))));
        }
        else
        {
            emit downloadFinished();
        }
        emit searchFinished();
    }
    else if ( d->searchTry == 1 )
    {
        d->foundedCovers.clear();

        if (respuesta->error() != QNetworkReply::NoError)
        {
            qDebug() << "error: " << respuesta->error();
        }
        else
        {
            QJsonArray albums = QJsonDocument::fromJson(respuesta->readAll()).object().value("album").toArray();
            foreach (const QJsonValue &album, albums)
                d->foundedCovers.append(album.toObject().value("strAlbumThumb").toString());
        }

        // Then iTunes, with the text typed in the search field
        d->searchTry = 2;
        QUrl url("https://itunes.apple.com/search");
        QUrlQuery q;
        q.addQueryItem("term", d->searchData);
        q.addQueryItem("entity", "album");
        q.addQueryItem("limit", "12");
        url.setQuery(q);
        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::UserAgentHeader, "FlowPlayer/1.0");
        reply = datos->get(req);

    }
    else if ( d->searchTry == 2 )
    {
        if (respuesta->error() != QNetworkReply::NoError)
        {
            qDebug() << "error: " << respuesta->error();
        }
        else
        {
            QJsonArray results = QJsonDocument::fromJson(respuesta->readAll()).object().value("results").toArray();
            foreach (const QJsonValue &result, results)
            {
                QString art = result.toObject().value("artworkUrl100").toString();
                art.replace("100x100bb", "600x600bb");
                art.replace("100x100", "600x600");
                d->foundedCovers.append(art);
            }
        }

        d->populateItems();

        if ( d->foundedCovers.count() > 0 )
        {
            d->curDown = 0;
            d->searchTry = 3;
            reply = datos->get(QNetworkRequest(QUrl(d->foundedCovers.at(0))));
        }
        else
        {
            emit downloadFinished();
        }
        emit searchFinished();
    }
    else if ( d->searchTry == 3 )
    {
        QImage image = QImage::fromData(reply->readAll());
        QString path = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/" + hash(d->foundedCovers.at(0)) + ".jpeg";
        image.save(path, "JPEG");
        d->items.at(d->curDown)->art = path;
        emit(d->q->dataChanged(d->q->index(d->curDown) , d->q->index(d->curDown)));

        if (d->foundedCovers.count()>0)
            d->foundedCovers.removeFirst();

        if (d->foundedCovers.count()>0) {
            d->curDown = d->curDown +1;
            d->searchTry = 3;
            QString url = d->foundedCovers.at(0);
            reply = datos->get(QNetworkRequest(QUrl(url)));
        } else {
            emit downloadFinished();
        }

    }


}

void CoverSearch::clearData()
{
    d->foundedCovers.clear();
    d->populateItems();
}

void CoverSearch::stopSearch()
{
    //if ( reply && reply->isRunning() )
    //    reply->abort();
    disconnect(datos, 0, 0, 0);
    clearData();
}

void CoverSearch::paintImg(QString image, int index)
{
    /*qDebug() << "LOADED " << index << " - " << image;

    if (d->items.count()>0) {
        d->items.at(index)->art = image;
        emit(d->q->dataChanged(d->q->index(index) , d->q->index(index)));
    }

    for (int i=0; i<d->items.count(); ++i)
    {
        if (d->items.at(i)->art=="") {
            pepe->downloadImageExtern(d->foundedCovers.at(i), i);
            break;
        }
    }*/
    //emit d->q->albumCoverChanged(image);
}

void CoverSearch::saveImage(QString artist, QString album, QString imagepath)
{
    QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/media-art/album-"+ doubleHash(artist, album) + ".jpeg";

    QImage image(imagepath);
    image.save(th2, "JPEG");

    emit imageChanged(artist, album);
}

void CoverSearch::saveArtistImage(QString artist, QString imagepath)
{
    QString th2 = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/artist-" + hash(artist) + ".jpeg";

    QImage image(imagepath);
    image.save(th2, "JPEG");

    emit imageChanged(artist, "");
}
