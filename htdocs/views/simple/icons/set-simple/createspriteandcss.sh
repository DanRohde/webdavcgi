#!/bin/bash


SPRITEFN=../sprite.png
CSSFN=../../suffix.css



echo ".icon { background-image: url(icons/sprite.png); background-repeat: no-repeat;}" > $CSSFN

FILES=""
pad=44
pos=22
while read category suffixes ; do
	FILES="$FILES templates/${category}.png"
	for suffix in $suffixes; do
		echo ".icon.suffix-$suffix { background-position: left -${pos}px; }" >> $CSSFN
	done
	pos=$(( $pos + $pad))
	
done < filetypes
FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 20x22 -quality 100 $SPRITEFN
