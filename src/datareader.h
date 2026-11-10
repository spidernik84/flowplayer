#ifndef DATAREADER_H
#define DATAREADER_H

#include <QThread>
#include <QString>
#include <QStringList>
#include <QSet>

#include "taglib/fileref.h"
#include "taglib/tag.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>

#include "mydatabase.h"

class DataReader : public QThread
{
    Q_OBJECT

public:
    DataReader();

    QStringList files;
    QStringList favFiles;
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_year;
    QString m_duration;
    QString m_tracknum;
    QString m_discnum;
    QString m_genre;

    QString reemplazar1(QString data);
    QString reemplazar2(QString data);

    QList<QVariantMap> map;

    bool forceFinish;


private:
    TagLib::FileRef *tagFile;
    TagLib::File* getFileByMimeType(QString file);

    // The scan thread's own connection: a connection may only be used
    // from the thread that opened it, so the UI's one can't be shared
    QSqlDatabase db;
    bool scanQuery(const QString &qr);
    QSet<QString> scanColumn(const QString &column);
    void scan();

public slots:
    void openDB();
    void insertData(QString url, QString artist, QString album,
        QString title, int year, int tracknum, int discnum, int duration, QString genre);
    void saveData();
    void readFile(QString file);
    void addFile(QString file);
    void clearFiles();
    void run();

signals:
    void finished();
    void percent(int);
    void total(int);
    // Collection totals after a completed scan, and how many of each are new
    void summary(int tracks, int albums, int artists,
                 int newTracks, int newAlbums, int newArtists);

};

#endif // DATAREADER_H
