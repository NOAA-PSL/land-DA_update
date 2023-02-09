#!/bin/bash 

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        jedi_path=$1
else 
        jedi_path="/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/"
fi 

/bin/cp -R ${jedi_path}/fv3-jedi/test/Data/fv3files . 
/bin/cp -R ${jedi_path}/fv3-jedi/test/Data/fieldmetadata . 

