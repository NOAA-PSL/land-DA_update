#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 
       	#GDASApp_path="/scratch3/NCEPDEV/da/Tseganeh.Gichamo/global-workflow/sorc/gdas.cd/" 
        GDASApp_path="/scratch4/NCEPDEV/land/APPS/GDASApp/"
fi 

# create link to GDASApp with executables:
gdasdir="./GDASApp"
if [[ -e $gdasdir ]]; then
  rm $gdasdir
fi
ln -fs $GDASApp_path $gdasdir

# link fix files


# link fv3files

fv3files="jedi/fv3-jedi/Data/fv3files"
if [[ -e $fv3files ]]; then
  rm $fv3files
fi

fv3jedi=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/fv3jedi/20241115
ln -fs $fv3jedi/fv3files  $fv3files
#ln -fs $fv3jedi/fieldmetadata jedi/fv3-jedi/Data/fieldmetadata
#ln -fs $fv3jedi/fieldsets jedi/fv3-jedi/Data/fieldsets

# link ioda converters
# ghcn - temporary until IODA converter PR merged. July 30, 2025.
ln -fs ${GDASApp_path}/sorc/iodaconv/src/land/ghcn_snod2ioda.py jedi/ioda/ghcn_snod2ioda.py
