#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 
        GDASApp_path="/scratch2/NCEPDEV/land/data/DA/GDASApp/build/"
fi 

# create link to GDASApp with executables:
ln -s $GDASApp_path ./GDASApp


# link converter (todo: remove this, link directly?)
# uncomment until converter is updated in JEDI repo
#ln -s ${GDASApp_path}/sorc/iodaconv/src/land/imsfv3_scf2ioda.py jedi/ioda/imsfv3_scf2ioda.py

# link fv3files (todo: remove this, and change directory in the yamls?)
ln -s ${GDASApp_path}/build/fv3-jedi/test/Data/fv3files jedi/fv3-jedi/Data/fv3files
/scratch2/NCEPDEV/land/data/DA/GDASApp/


