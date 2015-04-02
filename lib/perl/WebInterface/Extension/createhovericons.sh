#!/bin/bash

for i in */htdocs/*.png */htdocs/images/*.png ; do
	[[ $i =~ -hover.png ]] &&  continue

	su=${i##*.}
	ti=${i%%.*}-hover.$su

	test "$i" -nt "$ti" && convert "$i" -fill "#000000" -opaque "#808080" $ti

done
