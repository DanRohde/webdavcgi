#!/bin/bash 
##################################################################
# (C) ZE Computer- Medienservice, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
##################################################################
set -e

DEBUG=0
DONTCOMPRESS=0
FORCEMINIFY=0
while getopts "dnf" arg; do
    case "${arg}" in
        d)
            DEBUG=1
            ;;
        n)
            DONTCOMPRESS=1
            ;;
        f)  FORCEMINIFY=1
            ;;
    esac
done

QUERYSTRING="lib/QueryString/jquery-querystring.js"
MYSANHELPER="lib/MySwissArmyKnife/jquery-myswissarmyknife.js"
MYKEYBOARDEVENTHANDLER="lib/MyKeyboardEventHandler/jquery-mykeyboardeventhandler.js"
MYTOOLTIPLIB="lib/MyTooltip/jquery-mytooltip.js lib/MyTooltip/mytooltip.css"
MYPOPUPLIB="lib/MyPopup/jquery-mypopup.js lib/MyPopup/mypopup.css"
MYINPLACEEDITOR="lib/MyInplaceEditor/jquery-myinplaceeditor.js"
MYTABLEMANAGER="lib/MyTableManager/jquery-mytablemanager.js lib/MyTableManager/mytablemanager.css"

MYLIBS="${QUERYSTRING} ${MYSANHELPER} ${MYKEYBOARDEVENTHANDLER} ${MYTOOLTIPLIB} ${MYPOPUPLIB} ${MYINPLACEEDITOR} ${MYTABLEMANAGER} script.js style.css suffix.css"

COMPLETE=complete

rm -f ${COMPLETE}.min.*

for file in $MYLIBS ; do
    dir=$(dirname "${file}")
    bfn=$(basename "${file}")
    ext=${bfn#*.}
    bn=$(basename "${bfn}" ".${ext}")
    newfile="${dir}/${bn}.min.${ext}"
    complfile="${COMPLETE}.min.${ext}"
    if test "${DONTCOMPRESS}" -eq 0 ; then
        if test \( ${FORCEMINIFY} -eq 1 \) -o \( ! -e ${newfile} \) -o \( "${file}" -nt "${newfile}" \) ; then
            test ${DEBUG} -ne 0  && echo "Minify $file to $newfile and concat to $complfile"

            java -jar /etc/webdavcgi/minify/yuicompressor.jar $file \
                 | tee -a "${complfile}" \
                 > "${newfile}"
        else
            test ${DEBUG} -ne 0 && echo "Nothing to minify for ${file} -> concat only."
            cat "${newfile}" >> "${complfile}"
        fi
    else
        test ${DEBUG} -ne 0  && echo "Copy $file to $newfile and concat to $complfile"
        tee -a "${complfile}" < "${file}" >  "${newfile}"
    fi
done
test ${DEBUG} -ne 0 && echo "gzip ${COMPLETE}.min.*"
gzip ${COMPLETE}.min.*
exit 0
