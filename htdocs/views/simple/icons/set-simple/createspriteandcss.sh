#!/bin/bash


SPRITEFN=../sprite.png
CSSFN=../../suffix.css



echo ".icon { background-image: url(icons/sprite.png); background-repeat: no-repeat;}" > $CSSFN

FILES=""
ft=0
cg=0
pad=44
pos=22
while read category suffixes ; do
	FILES="$FILES templates/${category}.png"
	test $category  = "unknown" && echo ".icon { background-position: left -${pos}px; }" >> $CSSFN
	for suffix in $suffixes; do
		echo ".icon.suffix-$suffix { background-position: left -${pos}px; }" >> $CSSFN
		ft=$(( $ft + 1 ))
	done
	pos=$(( $pos + $pad))
	cg=$(( $cg + 1 ))
	
done < filetypes
FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 20x22 -quality 100 $SPRITEFN

echo "Statistics: $ft file types in $cg categories."
