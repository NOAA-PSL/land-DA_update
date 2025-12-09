#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 
       	#GDASApp_path="/scratch3/NCEPDEV/da/Tseganeh.Gichamo/global-workflow/sorc/gdas.cd/" 
        GDASApp_path="/scratch4/BMC/gsienkf/Clara.Draper/gerrit-hera/global-workflow/sorc/gdas.cd/"
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
#ln -fs ${GDASApp_path}/build/fv3-jedi/test/Data/fv3files $fv3files
ln -fs /scratch4/BMC/gsienkf/Clara.Draper/gerrit-hera/global-workflow/fix/gdas/fv3jedi/fv3files $fv3files

# link ioda converters
# ghcn - temporary until IODA converter PR merged. July 30, 2025.
ln -fs ${GDASApp_path}/sorc/iodaconv/src/land/ghcn_snod2ioda.py jedi/ioda/ghcn_snod2ioda.py
