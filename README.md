# torrentexpander

It can expand rar archives (including multipart) and zip archives, but it can also manage many audio and video files.
It can also solve numbering issues on TV series and cleanup filenames.
It also has the ability to move TV series / movies / music files to a folder of your choice.

The script is launched by Transmission.

QTransmission/etc/settings.json:

```
"script-torrent-done-enabled": true,
"script-torrent-done-filename": "/share/CACHEDEV1_DATA/.qpkg/QTransmission/scripts/torrentexpander.sh"
```


The script is copied from https://code.google.com/archive/p/torrentexpander/
