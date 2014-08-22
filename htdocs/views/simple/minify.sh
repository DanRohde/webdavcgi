#!/bin/bash 

FILES='style.css suffix.css script.js'

for file in $FILES ; do
	bn=${file%.*}
	ext=${file#*.}
	newfile=${bn}.min.${ext}.gz 
#	echo "file=$file newfile=$newfile"

	test $file -nt $newfile && java -jar /etc/webdavcgi/minify/yuicompressor.jar $file | gzip -c > $newfile
done

#java -jar /etc/webdavcgi/minify/yuicompressor.jar style.css  | gzip -c > style.min.css.gz
#java -jar /etc/webdavcgi/minify/yuicompressor.jar script.js  | gzip -c > script.min.js.gz

exit 0
