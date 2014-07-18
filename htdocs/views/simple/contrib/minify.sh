#!/bin/bash 

java -jar /etc/webdavcgi/minify/yuicompressor-2.4.7/build/yuicompressor-2.4.7.jar $1  | gzip -c > ${1%.*}.min.${1##*.}.gz

