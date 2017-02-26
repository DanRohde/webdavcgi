#!/bin/bash 
##################################################################
# (C) ZE Computer- Medienservice, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
##################################################################

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
MYSANHELPER="lib/MySwissArmyKnife/jquery-myswissarmyknife.js lib/MySwissArmyKnife/myswissarmyknife.css"
MYKEYBOARDEVENTHANDLER="lib/MyKeyboardEventHandler/jquery-mykeyboardeventhandler.js"
MYTOOLTIPLIB="lib/MyTooltip/jquery-mytooltip.js lib/MyTooltip/mytooltip.css"
MYPOPUPLIB="lib/MyPopup/jquery-mypopup.js lib/MyPopup/mypopup.css"
MYINPLACEEDITOR="lib/MyInplaceEditor/jquery-myinplaceeditor.js"
MYTABLEMANAGER="lib/MyTableManager/jquery-mytablemanager.js lib/MyTableManager/mytablemanager.css"
MYCOUNTDOWNTIMER="lib/MyCountdownTimer/jquery-mycountdowntimer.js"
MYFOLDERTREE="lib/MyFolderTree/jquery-myfoldertree.js lib/MyFolderTree/myfoldertree.css"
MYSPLITPANE="lib/MySplitPane/jquery-mysplitpane.js lib/MySplitPane/mysplitpane.css"
MYMAIN="script.js style.css svg/inlinestyle.css"
MYLIBS="${QUERYSTRING} ${MYSANHELPER} ${MYKEYBOARDEVENTHANDLER} ${MYTOOLTIPLIB} ${MYPOPUPLIB} ${MYINPLACEEDITOR} ${MYTABLEMANAGER} ${MYCOUNTDOWNTIMER} ${MYFOLDERTREE} ${MYSPLITPANE} ${MYMAIN}"

COMPLETE="complete"
SPRITE="svg/sprite.svg"

rm -f ${COMPLETE}.min.*

for file in $MYLIBS ; do
    dir=$(dirname "${file}")
    bfn=$(basename "${file}")
    ext=${bfn#*.}
    bn=$(basename "${bfn}" ".${ext}")
    newfile="${dir}/${bn}.min.${ext}"
    complfile="${COMPLETE}.min.${ext}"
    if test "${DONTCOMPRESS}" -eq 0 ; then
        grep -q '/**INCLUDE(' "${file}"
        if test \( $? -eq 0 \) -o \( ${FORCEMINIFY} -eq 1 \) -o \( ! -e ${newfile} \) -o \( "${file}" -nt "${newfile}" \) ; then
            test ${DEBUG} -ne 0  && echo "Minify $file to $newfile and concat to $complfile"

            perl prepjs.pl "$file" | java -jar /etc/webdavcgi/minify/yuicompressor.jar --type "${ext}" \
                 | tee -a "${complfile}" \
                 > "${newfile}"
        else
            test ${DEBUG} -ne 0 && echo "Nothing to minify for ${file} -> concat only."
            perl prepjs.pl "${newfile}" >> "${complfile}"
        fi
    else
        test ${DEBUG} -ne 0  && echo "Copy $file to $newfile and concat to $complfile"
        perl prepjs.pl "${file}" | tee -a "${complfile}" >  "${newfile}"
    fi
done
test ${DEBUG} -ne 0 && echo "(brotli|gzip) ${COMPLETE}.min.*"
for f in ${COMPLETE}.min.* $SPRITE ; do
    test ! -e $f && continue
    brotli < "${f}" > "${f}.br"
    gzip -f "${f}" 
done

exit 0
