#ifndef GLOBALUTILS_H
#define GLOBALUTILS_H

#include <QString>
#include <QCryptographicHash>
#include <QRegExp>
#include <QStringList>

QString hash(QString info);
QString doubleHash(QString artist, QString album);
QString clear(QString data);
QString cleanItem(QString data);
QStringList splitGenres(QStringList values);


#endif // GLOBALUTILS_H
