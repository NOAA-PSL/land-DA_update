#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 
        GDASApp_path="/scratch2/NCEPDEV/land/data/DA/GDASApp_20250207/"
fi 

# create link to GDASApp with executables:
gdasdir="./GDASApp"
if [[ -e $gdasdir ]]; then
  rm $gdasdir
fi
ln -fs $GDASApp_path $gdasdir

# link fv3files
fv3files="jedi/fv3-jedi/Data/fv3files"
if [[ -e $fv3files ]]; then
  rm $fv3files
fi
ln -fs ${GDASApp_path}/build/fv3-jedi/test/Data/fv3files $fv3files


