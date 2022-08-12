#!/bin/bash 

source land_mods_hera

for source in add_jedi_incr IMS_proc 
do 
cd $source 
./build.sh 
cd .. 
done
