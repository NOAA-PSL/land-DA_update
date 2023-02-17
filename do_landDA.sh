#!/bin/bash 
# script to run the land DA. Currently only option is the snow LETKFOI.
#
# 1. stage the restarts. 
# 2. stage and process obs. 
# 3. create the JEDI yamls.
# 4. create pseudo ensemble (LETKF-OI).
# 5. run JEDI.
# 6. add increment file to restarts (and adjust any necessary dependent variables).
# 7. clean up.

# Clara Draper, Oct 2021.
# Aug 2020, generalized for all DA types.

#########################################
# source namelist and setup directories
#########################################

set -x
if [[ $# -gt 0 ]]; then 
    config_file=$1
else
    echo "do_landDA.sh: no config file specified, exting" 
    exit 1
fi

echo "reading DA settings from $config_file"

GFSv17=${GFSv17:-"NO"}

fv3bundle_vn=${fv3bundle_vn:-"release-v1.0"}

source $config_file

LOGDIR=${OUTDIR}/DA/logs/
OBSDIR=${OBSDIR:-"/scratch2/NCEPDEV/land/data/DA/"}

# executables
if [[ -e ${BUILDDIR}/bin/apply_incr.exe ]]; then #prefer cmake-built executables
  apply_incr_EXEC=${BUILDDIR}/bin/apply_incr.exe
else
  apply_incr_EXEC=${CYCLEDIR}/DA_update/add_jedi_incr/exec/apply_incr
fi

# storage settings 
SAVE_INCR="YES" # "YES" to save increment (add others?) JEDI output
SAVE_TILE=${SAVE_TILE:-"NO"} # "YES" to save background in tile space
KEEPJEDIDIR=${KEEPJEDIDIR:-"YES"} # delete DA workdir 

echo 'THISDATE in land DA, '$THISDATE

############################################################################################

# create output directories.
if [[ ! -e ${OUTDIR}/DA ]]; then
    mkdir -p ${OUTDIR}/DA
    mkdir ${OUTDIR}/DA/jedi_incr
    mkdir ${OUTDIR}/DA/logs
    mkdir ${OUTDIR}/DA/hofx
fi 
export JEDIWORKDIR=${WORKDIR}/mem000/jedi
OROG_PATH=${LANDDA_INPUTS}/forcing/${atmos_forc}/orog_files

if [[ ! -e $JEDIWORKDIR ]]; then 
    mkdir -p $JEDIWORKDIR
fi


cd $JEDIWORKDIR 

################################################
# 1. FORMAT DATE STRINGS AND STAGE RESTARTS
################################################

INCDATE=${LANDDADIR}/incdate.sh

YYYY=`echo $THISDATE | cut -c1-4`
MM=`echo $THISDATE | cut -c5-6`
DD=`echo $THISDATE | cut -c7-8`
HH=`echo $THISDATE | cut -c9-10`

PREVDATE=`${INCDATE} $THISDATE -$WINLEN`

YYYP=`echo $PREVDATE | cut -c1-4`
MP=`echo $PREVDATE | cut -c5-6`
DP=`echo $PREVDATE | cut -c7-8`
HP=`echo $PREVDATE | cut -c9-10`

FILEDATE=${YYYY}${MM}${DD}.${HH}0000

if [[ ! -e ${JEDIWORKDIR}/output ]]; then
ln -s ${OUTDIR} ${JEDIWORKDIR}/output
fi 

if  [[ $SAVE_TILE == "YES" ]]; then
for tile in 1 2 3 4 5 6 
do
cp ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${RSTRDIR}/${FILEDATE}.sfc_data_back.tile${tile}.nc
done
fi 
#stage restarts for applying JEDI update (files will get directly updated)
for tile in 1 2 3 4 5 6 
do
  ln -fs ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc ${JEDIWORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc
done
cres_file=${JEDIWORKDIR}/${FILEDATE}.coupler.res
if [[ -e  ${RSTRDIR}/${FILEDATE}.coupler.res ]]; then 
    ln -sf ${RSTRDIR}/${FILEDATE}.coupler.res $cres_file
else #  if not present, need to create coupler.res for JEDI 
    cp ${LANDDADIR}/template.coupler.res $cres_file

    sed -i -e "s/XXYYYY/${YYYY}/g" $cres_file
    sed -i -e "s/XXMM/${MM}/g" $cres_file
    sed -i -e "s/XXDD/${DD}/g" $cres_file
    sed -i -e "s/XXHH/${HH}/g" $cres_file

    sed -i -e "s/XXYYYP/${YYYP}/g" $cres_file
    sed -i -e "s/XXMP/${MP}/g" $cres_file
    sed -i -e "s/XXDP/${DP}/g" $cres_file
    sed -i -e "s/XXHP/${HP}/g" $cres_file

fi 


################################################
# 2. PREPARE OBS FILES
################################################

for ii in "${!OBS_TYPES[@]}"; # loop through requested obs
do 

  # get the obs file name 
  if [ ${OBS_TYPES[$ii]} == "GTS" ]; then
     obsfile=$OBSDIR/snow_depth/GTS/data_proc/${YYYY}${MM}/adpsfc_snow_${YYYY}${MM}${DD}${HH}.nc4
  elif [ ${OBS_TYPES[$ii]} == "GHCN" ]; then 
     obsfile=$OBSDIR/snow_depth/GHCN/data_proc/${YYYY}/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc
  elif [ ${OBS_TYPES[$ii]} == "SYNTH" ]; then 
     obsfile=$OBSDIR/synthetic_noahmp/IODA.synthetic_gswp_obs.${YYYY}${MM}${DD}${HH}.nc
  else
     echo "do_landDA: Unknown obs type requested ${OBS_TYPES[$ii]}, exiting" 
     exit 1 
  fi

  # check obs are available
  if [[ -e $obsfile ]]; then
    echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile"
    ln -fs $obsfile  ${OBS_TYPES[$ii]}_${YYYY}${MM}${DD}${HH}.nc
  else
    echo "${OBS_TYPES[$ii]} observations not found: $obsfile"
    JEDI_TYPES[$ii]="SKIP"
  fi

done # OBS_TYPES

################################################
# 3. DETERMINE REQUESTED JEDI TYPE, CONSTRUCT YAMLS
################################################

do_DA="NO"
do_HOFX="NO"

for ii in "${!OBS_TYPES[@]}"; # loop through requested obs
do
   if [ ${JEDI_TYPES[$ii]} == "DA" ]; then 
         do_DA="YES" 
   elif [ ${JEDI_TYPES[$ii]} == "HOFX" ]; then
         do_HOFX="YES" 
   elif [ ${JEDI_TYPES[$ii]} != "SKIP" ]; then
         echo "do_landDA:Unknown obs action ${JEDI_TYPES[$ii]}, exiting" 
         exit 1
   fi
done

if [[ $do_DA == "NO" && $do_HOFX == "NO" ]]; then 
        echo "do_landDA:No obs found, not calling JEDI" 
        exit 0 
fi

# if yaml is specified by user, use that. Otherwise, build the yaml
if [[ $do_DA == "YES" ]]; then 

   if [[ $YAML_DA == "construct" ]];then  # construct the yaml

      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${DAtype}.yaml ${JEDIWORKDIR}/letkf_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "DA" ]; then
        cat ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${OBS_TYPES[$ii]}.yaml >> letkf_land.yaml
        fi 
      done

   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_DA}"
      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${YAML_DA} ${JEDIWORKDIR}/letkf_land.yaml
   fi

   sed -i -e "s/XXYYYY/${YYYY}/g" letkf_land.yaml
   sed -i -e "s/XXMM/${MM}/g" letkf_land.yaml
   sed -i -e "s/XXDD/${DD}/g" letkf_land.yaml
   sed -i -e "s/XXHH/${HH}/g" letkf_land.yaml

   sed -i -e "s/XXYYYP/${YYYP}/g" letkf_land.yaml
   sed -i -e "s/XXMP/${MP}/g" letkf_land.yaml
   sed -i -e "s/XXDP/${DP}/g" letkf_land.yaml
   sed -i -e "s/XXHP/${HP}/g" letkf_land.yaml
   sed -i -e "s#DATAPATH#${OROG_PATH}#g" letkf_land.yaml

   sed -i -e "s/XXTSTUB/${TSTUB}/g" letkf_land.yaml
   sed -i -e "s#XXTPATH#${TPATH}#g" letkf_land.yaml
   sed -i -e "s/XXRES/${RES}/g" letkf_land.yaml
   RESP1=$((RES+1))
   sed -i -e "s/XXREP/${RESP1}/g" letkf_land.yaml

   sed -i -e "s/XXHOFX/false/g" letkf_land.yaml  # do DA
fi

if [[ $do_HOFX == "YES" ]]; then 

   if [[ $YAML_HOFX == "construct" ]];then  # construct the yaml

      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${DAtype}.yaml ${JEDIWORKDIR}/hofx_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "HOFX" ]; then
        cat ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${OBS_TYPES[$ii]}.yaml >> hofx_land.yaml
        fi 
      done
   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_HOFX}"
      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/${YAML_HOFX} ${JEDIWORKDIR}/hofx_land.yaml
   fi

   sed -i -e "s/XXYYYY/${YYYY}/g" hofx_land.yaml
   sed -i -e "s/XXMM/${MM}/g" hofx_land.yaml
   sed -i -e "s/XXDD/${DD}/g" hofx_land.yaml
   sed -i -e "s/XXHH/${HH}/g" hofx_land.yaml

   sed -i -e "s/XXYYYP/${YYYP}/g" hofx_land.yaml
   sed -i -e "s/XXMP/${MP}/g" hofx_land.yaml
   sed -i -e "s/XXDP/${DP}/g" hofx_land.yaml
   sed -i -e "s/XXHP/${HP}/g" hofx_land.yaml
   sed -i -e "s#DATAPATH#${OROG_PATH}#g" hofx_land.yaml

   sed -i -e "s#XXTPATH#${TPATH}#g" hofx_land.yaml
   sed -i -e "s/XXTSTUB/${TSTUB}/g" hofx_land.yaml
   sed -i -e "s/XXRES/${RES}/g" hofx_land.yaml
   RESP1=$((RES+1))
   sed -i -e "s/XXREP/${RESP1}/g" hofx_land.yaml

   sed -i -e "s/XXHOFX/true/g" hofx_land.yaml  # do HOFX

fi

################################################
# 4. CREATE BACKGROUND ENSEMBLE (LETKFOI)
################################################

if [[ ${DAtype} == 'letkfoi_snow' ]]; then 

    JEDI_EXEC="fv3jedi_letkf.x"

    if [ $GFSv17 == "YES" ]; then
        SNOWDEPTHVAR="snodl" 
        # field overwrite file with GFSv17 variables.
        cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${fv3bundle_vn}/gfs-land-v17.yaml ${JEDIWORKDIR}/gfs-land-v17.yaml
    else
        SNOWDEPTHVAR="snwdph"
    fi

    B=30  # back ground error std for LETKFOI

    # FOR LETKFOI, CREATE THE PSEUDO-ENSEMBLE
    for ens in pos neg 
    do
        if [ -e $JEDIWORKDIR/mem_${ens} ]; then 
                rm -r $JEDIWORKDIR/mem_${ens}
        fi
        mkdir -p $JEDIWORKDIR/mem_${ens} 
        for tile in 1 2 3 4 5 6
        do
        cp ${JEDIWORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${JEDIWORKDIR}/mem_${ens}/${FILEDATE}.sfc_data.tile${tile}.nc
        done
        cp ${JEDIWORKDIR}/${FILEDATE}.coupler.res ${JEDIWORKDIR}/mem_${ens}/${FILEDATE}.coupler.res
    done
       

    echo 'do_landDA: calling create ensemble' 

    # using ioda mods to get a python version with netCDF4

    ${PYTHON} ${LANDDADIR}/letkf_create_ens.py $FILEDATE $SNOWDEPTHVAR $B
    if [[ $? != 0 ]]; then
        echo "letkf create failed"
        exit 10
    fi

fi

################################################
# 5. RUN JEDI
################################################

NPROC_JEDI=6

if [[ ! -e Data ]]; then
    ln -s $JEDI_STATICDIR Data 
fi

echo 'do_landDA: calling fv3-jedi' 

if [[ $do_DA == "YES" ]]; then
    ${MPIEXEC} -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} letkf_land.yaml ${LOGDIR}/jedi_letkf.log
    if [[ $? != 0 ]]; then
        echo "JEDI DA failed"
        exit 10
    fi
fi 
if [[ $do_HOFX == "YES" ]]; then  
    ${MPIEXEC} -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} hofx_land.yaml ${LOGDIR}/jedi_hofx.log
    if [[ $? != 0 ]]; then
        echo "JEDI hofx failed"
        exit 10
    fi
fi 

################################################
# 6. APPLY INCREMENT TO UFS RESTARTS 
################################################

if [[ $do_DA == "YES" ]]; then 

  if [[ $DAtype == "letkfoi_snow" ]]; then 

cat << EOF > apply_incr_nml
&noahmp_snow
 date_str=${YYYY}${MM}${DD}
 hour_str=$HH
 res=$RES
 frac_grid=$GFSv17
 orog_path="$TPATH"
 otype="$TSTUB"
/
EOF

    echo 'do_landDA: calling apply snow increment'

    # (n=6) -> this is fixed, at one task per tile (with minor code change, could run on a single proc). 
    ${MPIEXEC} -n 6 ${apply_incr_EXEC} ${LOGDIR}/apply_incr.log
    if [[ $? != 0 ]]; then
        echo "apply snow increment failed"
        exit 10
    fi

  fi

fi 

################################################
# 7. CLEAN UP
################################################

# keep increments
if [ $SAVE_INCR == "YES" ] && [ $do_DA == "YES" ]; then
   cp ${JEDIWORKDIR}/${FILEDATE}.xainc.sfc_data.tile*.nc  ${OUTDIR}/DA/jedi_incr/
fi 

# clean up 
if [[ $KEEPJEDIDIR == "NO" ]]; then
   rm -rf ${JEDIWORKDIR} 
fi 
