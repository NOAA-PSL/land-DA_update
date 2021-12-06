#!/bin/ksh 

if [ $# != 1 ]; then 
        echo 'ERROR: usage make_links.sh path-to-JEDI-fv3-bundle-build' 
        exit 
fi 

jedi_path=$1

ln -s ${jedi_path}/fv3-jedi/test/Data/fieldsets . 
ln -s ${jedi_path}/fv3-jedi/test/Data/fv3files . 
# standard:
ln -s /scratch1/NCEPDEV/global/glopara/fix/fix_fv3_gmted2010 ./glopara_fix
# Mike's files, used offline
ln -s /scratch2/BMC/gsienkf/Clara.Draper/data_RnR/orog_files_Mike ./offline_fix

