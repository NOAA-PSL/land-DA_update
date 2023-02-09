#!/bin/bash 

source land_mods_hera

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
make_links.sh
