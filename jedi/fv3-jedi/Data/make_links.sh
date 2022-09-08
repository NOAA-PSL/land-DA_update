#!/bin/ksh 

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        jedi_path=$1
else 
        jedi_path="/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/"
fi 

ln -s ${jedi_path}/fv3-jedi/test/Data/fv3files . 
ln -s ${jedi_path}/fv3-jedi/test/Data/fieldmetadata . 
# Offline system:
#ln -s /scratch2/BMC/gsienkf/Clara.Draper/data_RnR/orog_files_Mike ./fix
# Coupled: 

