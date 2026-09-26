#ifndef RADIOS_H
#define RADIOS_H

#include <QQuickItem>

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QDebug>

#include "globalutils.h"
#include "mydatabase.h"

class Radios : public QQuickItem
{
    Q_OBJECT

public:
    Q_INVOKABLE bool radioExists(QString name, QString url);

    Radios(QQuickItem *parent = 0);

    QNetworkAccessManager* datos;

    QString reemplazar1(QString data);
    QString reemplazar2(QString data);

public slots:
    void loadRadios();
    void searchRadio(QString text);
    void getRadioInfo(QString uuid);
    void saveRadio(QString name, QString url, QString id, QString image);
    void removeRadio(QString name, QString url);

private:
    QNetworkReply *apiGet(QString path);
    QNetworkReply *searchReply = nullptr;

signals:
    void appendRadio(QString name, QString genre, QString radioid, QString image);
    void appendRadioSearch(QString name, QString genre, QString radioid, QString url, QString image);
    void appendRadioDone();
    void radioInfoLoaded(QString radiourl);

};

#endif // RADIOS_H
