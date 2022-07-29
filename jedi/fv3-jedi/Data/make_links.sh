#!/bin/ksh 

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        jedi_path=$1
else 
        jedi_path="/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/"
fi 

ln -s ${jedi_path}/fv3-jedi/test/Data/fv3files . 
ln -s ${jedi_path}/fv3-jedi/test/Data/fieldmetadata . 
# standard:
ln -s /scratch1/NCEPDEV/global/glopara/fix/fix_fv3_gmted2010 ./glopara_fix
# Mike's files, used offline
ln -s /scratch2/BMC/gsienkf/Clara.Draper/data_RnR/orog_files_Mike ./offline_fix

