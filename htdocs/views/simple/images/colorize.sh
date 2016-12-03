#!/bin/bash
## needs ImageMagick's montage

FILES="about.png addbookmark.png bookmarks.png copy.png cut.png delete.png download.png edit.png group.png paste.png refresh.png remove.png rename.png upload.png user-edit.png user-properties.png view-filter.png cancel.png createfolder.png createfile.png createlink.png changedir.png toggleselection.png logout.png help.png home.png add.png search.png settings.png refresh-start.png refresh-pause.png refresh-stop.png selectall.png selectnone.png contact.png size.png sigma.png fullscreen-on.png fullscreen-off.png bookmark.png uploaddir.png fileactions.png save.png"

test "$#" = "0" && exit 1
set1=set-$1
set2=set-$2
from=$3
to=$4

echo "set1=$set1  set2=$set2 from=$from to=$to"

i=1
for f in $FILES ; do
    convert ${set1}/$f -fill "${to:=#000000}" -opaque "${from:=#808080}" ${set2}/$f
done

