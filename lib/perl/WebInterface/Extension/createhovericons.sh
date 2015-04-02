#!/bin/bash

for i in */htdocs/*.png ; do
	[[ $i =~ -hover.png ]] &&  continue

	su=${i##*.}
	ti=${i%%.*}-hover.$su

	convert "$i" -fill "#000000" -opaque "#808080" $ti

done
