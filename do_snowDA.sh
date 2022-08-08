#!/bin/bash 

# 1. staging and preparation of obs. 
#    note: IMS obs prep currently requires model background, then conversion to IODA format
# 2. creation of pseudo ensemble 
# 3. run LETKF to generate increment file 
# 4. add increment file to restarts (=disaggregation of bulk snow depth update into updates 
#    to SWE snd SD in each snow layer).

# Clara Draper, Oct 2021.

# to-do: 
# check that slmsk is always taken from the forecast file (oro files has a different definition)
# make sure documentation is updated.

# user directories

WORKDIR=${WORKDIR:-"/scratch2/BMC/gsienkf/Clara.Draper/workdir/"}
SCRIPTDIR=${DADIR:-"/scratch2/BMC/gsienkf/Clara.Draper/gerrit-hera/AZworkflow/DA_update/"}
OBSDIR=${OBSDIR:-"/scratch2/NCEPDEV/land/data/DA/"}
OUTDIR=${OUTDIR:-${SCRIPTDIR}/../output/} 
LOGDIR=${OUTDIR}/DA/logs/
#RSTRDIR=/scratch2/BMC/gsienkf/Clara.Draper/DA_test_cases/20191215_C48/ #C48
#RSTRDIR=/scratch2/BMC/gsienkf/Clara.Draper/jedi/create_ens/mem_base/  #C768 
#RSTRDIR=/scratch2/BMC/gsienkf/Clara.Draper/data_RnR/example_restarts/ # C96 Noah-MP
RSTRDIR=${RSTRDIR:-$WORKDIR/restarts/tile/} # if running offline cycling will be here

# DA options (select "YES" to assimilate)
DA_IMS=${DA_IMS:-"YES"}
DA_GHCN=${DA_GHCN:-"YES"} 
DA_GTS=${DA_GTS:-"NO"}
DA_SYNTH=${DA_SYNTH:-"NO"}
HOFX_IMS=${HOFX_IMS:-"YES"}
HOFX_GHCN=${HOFX_GHCN:-"YES"} 
HOFX_GTS=${HOFX_GTS:-"NO"}
HOFX_SYNTH=${HOFX_SYNTH:-"NO"}

do_DA=${do_DA:-"YES"}
do_hofx=${do_hofx:-"YES"}
YAML_DA=${YAML_DA:-"letkf_snow_offline_IMS_GHCN_C96.yaml"} # IMS and GHCN
YAML_HOFX=${YAML_HOFX:-"letkfoi_snow_offline_hofx_GHCN_C96.yaml"} 
echo "DA_update, YAML_DA is ${YAML_DA}"
echo "DA_update, YAML_HOFX is ${YAML_HOFX}"

# IMS data in file is from day before the file's time stamp 
IMStiming=OBSDATE # FILEDATE - use IMS data for file's time stamp =THISDATE (NRT option) 
                   # OBSDATE  - use IMS data for observation time stamp = THISDATE (hindcast option)

# executable directories

FIMS_EXECDIR=${SCRIPTDIR}/IMS_proc/exec/   
INCR_EXECDIR=${SCRIPTDIR}/add_jedi_incr/exec/   

# JEDI FV3 Bundle directories

JEDI_EXECDIR=${JEDI_EXECDIR:-"/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/bin/"}
JEDI_STATICDIR=${SCRIPTDIR}/jedi/fv3-jedi/Data/

# JEDI IODA-converter bundle directories

IODA_BUILD_DIR=${IODA_BUILD_DIR:-"/scratch2/BMC/gsienkf/UFS-RNR/UFS-RNR-stack/external/ioda-bundle/build/"}

# EXPERIMENT SETTINGS

RES=${RES:-96}
NPROC_DA=${NPROC_DA:-6} 
B=30  # back ground error std.

# STORAGE SETTINGS 

SAVE_IMS="YES" # "YES" to save processed IMS IODA file
SAVE_INCR="YES" # "YES" to save increment (add others?) JEDI output
SAVE_TILE="NO" # "YES" to save background in tile space
REDUCE_HOFX="YES" # "YES" to remove duplicate hofx files (one per processor)

THISDATE=${THISDATE:-"2015090118"}

echo 'THISDATE in land DA, '$THISDATE

############################################################################################
# SHOULD NOT HAVE TO CHANGE ANYTHING BELOW HERE

cd $WORKDIR 

source ${SCRIPTDIR}/land_mods_hera

################################################
# FORMAT DATE STRINGS
################################################

INCDATE=${SCRIPTDIR}/incdate.sh

# substringing to get yr, mon, day, hr info
export YYYY=`echo $THISDATE | cut -c1-4`
export MM=`echo $THISDATE | cut -c5-6`
export DD=`echo $THISDATE | cut -c7-8`
export HH=`echo $THISDATE | cut -c9-10`

PREVDATE=`${INCDATE} $THISDATE -6`

export YYYP=`echo $PREVDATE | cut -c1-4`
export MP=`echo $PREVDATE | cut -c5-6`
export DP=`echo $PREVDATE | cut -c7-8`
export HP=`echo $PREVDATE | cut -c9-10`

FILEDATE=${YYYY}${MM}${DD}.${HH}0000

if [[ $IMStiming == "FILEDATE" ]]; then 
        IMSDAY=${THISDATE} 
elif [[ $IMStiming == "OBSDATE" ]]; then
        IMSDAY=`${INCDATE} ${THISDATE} +24`
else
        echo 'UNKNOWN IMStiming selection, exiting' 
        exit 10 
fi

export YYYN=`echo $IMSDAY | cut -c1-4`
export MN=`echo $IMSDAY | cut -c5-6`
export DN=`echo $IMSDAY | cut -c7-8`

DOY=$(date -d "${YYYN}-${MN}-${DN}" +%j)
echo DOY is ${DOY}


if [[ ! -e ${WORKDIR}/output ]]; then
ln -s ${OUTDIR} ${WORKDIR}/output
fi 

if  [[ $SAVE_TILE == "YES" ]]; then
for tile in 1 2 3 4 5 6 
do
cp ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${OUTDIR}/restarts/${FILEDATE}.sfc_data_back.tile${tile}.nc
done
fi 

#stage restarts for applying JEDI update (files will get directly updated)
for tile in 1 2 3 4 5 6 
do
  ln -s ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc ${WORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc
done
ln -s ${RSTRDIR}/${FILEDATE}.coupler.res ${WORKDIR}/${FILEDATE}.coupler.res 


################################################
# PREPARE OBS FILES
################################################

# stage GTS
if [[ $DA_GTS == "YES" || $HOFX_GTS == "YES" ]]; then
  obsfile=$OBSDIR/snow_depth/GTS/data_proc/${YYYY}${MM}/adpsfc_snow_${YYYY}${MM}${DD}${HH}.nc4

  if [[ -e $obsfile ]]; then
    ln -s $obsfile  gts_${YYYY}${MM}${DD}${HH}.nc
    echo "GTS observations found: $obsfile"
  else
    echo "GTS observations not found: $obsfile"
    DA_GTS=NO
    HOFX_GTS=NO
  fi
fi 

# stage GHCN
if [[ $DA_GHCN == "YES" || $HOFX_GHCN == "YES" ]]; then
  obsfile=$OBSDIR/snow_depth/GHCN/data_proc/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc
  if [[ -e $obsfile ]]; then
    ln -s $obsfile  ghcn_${YYYY}${MM}${DD}.nc
    echo "GHCN observations found: $obsfile"
  else
    echo "GHCN observations not found: $obsfile"
    DA_GHCN=NO
    HOFX_GHCN=NO
  fi
fi 

# stage synthetic obs.
if [[ $DA_SYNTH == "YES" || $HOFX_SYNTH == "YES" ]]; then
  obsfile=$OBSDIR/synthetic_noahmp/IODA.synthetic_gswp_obs.${YYYY}${MM}${DD}18.nc
  if [[ -e $obsfile ]]; then
    ln -s $obsfile  synth_${YYYY}${MM}${DD}.nc
    echo "SYNTH observations found: $obsfile"
  else
    echo "SYNTH observations not found: $obsfile"
    DA_SYNTH=NO
    HOFX_SYNTH=NO
  fi
fi 

# prepare IMS
if [[ $DA_IMS == "YES" || $HOFX_IMS == "YES" ]]; then

  if [[ $IMSDAY -gt 2014120200 ]]; then
        ims_vsn=1.3 
  else
        ims_vsn=1.2 
  fi

  obsfile=${OBSDIR}/snow_ice_cover/IMS/${YYYY}/ims${YYYY}${DOY}_4km_v${ims_vsn}.nc
  if [[ -e $obsfile && $HH == "18" ]]; then
    echo "IMS observations found: $obsfile"
  else
    echo "IMS observations not found: $obsfile"
    DA_IMS=NO
    HOFX_IMS=NO
  fi
 
# pre-process and call IODA converter for IMS obs.

cat >> fims.nml << EOF
 &fIMS_nml
  idim=$RES, jdim=$RES,
  jdate=${YYYY}${DOY},
  yyyymmdd=${YYYY}${MM}${DD},
  imsformat=2,
  imsversion=${ims_vsn},
  IMS_OBS_PATH="${OBSDIR}/snow_ice_cover/IMS/${YYYY}/",
  IMS_IND_PATH="${OBSDIR}/snow_ice_cover/IMS/index_files/"
  /
EOF

    echo 'snowDA: calling fIMS'

    ${FIMS_EXECDIR}/calcfIMS
    if [[ $? != 0 ]]; then
        echo "fIMS failed"
        exit 10
    fi

    source ${SCRIPTDIR}/ioda_mods_hera
 
    IMS_IODA=imsfv3_scf2ioda_obs40.py
    cp ${SCRIPTDIR}/jedi/ioda/${IMS_IODA} $WORKDIR

    echo 'snowDA: calling ioda converter' 

    python ${IMS_IODA} -i IMSscf.${YYYY}${MM}${DD}.C${RES}.nc -o ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc 
    if [[ $? != 0 ]]; then
        echo "IMS IODA converter failed"
        exit 10
    fi

fi

############################
# Check the observation availability
if [ $DA_IMS == "NO" ] && [ $DA_GHCN == "NO" ] && [ $DA_SYNTH == "NO" ] && [ $DA_GTS == "NO" ] ; then
    echo "No observation is found: not calling JEDI for hofx or DA"
    exit 0
fi

############################
# create the jedi yaml name

# construct yaml name
if [ $do_DA == "YES" ]; then
     YAML_DA=${DAtype}"_offline_DA"
     if [ $DA_IMS == "YES" ]; then YAML_DA=${YAML_DA}"_IMS" ; fi
     if [ $DA_GHCN == "YES" ]; then YAML_DA=${YAML_DA}"_GHCN" ; fi
     if [ $DA_SYNTH == "YES" ]; then YAML_DA=${YAML_DA}"_SYNTH"; fi
     if [ $DA_GTS == "YES" ]; then YAML_DA=${YAML_DA}"_GTS" ; fi
fi

if [ $do_hofx == "YES" ]; then
     YAML_HOFX=${DAtype}"_offline_hofx"
     if [ $HOFX_IMS == "YES" ]; then YAML_HOFX=${YAML_HOFX}"_IMS" ; fi
     if [ $HOFX_GHCN == "YES" ]; then YAML_HOFX=${YAML_HOFX}"_GHCN" ; fi
     if [ $HOFX_SYNTH == "YES" ]; then YAML_HOFX=${YAML_HOFX}"_SYNTH"; fi
     if [ $HOFX_GTS == "YES" ]; then YAML_HOFX=${YAML_HOFX}"_GTS" ; fi
fi

YAML_DA=${YAML_DA}"_C${RES}.yaml"
YAML_HOFX=${YAML_HOFX}"_C96.yaml"

# if yamls specified in namelist, use those
YAML_DA=${YAML_DA_SPEC:-$YAML_DA}
YAML_HOFX=${YAML_HOFX_SPEC:-$YAML_HOFX}
if [[ $do_DA == "YES" ]]; then
     echo "JEDI_YAML for DA "$YAML_DA
     if [[ ! -e ${DADIR}/jedi/fv3-jedi/yaml_files/$YAML_DA ]]; then
         echo "DA YAML does not exist, exiting"
         exit 10
     fi
     export YAML_DA
fi
if [[ $do_hofx == "YES" ]]; then
     echo "JEDI_YAML for hofx "$YAML_HOFX
     if [[ ! -e ${DADIR}/jedi/fv3-jedi/yaml_files/$YAML_HOFX ]]; then
         echo "HOFX YAML does not exist, exiting"
         exit 10
     fi
     export YAML_HOFX
fi

################################################
# CREATE PSEUDO-ENSEMBLE
################################################

if [[ $do_DA == "YES" ]]; then 

    cp -r ${RSTRDIR} $WORKDIR/mem_pos
    cp -r ${RSTRDIR} $WORKDIR/mem_neg

    echo 'snowDA: calling create ensemble' 

    python ${SCRIPTDIR}/letkf_create_ens.py $FILEDATE $B
    if [[ $? != 0 ]]; then
        echo "letkf create failed"
        exit 10
    fi

fi 

################################################
# RUN LETKF
################################################

# prepare namelist for DA 
if [ $do_DA == "YES" ]; then

    cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/$YAML_DA ${WORKDIR}/letkf_snow.yaml

    sed -i -e "s/XXYYYY/${YYYY}/g" letkf_snow.yaml
    sed -i -e "s/XXMM/${MM}/g" letkf_snow.yaml
    sed -i -e "s/XXDD/${DD}/g" letkf_snow.yaml
    sed -i -e "s/XXHH/${HH}/g" letkf_snow.yaml

    sed -i -e "s/XXYYYP/${YYYP}/g" letkf_snow.yaml
    sed -i -e "s/XXMP/${MP}/g" letkf_snow.yaml
    sed -i -e "s/XXDP/${DP}/g" letkf_snow.yaml
    sed -i -e "s/XXHP/${HP}/g" letkf_snow.yaml

fi 

if [ $do_hofx == "YES" ]; then 

    cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/$YAML_HOFX ${WORKDIR}/hofx_snow.yaml

    sed -i -e "s/XXYYYY/${YYYY}/g" hofx_snow.yaml
    sed -i -e "s/XXMM/${MM}/g" hofx_snow.yaml
    sed -i -e "s/XXDD/${DD}/g" hofx_snow.yaml
    sed -i -e "s/XXHH/${HH}/g" hofx_snow.yaml

    sed -i -e "s/XXYYYP/${YYYP}/g" hofx_snow.yaml
    sed -i -e "s/XXMP/${MP}/g" hofx_snow.yaml
    sed -i -e "s/XXDP/${DP}/g" hofx_snow.yaml
    sed -i -e "s/XXHP/${HP}/g" hofx_snow.yaml

fi

if [[ ! -e Data ]]; then
    ln -s $JEDI_STATICDIR Data 
fi

echo 'snowDA: calling fv3-jedi' 
source ${JEDI_EXECDIR}/../../../fv3_mods_hera

if [[ $do_DA == "YES" ]]; then
srun -n $NPROC_DA ${JEDI_EXECDIR}/fv3jedi_letkf.x letkf_snow.yaml ${LOGDIR}/jedi_letkf.log
if [[ $? != 0 ]]; then
    echo "JEDI DA failed"
    exit 10
fi
fi 
if [[ $do_hofx == "YES" ]]; then  
srun -n $NPROC_DA ${JEDI_EXECDIR}/fv3jedi_hofx_nomodel.x hofx_snow.yaml ${LOGDIR}/jedi_hofx.log
if [[ $? != 0 ]]; then
    echo "JEDI hofx failed"
    exit 10
fi
fi 

################################################
# APPLY INCREMENT TO UFS RESTARTS 
################################################

if [[ $do_DA == "YES" ]]; then 

cat << EOF > apply_incr_nml
&noahmp_snow
 date_str=${YYYY}${MM}${DD}
 hour_str=$HH
 res=$RES
/
EOF

echo 'snowDA: calling apply increment'
source ${SCRIPTDIR}/land_mods_hera

# (n=6) -> this is fixed, at one task per tile (with minor code change, could run on a single proc). 
srun '--export=ALL' -n 6 ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
if [[ $? != 0 ]]; then
    echo "apply increment failed"
    exit 10
fi

fi 

################################################
# CLEAN UP
################################################

if  [[ $SAVE_TILE == "YES" ]]; then
for tile in 1 2 3 4 5 6 
do
cp ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${OUTDIR}/restarts/${FILEDATE}.sfc_data_anal.tile${tile}.nc
done
fi 

# keep IMS IODA file
if [ $SAVE_IMS == "YES"  ] && [[ $DA_IMS == "YES" || $HOFX_IMS == "YES" ]]; then
        cp ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ${OUTDIR}/DA/IMSproc/
fi 

# keep increments
if [ $SAVE_INCR == "YES" ] && [ $do_DA == "YES" ]; then
        cp ${WORKDIR}/${FILEDATE}.xainc.sfc_data.tile*.nc  ${OUTDIR}/DA/jedi_incr/
fi 

# keep only one copy of each hofx files
if [ $REDUCE_HOFX == "YES" ]; then 
   if [ $do_hofx == "YES" ] || [ $do_DA == "YES" ] ; then
       for file in $(ls ${OUTDIR}/DA/hofx/*${YYYY}${MM}${DD}*00[123456789].nc) 
        do 
        rm $file 
        done
   fi
fi 
