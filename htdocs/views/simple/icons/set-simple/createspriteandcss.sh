#!/bin/bash


SPRITEFN=../sprite.png
CSSFN=../../suffix.css


echo ".icon { background-image: url(icons/sprite.png); background-repeat: no-repeat;}" > $CSSFN

FILES=""
pad=44
pos=22
for category in $(cat categories) ; do
	FILES="$FILES templates/${category}.png"
	if [ $category  = "unknown" ] ; then
		echo ".icon { background-position: left -${pos}px; }" >> $CSSFN
	else 
		echo ".icon.category-$category { background-position: left -${pos}px; }" >> $CSSFN
	fi
	pos=$(( $pos + $pad))
done

FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 20x22 -quality 100 $SPRITEFN
