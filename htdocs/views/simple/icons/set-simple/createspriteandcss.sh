#!/bin/bash


SPRITEFN=../sprite.png
CSSFN=../../suffix.css

CATCSSFN=.category.css
ICONCSSFN=.icon.css


echo ".icon { background-image: url(icons/sprite.png); background-repeat: no-repeat;}" > $CATCSSFN

FILES=""
ft=0
cg=0
pad=44
pos=22
while read category suffixes ; do
	FILES="$FILES templates/${category}.png"
	if [ $category  = "unknown" ] ; then
		echo ".icon { background-position: left -${pos}px; }" >> $CATCSSFN
	else 
		echo ".category-$category { background-position: left -${pos}px; }" >> $CATCSSFN
		for suffix in $suffixes; do
			echo ".icon.suffix-$suffix { background-position: left -${pos}px; }" >> $ICONCSSFN
			ft=$(( $ft + 1 ))
		done
	fi
	pos=$(( $pos + $pad))
	cg=$(( $cg + 1 ))
	
done < filetypes

cat $CATCSSFN $ICONCSSFN > $CSSFN
rm $CATCSSFN $ICONCSSFN

FILESWITHNULL="null: $(echo $FILES| sed -e 's@ @ null: @g')"

montage $FILESWITHNULL -tile 1x -background none -geometry 20x22 -quality 100 $SPRITEFN

echo "Statistics: $ft file types in $cg categories."
