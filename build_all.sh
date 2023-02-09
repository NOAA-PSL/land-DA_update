#!/bin/bash 

source ./land_mods_aws
jedi_path=/contrib/role.ca-ufs-rnr/fv3-bundle
ioda_converters_path=/contrib/role.ca-ufs-rnr/soca-science/build/bin

for source in add_jedi_incr IMS_proc 
do 
cd $source 
echo 'compiling '$source
./build.sh 
cd .. 
done

# create links 
echo 'creating jedi links'
cd jedi/fv3-jedi/Data/
./make_links.sh $jedi_path
cd ../../../
cd jedi/ioda/
./make_links.sh $ioda_converters_path
