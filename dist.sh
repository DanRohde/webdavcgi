#!/bin/bash
RELEASE=`cat RELEASE`
TMPPATH=/tmp/webdavcgi-${RELEASE}

test -e ${TMPPATH} && rm -rf ${TMPPATH}

svn export svn://svn.code.sf.net/p/webdavcgi/code/trunk ${TMPPATH}


(cd `dirname ${TMPPATH}`; zip -r  webdavcgi-${RELEASE}.zip `basename ${TMPPATH}`)
(cd `dirname ${TMPPATH}`; tar jcf webdavcgi-${RELEASE}.tar.bz2 `basename ${TMPPATH}`)
(cd $(dirname ${TMPPATH}); cp webdavcgi-${RELEASE}.zip  webdavcgi-latest.zip)
(cd $(dirname ${TMPPATH}); cp webdavcgi-${RELEASE}.tar.bz2 webdavcgi-latest.tar.bz2 )
