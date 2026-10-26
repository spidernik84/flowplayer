#ifndef MISSINGARTISTS_H
#define MISSINGARTISTS_H

#include <QAbstractListModel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>

// Artists with no picture in the cache, and a sequential downloader that
// fetches them from TheAudioDB.
class MissingArtists : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int processed READ processed NOTIFY progressChanged)
    Q_PROPERTY(int found READ found NOTIFY progressChanged)

public:
    enum MissingArtistRole
    {
        TitleRole = Qt::UserRole + 1,
        BandRole, CoverRole, SelRole, LoadingRole
    };

    explicit MissingArtists(QObject * parent = 0);
    virtual ~MissingArtists();
    virtual int rowCount(const QModelIndex & parent = QModelIndex()) const;
    virtual QVariant data(const QModelIndex & index , int role = Qt::DisplayRole) const;
    QHash<int, QByteArray> roleNames() const;

    int count() const { return rowCount(); }
    bool loaded() const { return m_loaded; }
    bool running() const { return m_running; }
    int processed() const { return m_processed; }
    int found() const { return m_found; }

signals:
    void countChanged();
    void loadChanged();
    void runningChanged();
    void progressChanged();
    void artistImageChanged(QString imagepath);

public slots:
    void loadData();
    void clearList();
    void selectItem(int index);
    void startDownload();
    void cancelAll();

private slots:
    void searchNext();
    void searchFinished();
    void imageFinished();

private:
    struct Item
    {
        QString artist, albums, coverart;
        bool isSelected, loading;
    };

    void setRunning(bool running);
    void itemDone(const QString &coverart);
    void scheduleNext(int delay);

    QList<Item> items;
    QNetworkAccessManager *network;
    QNetworkReply *reply;
    QTimer timer;
    int current;
    int retries;
    int m_processed, m_found;
    bool m_loaded, m_running;
};

#endif // MISSINGARTISTS_H
