#!/bin/bash


ICONSET=$1


FILES=set-$ICONSET/*.png
SPRITEFN=sprite.png
CSSFN=../suffix.css

FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 22x22 -quality 100 $SPRITEFN

echo ".icon { background-image: url(icons/$SPRITEFN); background-repeat: no-repeat;}" > $CSSFN

pad=44
pos=22
for i in $FILES ; do
	bn=$(basename $i)
	ns=${bn%.*}
	echo ".icon.suffix-$ns { background-position: left -${pos}px; }" >> $CSSFN
	test $ns = "unknown" && echo ".icon { background-position: left -${pos}px; }" >> $CSSFN
	pos=$(( $pos + $pad))
	
done
