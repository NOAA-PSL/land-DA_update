#!/bin/bash 

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        jedi_path=$1
else 
        jedi_path="/scratch2/BMC/gsienkf/UFS-RNR/UFS-RNR-stack/external/ioda-bundle/iodaconv/src/land"
fi 

/bin/cp -f ${jedi_path}/imsfv3_scf2ioda.py . 

