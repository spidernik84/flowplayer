#include "radios.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>

#include "version.h"

bool Radios::radioExists(QString name, QString url)
{
    name = reemplazar1(name);
    url = reemplazar1(url);
    bool res = executeQueryCheckCount(QString("select * from radio where name='%1' and url='%2'").arg(name).arg(url));
    qDebug() << "radio exits " << name << res;
    return res;
}

Radios::Radios(QQuickItem *parent)
    : QQuickItem(parent)
{
    datos = new QNetworkAccessManager(this);
}

// Station directory: https://www.radio-browser.info
// all.api.radio-browser.info is the round-robin DNS name for every API server.
QNetworkReply *Radios::apiGet(QString path)
{
    QNetworkRequest req{QUrl("https://all.api.radio-browser.info" + path)};
    // The API asks clients to identify themselves
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "FlowPlayer/" VERSION " (https://github.com/sailfishos-applications/flowplayer)");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    return datos->get(req);
}

QString Radios::reemplazar1(QString data)
{
    data.replace("&","&amp;");
    data.replace("<","&lt;");
    data.replace(">","&gt;");
    data.replace("\"","&quot;");
    data.replace("\'","&apos;");
    return data;
}

QString Radios::reemplazar2(QString data)
{
    data.replace("&amp;", "&");
    data.replace("&lt;", "<");
    data.replace("&gt;", ">");
    data.replace("&quot;", "\"");
    data.replace("&apos;", "\'");
    return data;
}

void Radios::loadRadios()
{
    QSqlQuery query = getQuery(QString("select * from radio order by name"));

    while( query.next() )
    {
        QString dato1, dato2, dato3, dato4;
        dato1 = reemplazar2(query.value(0).toString());
        dato2 = reemplazar2(query.value(1).toString());
        dato3 = reemplazar2(query.value(2).toString());
        dato4 = reemplazar2(query.value(3).toString());

        emit appendRadio(dato1, dato2, dato3, dato4);
    }

}

void Radios::searchRadio(QString text)
{
    // A new search supersedes one still running
    if (searchReply)
        searchReply->abort();

    QUrlQuery query;
    query.addQueryItem("name", QString(QUrl::toPercentEncoding(text.trimmed())));
    query.addQueryItem("hidebroken", "true");
    query.addQueryItem("order", "clickcount");
    query.addQueryItem("reverse", "true");
    query.addQueryItem("limit", "100");

    qDebug() << "Searching radio" << text;
    QNetworkReply *reply = apiGet("/json/stations/search?" + query.toString(QUrl::FullyEncoded));
    searchReply = reply;

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply == searchReply)
            searchReply = nullptr;
        if (reply->error() == QNetworkReply::OperationCanceledError)
            return;
        if (reply->error() != QNetworkReply::NoError)
            qDebug() << "Radio search failed:" << reply->errorString();

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        foreach (const QJsonValue &value, doc.array())
        {
            QJsonObject station = value.toObject();

            // url_resolved has playlists (.pls/.m3u) already resolved to the stream
            QString url = station["url_resolved"].toString();
            if (url.isEmpty())
                url = station["url"].toString();
            if (url.isEmpty())
                continue;

            QStringList details;
            QString codec = station["codec"].toString();
            int bitrate = station["bitrate"].toInt();
            if (!codec.isEmpty() && codec != "UNKNOWN")
                details << (bitrate > 0 ? QString("%1 %2k").arg(codec).arg(bitrate) : codec);
            if (!station["countrycode"].toString().isEmpty())
                details << station["countrycode"].toString();
            if (!station["tags"].toString().isEmpty())
                details << station["tags"].toString().replace(",", ", ");

            emit appendRadioSearch(station["name"].toString().trimmed(), details.join(" · "),
                                   station["stationuuid"].toString(), url,
                                   station["favicon"].toString());
        }
        emit appendRadioDone();
    });
}

// Called when the user picks a station: /json/url registers the click (the
// directory's popularity ranking relies on it) and returns the stream url.
void Radios::getRadioInfo(QString uuid)
{
    qDebug() << "Getting radio info" << uuid;
    QNetworkReply *reply = apiGet("/json/url/" + QString(QUrl::toPercentEncoding(uuid.trimmed())));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        QJsonObject result = QJsonDocument::fromJson(reply->readAll()).object();
        QString url = result["url"].toString();
        if (reply->error() != QNetworkReply::NoError || !result["ok"].toBool() || url.isEmpty()) {
            qDebug() << "Radio info failed:" << reply->errorString() << result["message"].toString();
            emit radioInfoLoaded("ERROR");
            return;
        }
        emit radioInfoLoaded(url);
    });
}

void Radios::saveRadio(QString name, QString url, QString id, QString image)
{
    qDebug() << "Save radio" << name << url << id << image;
    name = reemplazar1(name);
    url = reemplazar1(url);
    image = reemplazar1(image);

    bool res = executeQueryCheckCount(QString("select from radio where name='%1' and url='%2'")
                                      .arg(name).arg(url));

    if (!res)
        res = executeQuery(QString("insert into radio values('%1','%2','%3','%4')")
                           .arg(name).arg(url).arg(id).arg(image));

    qDebug() << "ADDING " << name << res;

}

void Radios::removeRadio(QString name, QString url)
{
    name = reemplazar1(name);
    url = reemplazar1(url);
    bool res = executeQuery(QString("delete from radio where name='%1' and url='%2'")
                                      .arg(name).arg(url));
    qDebug() << "Removed radio " << name << res;

}
