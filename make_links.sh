#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 
        GDASApp_path="/scratch2/NCEPDEV/land/data/DA/GDASApp/"
fi 

# create link to GDASApp with executables:
ln -s $GDASApp_path ./GDASApp

# link fv3files 
ln -s ${GDASApp_path}/build/fv3-jedi/test/Data/fv3files jedi/fv3-jedi/Data/fv3files


