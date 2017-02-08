#!/bin/bash

for i in */htdocs/*.png */htdocs/images/*.png ; do
	[[ $i =~ -hover.png ]] &&  continue

	su=${i##*.}
	ti=${i%%.*}-hover.$su

	test "$i" -nt "$ti" && convert "$i" -fill "#000000" -opaque "#808080" $ti

done
for i in */htdocs/*.svg */htdocs/images/*.svg ; do
    [[ $i =~ -hover.svg ]] &&  continue

    su=${i##*.}
    ti=${i%%.*}-hover.$su

    test "$i" -nt "$ti" && sed -e 's/#808080/#000000/g' "$i" > $ti
        
done