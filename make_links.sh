#!/bin/bash

source detect_machine.sh

if [[ ${MACHINE_ID} == 'ursa' ]]; then
    echo "linking GDASApp lib paths on URSA"
    GDASApp_path=/scratch4/NCEPDEV/land/APPS/GDASApp/20260316
    fixorog=/scratch3/NCEPDEV/global/role.glopara/fix/orog/20240917
    obs=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/obs/20240213
    snow=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/snow/20241210
    fv3jedi=/scratch3/NCEPDEV/global/role.glopara/fix/gdas/fv3jedi/20241115
elif [[ ${MACHINE_ID} == 'gaeac6' ]]; then
    echo "linking GDASApp lib paths on GAEA C6"
    GDASApp_path=/gpfs/f6/land-cpu/scratch/Tseganeh.Gichamo/Land_GDASApp   #/gpfs/f6/land-cpu/proj-shared/APPS/Land_GDASApp
    fixorog=/gpfs/f6/drsa-precip3/world-shared/role.glopara/fix/orog/20240917
    obs=/gpfs/f6/drsa-precip3/world-shared/role.glopara/fix/gdas/obs/20240213
    snow=/gpfs/f6/drsa-precip3/world-shared/role.glopara/fix/gdas/snow/20241210
    fv3jedi=/gpfs/f6/drsa-precip3/world-shared/role.glopara/fix/gdas/fv3jedi/20241115
else
    echo "Land offline workflow currently supported only on URSA and GAEA C6"
    exit 1
fi

# create link to GDASApp with executables:
gdasdir="./GDASApp"
if [[ -e $gdasdir ]]; then
  rm $gdasdir
fi
ln -fs $GDASApp_path $gdasdir

#link GDASApp/parm
HOMEgfs="$(dirname "$(pwd)")/HOMEgfs"
echo "homegfs: $HOMEgfs"
if [[ -e  "${HOMEgfs}/parm/gdas" ]]; then
  echo "removing homegfs/parm/gdas"
  rm "${HOMEgfs}/parm/gdas"
fi
ln -fs ${GDASApp_path}/parm ${HOMEgfs}/parm/gdas

# link fix and fv3files

fv3files="jedi/fv3-jedi/Data/fv3files"
if [[ -e $fv3files ]]; then
  rm $fv3files
fi
ln -fs $fv3jedi/fv3files  $fv3files

if [[ -e  "${HOMEgfs}/fix/orog" ]]; then
  echo "removing homegfs/fix/orog"
  rm "${HOMEgfs}/fix/orog"
fi
ln -fs ${fixorog} ${HOMEgfs}/fix/orog

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

# if using default fv3jedi
if [[ -e  "${HOMEgfs}/fix/gdas/fv3jedi" ]]; then
  echo "removing homegfs/fix/gdas/fv3jedi"
  rm "${HOMEgfs}/fix/gdas/fv3jedi"
fi
ln -fs ${fv3jedi} ${HOMEgfs}/fix/gdas/fv3jedi
#ln -fs $fv3jedi/fv3files  jedi/fv3-jedi/Data/fv3files
#ln -fs $fv3jedi/fieldmetadata jedi/fv3-jedi/Data/fieldmetadata
#ln -fs $fv3jedi/fieldsets jedi/fv3-jedi/Data/fieldsets
