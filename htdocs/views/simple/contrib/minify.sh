#!/bin/bash 

while (( "$#" )) ; do
	echo $1
java -jar /etc/webdavcgi/minify/yuicompressor-2.4.7/build/yuicompressor-2.4.7.jar $1  | gzip -c > ${1%.*}.min.${1##*.}.gz
shift
done

