# Known bugs

Bugs found while working on other features, left for later.

## Album metadata editor calls a missing function

`qml/pages/AlbumMetadata.qml:50` calls `misdatos.loadData(utils.order)`, but
`Datos` (`src/datos.h`) has no `loadData()`.

When the album editor is accepted, the tags are saved, then `misdatos.clearList()`
empties the library list and the `loadData()` call throws a QML error. The
artists/albums list stays empty until it is reloaded some other way.

Likely fix: reload the current group the way `Metadata.qml` does (`loadAlbums`,
`loadArtists` or `loadSongs`, depending on `lastGroup`).

## Track metadata edits never reach playlists and the queue

`Meta::setData()` (`src/meta.cpp:74` and `:79`) runs
`UPDATE playlists SET ..., year=%4 ...` and `UPDATE queue SET ..., year=%4 ...`,
but the `playlists` and `queue` tables have no `year` column
(`src/datareader.cpp`, `DataReader::openDB()`).

SQLite rejects both statements and `executeQuery()` ignores the failure, so
editing a track's title, artist or album updates the library and the file
tags, but playlists and the queue keep the old values.

Likely fix: drop `year` from those two statements, as `Meta::setAlbumData()`
already does.
