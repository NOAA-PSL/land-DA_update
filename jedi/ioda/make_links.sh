#!/bin/ksh 

if [ $# != 1 ]; then 
        echo 'ERROR: usage make_links.sh path-to-JEDI-ioda-bundle-src' 
        exit 
fi 

jedi_path=$1

ln -s ${jedi_path}/iodaconv/src/land/imsfv3_scf2ioda.py . 

