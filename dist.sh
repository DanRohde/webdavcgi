#!/bin/bash
RELEASE=${1:-$(cat RELEASE)}
TMPPATH=/tmp
ARCBASE=webdavcgi-${RELEASE}
ARCFORMATS="zip tgz"

for format in ${ARCFORMATS} ; do
    git archive --format ${format} --output ${TMPPATH}/${ARCBASE}.${format} $RELEASE
done

