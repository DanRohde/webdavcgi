#!/bin/bash 

while (( "$#" )) ; do
	echo $1
    java -jar /etc/webdavcgi/minify/yuicompressor-2.4.8.jar $1  | gzip -c > ${1%.*}.min.${1##*.}.gz
    shift
done

