#ifndef META_H
#define META_H

#include <QQuickItem>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>

#include "taglib/fileref.h"
#include "taglib/tag.h"

#include "globalutils.h"
#include "mydatabase.h"

class Meta : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QString title READ title NOTIFY dataChanged)
    Q_PROPERTY(QString album READ album NOTIFY dataChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY dataChanged)
    Q_PROPERTY(QString year READ year NOTIFY dataChanged)
    Q_PROPERTY(QString genre READ genre NOTIFY dataChanged)
    Q_PROPERTY(QString filename READ filename NOTIFY dataChanged)

public:
    Meta(QQuickItem *parent = 0);

    QString title() const { return m_title; }
    QString album() const { return m_album; }
    QString artist() const { return m_artist; }
    QString year() const { return m_year; }
    QString genre() const { return m_genre; }
    QString filename() const { return m_filename; }
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_year;
    QString m_genre;
    QString m_filename;

    QString currentFile;

    QString reemplazar1(QString data);
    QString reemplazar2(QString data);

private:
    TagLib::FileRef *tagFile;
    TagLib::File* getFileByMimeType(QString file);
    QString readGenre();
    QSqlDatabase db;

public slots:
    void setFile(QString file, QString update="true");
    void setData(QString title, QString artist, QString album, QString year);
    void setAlbumData(QString artist, QString album, QString year);
    void setGenre(QString genre);

signals:
    void dataChanged();
    void dataAlbumChanged();
    void genreSaved();

};

#endif // META_H
