#!/bin/bash 

FILES='style.css script.js'


for p in $(find . -type d -name htdocs) ; do
	for file in $FILES ; do
		bn=${file%.*}
		ext=${file#*.}
		newfile=${bn}.min.${ext}.gz 

		test "$p/$file" -nt "$p/$newfile" && java -jar /etc/webdavcgi/minify/yuicompressor.jar "$p/$file" | gzip -c > "$p/$newfile"
	done

done
