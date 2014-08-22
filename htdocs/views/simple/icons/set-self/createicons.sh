#!/bin/bash
#########################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################

while read tmpl exts ; do
	for e in $exts; do 
		pointsize=8
		if [ ${#e} -gt 4  ]; then
			pointsize=7
		fi
		test ${e}.png -nt templates/${tmpl}.png && continue
		##convert templates/${tmpl}.png -fill white +antialias -font Ubuntu-Regular -pointsize $pointsize -annotate +${posx}+10 ${e^^*} ${e}.png
		convert -size 20x22 xc:none -gravity center -fill white +antialias -font Ubuntu-Regular -pointsize $pointsize  -annotate 0 ${e^^*} -background none \
			templates/${tmpl}.png +swap -gravity north -geometry +0-4 -composite ${e}.png
		echo e=$e
	done
done < filetypes
