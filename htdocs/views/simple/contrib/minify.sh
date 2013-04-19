#!/bin/bash 

java -jar /etc/webdavcgi/minify/yuicompressor-2.4.2.jar $1  | gzip -c > ${1%.*}.min.${1##*.}.gz

