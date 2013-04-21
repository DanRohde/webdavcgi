#!/bin/bash
## needs ImageMagick's montage

FILES="about.png addbookmark.png bookmarks.png copy.png cut.png delete.png download.png edit.png group.png paste.png refresh.png remove.png rename.png upload.png user-edit.png user-properties.png view-filter.png zip.png"


FILESWITHNULL="null: $(echo $FILES | sed -e 's@ @ null: @g')"
montage $FILESWITHNULL -tile 1x -shadow -background none -geometry 16x16+0+0 sprite.png

