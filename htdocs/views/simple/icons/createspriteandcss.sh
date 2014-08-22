#!/bin/bash


ICONSET=$1


FILES=set-$ICONSET/*.png
SPRITEFN=sprite.png
CSSFN=../suffix.css

FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 22x22 $SPRITEFN

rm $CSSFN
pad=44
pos=22
for i in $FILES ; do
	bn=$(basename $i)
	ns=${bn%.*}
	echo ".icon.suffix-$ns { background: url(icons/$SPRITEFN) no-repeat left -${pos}px; }" >> $CSSFN
	test $ns = "unknown" && echo ".icon { background: url(icons/$SPRITEFN) no-repeat left -${pos}px; }" >> $CSSFN
	pos=$(( $pos + $pad))
	
done
