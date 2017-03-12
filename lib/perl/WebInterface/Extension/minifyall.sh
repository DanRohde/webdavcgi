#!/bin/bash 

FILES='style.css script.js'


for p in $(find . -type d -name htdocs) ; do
	for file in $FILES ; do
		bn=${file%.*}
		ext=${file#*.}
		newfile=${bn}.min.${ext} 

		if [ \( ! -e "$p/$newfile" \) -o \( "$p/$file" -nt "$p/$newfile" \) ]; then
			test -f "$p/$file" && yuglify --terminal --type "${ext}" < "$p/$file" > "$p/$newfile"
			test -f $"$p/$newfile" && gzip -c < "$p/$newfile" > "$p/${newfile}.gz"
		fi
	done

done

touch /etc/webdav*conf

exit 0
