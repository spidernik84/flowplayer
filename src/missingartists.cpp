#include "missingartists.h"
#include "globalutils.h"
#include "mydatabase.h"
#include "version.h"

#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrlQuery>

// TheAudioDB free API key. It allows 30 requests per minute, so searches are
// spaced out; image downloads come from their CDN and don't count.
#define AUDIODB_URL "https://www.theaudiodb.com/api/v1/json/123/search.php"
#define SEARCH_INTERVAL 2100
#define RATE_LIMIT_WAIT 30000
#define MAX_RETRIES 3

static QString artistImagePath(const QString &artist)
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/artist-" + hash(artist) + ".jpeg";
}

// Last.fm used to hand out the same 300x300 grey star for every artist, and
// older versions saved it as the artist picture. It is flat light grey and
// white, which no real photo is.
static bool isLastFmPlaceholder(const QString &path)
{
    QImageReader reader(path);
    if (reader.size() != QSize(300, 300))
        return false;

    QImage image = reader.read();
    if (image.isNull())
        return false;

    for (int y = 2; y < image.height(); y += 6) {
        for (int x = 2; x < image.width(); x += 6) {
            QRgb px = image.pixel(x, y);
            int r = qRed(px), g = qGreen(px), b = qBlue(px);
            if (qMin(r, qMin(g, b)) < 220 || qMax(r, qMax(g, b)) - qMin(r, qMin(g, b)) > 8)
                return false;
        }
    }
    return true;
}

static QString unescape(QString data)
{
    data.replace("&amp;", "&");
    data.replace("&lt;", "<");
    data.replace("&gt;", ">");
    data.replace("&quot;", "\"");
    data.replace("&apos;", "\'");
    return data;
}

static QNetworkRequest audioDbRequest(const QUrl &url)
{
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "FlowPlayer/" VERSION " (https://github.com/sailfishos-applications/flowplayer)");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    return req;
}

MissingArtists::MissingArtists(QObject * parent) :
        QAbstractListModel(parent), reply(0), current(-1), retries(0),
        m_processed(0), m_found(0), m_loaded(false), m_running(false)
{
    network = new QNetworkAccessManager(this);
    timer.setSingleShot(true);
    connect(&timer, &QTimer::timeout, this, &MissingArtists::searchNext);
}

MissingArtists::~MissingArtists()
{
}

QHash<int, QByteArray> MissingArtists::roleNames() const
{
    QHash <int, QByteArray> roles;
    roles.insert(TitleRole , "title");
    roles.insert(BandRole , "band");
    roles.insert(CoverRole , "coverart");
    roles.insert(SelRole , "isSelected");
    roles.insert(LoadingRole , "loading");
    return roles;
}

int MissingArtists::rowCount(const QModelIndex & parent) const
{
    Q_UNUSED(parent)
    return items.size();
}

QVariant MissingArtists::data(const QModelIndex & index , int role) const
{
    if (index.row() < 0 || index.row() >= items.size())
        return QVariant();

    const Item &item = items.at(index.row());
    switch(role)
    {
    case TitleRole:
        return item.artist;
    case BandRole:
        return item.albums;
    case CoverRole:
        return item.coverart;
    case SelRole:
        return item.isSelected;
    case LoadingRole:
        return item.loading;
    default:
        return QVariant();
    }
}

void MissingArtists::loadData()
{
    const QString unknown = QCoreApplication::translate("DataReader", "Unknown artist");

    beginResetModel();
    items.clear();

    QSqlQuery query = getQuery(QString("select artist, count(distinct album) as acount from tracks "
                                       "group by artist order by artist collate nocase"));
    while( query.next() )
    {
        QString artist = unescape(query.value(0).toString());
        if (artist.trimmed().isEmpty() || artist==unknown || artist=="Unknown artist")
            continue;
        QString path = artistImagePath(artist);
        if (QFileInfo(path).exists()) {
            if (!isLastFmPlaceholder(path))
                continue;
            qDebug() << "Removing Last.fm placeholder for" << artist;
            QFile::remove(path);
        }

        int albums = query.value(1).toInt();
        Item item;
        item.artist = artist;
        item.albums = albums==1 ? tr("1 album") : tr("%1 albums").arg(albums);
        item.isSelected = true;
        item.loading = false;
        items.append(item);
    }

    endResetModel();
    qDebug() << "Missing artist images: " << items.count();

    m_processed = 0;
    m_found = 0;
    emit progressChanged();
    emit countChanged();
    m_loaded = true;
    emit loadChanged();
}

void MissingArtists::clearList()
{
    cancelAll();
    m_loaded = false;
    emit loadChanged();
    beginResetModel();
    items.clear();
    endResetModel();
    emit countChanged();
}

void MissingArtists::selectItem(int index)
{
    if (index < 0 || index >= items.size() || m_running)
        return;
    items[index].isSelected = !items[index].isSelected;
    emit dataChanged(this->index(index), this->index(index));
}

void MissingArtists::setRunning(bool running)
{
    if (m_running == running)
        return;
    m_running = running;
    emit runningChanged();
}

void MissingArtists::startDownload()
{
    if (m_running)
        return;

    qDebug() << "Starting artist image download...";
    m_processed = 0;
    m_found = 0;
    emit progressChanged();
    current = -1;
    setRunning(true);
    searchNext();
}

void MissingArtists::cancelAll()
{
    timer.stop();
    retries = 0;
    setRunning(false);
    if (reply) {
        QNetworkReply *r = reply;
        reply = 0;
        r->abort();
    }
    if (current >= 0 && current < items.size() && items[current].loading) {
        items[current].loading = false;
        emit dataChanged(index(current), index(current));
    }
    current = -1;
}

void MissingArtists::scheduleNext(int delay)
{
    if (m_running)
        timer.start(delay);
}

// Advances to the next selected artist that hasn't been tried yet
void MissingArtists::searchNext()
{
    if (!m_running)
        return;

    if (retries == 0) {
        do {
            ++current;
        } while (current < items.size() && (!items[current].isSelected || !items[current].coverart.isEmpty()));
    }

    if (current >= items.size()) {
        current = -1;
        setRunning(false);
        return;
    }

    items[current].loading = true;
    emit dataChanged(index(current), index(current));

    QUrl url(AUDIODB_URL);
    QUrlQuery q;
    q.addQueryItem("s", items[current].artist);
    url.setQuery(q);

    reply = network->get(audioDbRequest(url));
    connect(reply, &QNetworkReply::finished, this, &MissingArtists::searchFinished);
}

void MissingArtists::searchFinished()
{
    QNetworkReply *r = qobject_cast<QNetworkReply*>(sender());
    r->deleteLater();
    if (r != reply)
        return; // canceled
    reply = 0;

    int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 429 && retries < MAX_RETRIES) {
        ++retries;
        qDebug() << "TheAudioDB rate limit hit, waiting before retrying" << items[current].artist;
        scheduleNext(RATE_LIMIT_WAIT);
        return;
    }
    retries = 0;

    QString thumb;
    if (r->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(r->readAll());
        QJsonArray artists = doc.object().value("artists").toArray();
        // Prefer an exact name match, otherwise take TheAudioDB's best result
        for (int i = 0; i < artists.count() && thumb.isEmpty(); ++i) {
            QJsonObject a = artists.at(i).toObject();
            if (a.value("strArtist").toString().compare(items[current].artist, Qt::CaseInsensitive) == 0)
                thumb = a.value("strArtistThumb").toString();
        }
        if (thumb.isEmpty() && !artists.isEmpty())
            thumb = artists.first().toObject().value("strArtistThumb").toString();
    } else {
        qDebug() << "TheAudioDB error:" << items[current].artist << r->error();
    }

    if (thumb.isEmpty()) {
        qDebug() << "No artist image for" << items[current].artist;
        itemDone("ERROR");
        scheduleNext(SEARCH_INTERVAL);
        return;
    }

    reply = network->get(audioDbRequest(QUrl(thumb)));
    connect(reply, &QNetworkReply::finished, this, &MissingArtists::imageFinished);
}

void MissingArtists::imageFinished()
{
    QNetworkReply *r = qobject_cast<QNetworkReply*>(sender());
    r->deleteLater();
    if (r != reply)
        return; // canceled
    reply = 0;

    QString result = "ERROR";
    if (r->error() == QNetworkReply::NoError) {
        QImage image = QImage::fromData(r->readAll());
        QString path = artistImagePath(items[current].artist);
        if (!image.isNull() && image.save(path, "JPEG")) {
            result = path;
            ++m_found;
            emit artistImageChanged(path);
        }
    } else {
        qDebug() << "Artist image download failed:" << items[current].artist << r->error();
    }

    itemDone(result);
    scheduleNext(SEARCH_INTERVAL);
}

void MissingArtists::itemDone(const QString &coverart)
{
    items[current].loading = false;
    items[current].coverart = coverart;
    emit dataChanged(index(current), index(current));
    ++m_processed;
    emit progressChanged();
}
