#!/bin/bash

if [ $# == 1 ]; then 
        echo "setting jedi path to input $1"
        GDASApp_path=$1
else 	
        GDASApp_path="/scratch3/NCEPDEV/da/Tseganeh.Gichamo/global-workflow/sorc/gdas.cd/"
	#/scratch4/NCEPDEV/land/APPS/GDASApp/20260123/" 
fi 

# create link to GDASApp with executables:
gdasdir="./GDASApp"
if [[ -e $gdasdir ]]; then
  rm $gdasdir
fi
ln -fs $GDASApp_path $gdasdir

# link fix and fv3files

fv3files="jedi/fv3-jedi/Data/fv3files"
if [[ -e $fv3files ]]; then
  rm $fv3files
fi

fv3jedi=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/fv3jedi/20241115
ln -fs $fv3jedi/fv3files  $fv3files
#ln -fs $fv3jedi/fieldmetadata jedi/fv3-jedi/Data/fieldmetadata
#ln -fs $fv3jedi/fieldsets jedi/fv3-jedi/Data/fieldsets

# link ioda converters for ghcn
if [[ -e jedi/ioda/ghcn_snod2ioda.py ]]; then 
  rm jedi/ioda/ghcn_snod2ioda.py
fi
ln -fs ${GDASApp_path}/ush/snow/ghcn_snod2ioda.py jedi/ioda/ghcn_snod2ioda.py

# Add "HOMEgfs" components needed for snow
HOMEgfs="$(dirname "$(pwd)")/HOMEgfs" 
echo "homegfs: $HOMEgfs"  
if [[ -e  "${HOMEgfs}/parm/gdas" ]]; then
  echo "removing homegfs/parm/gdas"
  rm "${HOMEgfs}/parm/gdas"
fi
ln -fs ${GDASApp_path}/parm ${HOMEgfs}/parm/gdas

FIXorog=/scratch3/NCEPDEV/global/role.glopara/fix/orog/20240917/
if [[ -e  "${HOMEgfs}/fix/orog" ]]; then
  echo "removing homegfs/fix/orog"
  rm "${HOMEgfs}/fix/orog"
fi
ln -fs ${FIXorog} ${HOMEgfs}/fix/orog

obs=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/obs/20240213
snow=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/snow/20241210
if [[ ! -d  "${HOMEgfs}/fix/gdas" ]]; then
  echo "creating homegfs/fix/gdas"
  mkdir "${HOMEgfs}/fix/gdas"
fi

if [[ -e  "${HOMEgfs}/fix/gdas/obs" ]]; then
  echo "removing homegfs/fix/gdas/obs"
  rm "${HOMEgfs}/fix/gdas/obs"
fi
ln -fs ${obs} ${HOMEgfs}/fix/gdas/obs

if [[ -e  "${HOMEgfs}/fix/gdas/snow" ]]; then
  echo "removing homegfs/fix/gdas/snow"
  rm "${HOMEgfs}/fix/gdas/snow"
fi
ln -fs ${snow} ${HOMEgfs}/fix/gdas/snow

if [[ -e  "${HOMEgfs}/fix/gdas/fv3jedi" ]]; then
  echo "removing homegfs/fix/gdas/fv3jedi"
  rm "${HOMEgfs}/fix/gdas/fv3jedi"
fi
ln -fs ${fv3jedi} ${HOMEgfs}/fix/gdas/fv3jedi
