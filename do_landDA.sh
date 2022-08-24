#!/bin/bash -le
# script to run the land DA. Currently only option is the snow LETKFOI.
#
# 1. stage the restarts. 
# 2. stage and process obs. 
#    note: IMS obs prep currently requires model background, then conversion to IODA format.
# 3. create the JEDI yamls.
# 4. create pseudo ensemble (LETKF-OI).
# 5. run JEDI.
# 6. add increment file to restarts (and adjust any necessary dependent variables).
# 7. clean up.

# Clara Draper, Oct 2021.
# Aug 2020, generalized for all DA types.

# to-do: 
# check that slmsk is always taken from the forecast file (oro files has a different definition)
# make sure documentation is updated.

#########################################
# source namelist and setup directories
#########################################

if [[ $# -gt 0 ]]; then 
    config_file=$1
else
    echo "do_landDA.sh: no config file specified, exting" 
    exit 1
fi

echo "reading DA settings from $config_file"

source $config_file

LOGDIR=${OUTDIR}/DA/logs/
RSTRDIR=${RSTRDIR:-$WORKDIR/restarts/tile/} # if running offline cycling will be here
OBSDIR=${OBSDIR:-"/scratch2/NCEPDEV/land/data/DA/"}

# executable directories
FIMS_EXECDIR=${SCRIPTDIR}/IMS_proc/exec/   
INCR_EXECDIR=${SCRIPTDIR}/add_jedi_incr/exec/   

# JEDI directories
JEDI_EXECDIR=${JEDI_EXECDIR:-"/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/bin/"}
IODA_BUILD_DIR=${IODA_BUILD_DIR:-"/scratch2/BMC/gsienkf/UFS-RNR/UFS-RNR-stack/external/ioda-bundle/build/"}
JEDI_STATICDIR=${SCRIPTDIR}/jedi/fv3-jedi/Data/

# storage settings 
SAVE_IMS="YES" # "YES" to save processed IMS IODA file
SAVE_INCR="YES" # "YES" to save increment (add others?) JEDI output
SAVE_TILE="NO" # "YES" to save background in tile space
REDUCE_HOFX="YES" # "YES" to remove duplicate hofx files (one per processor)

echo 'THISDATE in land DA, '$THISDATE

############################################################################################
# TEMPORARY, UNTIL WE SORT OUT THE LATENCY ON THE IMS OBS
# IMS data in file is from day before the file's time stamp 
IMStiming=OBSDATE # FILEDATE - use IMS data for file's time stamp =THISDATE (NRT option) 
                   # OBSDATE  - use IMS data for observation time stamp = THISDATE (hindcast option)

############################################################################################

# create output directories.
if [[ ! -e ${OUTDIR}/DA ]]; then
    mkdir -p ${OUTDIR}/DA
    mkdir ${OUTDIR}/DA/IMSproc
    mkdir ${OUTDIR}/DA/jedi_incr
    mkdir ${OUTDIR}/DA/logs
    mkdir ${OUTDIR}/DA/hofx
fi 

if [[ ! -e $WORKDIR ]]; then 
    mkdir $WORKDIR
fi


cd $WORKDIR 

################################################
# 1. FORMAT DATE STRINGS AND STAGE RESTARTS
################################################

INCDATE=${SCRIPTDIR}/incdate.sh

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
  elif [ ${OBS_TYPES[$ii]} == "IMS" ]; then 
     if [[ $IMStiming == "FILEDATE" ]]; then 
            IMSDAY=${THISDATE} 
     elif [[ $IMStiming == "OBSDATE" ]]; then
            IMSDAY=`${INCDATE} ${THISDATE} +24`
     else
            echo 'UNKNOWN IMStiming selection, exiting' 
            exit 10 
     fi
     YYYN=`echo $IMSDAY | cut -c1-4`
     MN=`echo $IMSDAY | cut -c5-6`
     DN=`echo $IMSDAY | cut -c7-8`
     DOY=$(date -d "${YYYN}-${MN}-${DN}" +%j)
     echo DOY is ${DOY}

     if [[ $IMSDAY -gt 2014120200 ]]; then  ims_vsn=1.3 ; else  ims_vsn=1.2 ; fi
     obsfile=${OBSDIR}/snow_ice_cover/IMS/${YYYY}/ims${YYYY}${DOY}_4km_v${ims_vsn}.nc

  else
     echo "do_landDA: Unknown obs type requested ${OBS_TYPES[$ii]}, exiting" 
     exit 1 
  fi

  # check obs are available
  if [[ -e $obsfile ]]; then
    echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile"
    if [ ${OBS_TYPES[$ii]} != "IMS" ]; then 
       ln -s $obsfile  ${OBS_TYPES[$ii]}_${YYYY}${MM}${DD}${HH}.nc
    fi 
  else
    echo "${OBS_TYPES[$ii]} observations not found: $obsfile"
    JEDI_TYPES[$ii]="SKIP"
  fi

  # pre-process and call IODA converter for IMS obs.
  if [[ ${OBS_TYPES[$ii]} == "IMS"  && ${JEDI_TYPES[$ii]} != "SKIP" ]]; then

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
    echo 'do_landDA: calling fIMS'
    source ${SCRIPTDIR}/land_mods_hera

    ${FIMS_EXECDIR}/calcfIMS
    if [[ $? != 0 ]]; then
        echo "fIMS failed"
        exit 10
    fi

    IMS_IODA=imsfv3_scf2ioda_obs40.py
    cp ${SCRIPTDIR}/jedi/ioda/${IMS_IODA} $WORKDIR

    echo 'do_landDA: calling ioda converter' 
    source ${SCRIPTDIR}/ioda_mods_hera

    python ${IMS_IODA} -i IMSscf.${YYYY}${MM}${DD}.C${RES}.nc -o ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc 
    if [[ $? != 0 ]]; then
        echo "IMS IODA converter failed"
        exit 10
    fi
  fi #IMS

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

      cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${DAtype}.yaml ${WORKDIR}/letkf_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "DA" ]; then
        cat ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${OBS_TYPES[$ii]}.yaml >> letkf_land.yaml
        fi 
      done

      sed -i -e "s/XXYYYY/${YYYY}/g" letkf_land.yaml
      sed -i -e "s/XXMM/${MM}/g" letkf_land.yaml
      sed -i -e "s/XXDD/${DD}/g" letkf_land.yaml
      sed -i -e "s/XXHH/${HH}/g" letkf_land.yaml

      sed -i -e "s/XXYYYP/${YYYP}/g" letkf_land.yaml
      sed -i -e "s/XXMP/${MP}/g" letkf_land.yaml
      sed -i -e "s/XXDP/${DP}/g" letkf_land.yaml
      sed -i -e "s/XXHP/${HP}/g" letkf_land.yaml

      sed -i -e "s/XXRES/${RES}/g" letkf_land.yaml
      RESP1=$((RES+1))
      sed -i -e "s/XXREP/${RESP1}/g" letkf_land.yaml

      sed -i -e "s/XXHOFX/false/g" letkf_land.yaml  # do DA

   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_DA}"
      cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${YAML_DA} ${WORKDIR}/letkf_land.yaml
   fi
fi

if [[ $do_HOFX == "YES" ]]; then 

   if [[ $YAML_HOFX == "construct" ]];then  # construct the yaml

      cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${DAtype}.yaml ${WORKDIR}/hofx_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "HOFX" ]; then
        cat ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${OBS_TYPES[$ii]}.yaml >> hofx_land.yaml
        fi 
      done

      sed -i -e "s/XXYYYY/${YYYY}/g" hofx_land.yaml
      sed -i -e "s/XXMM/${MM}/g" hofx_land.yaml
      sed -i -e "s/XXDD/${DD}/g" hofx_land.yaml
      sed -i -e "s/XXHH/${HH}/g" hofx_land.yaml

      sed -i -e "s/XXYYYP/${YYYP}/g" hofx_land.yaml
      sed -i -e "s/XXMP/${MP}/g" hofx_land.yaml
      sed -i -e "s/XXDP/${DP}/g" hofx_land.yaml
      sed -i -e "s/XXHP/${HP}/g" hofx_land.yaml

      sed -i -e "s/XXRES/${RES}/g" hofx_land.yaml
      RESP1=$((RES+1))
      sed -i -e "s/XXREP/${RESP1}/g" hofx_land.yaml

      sed -i -e "s/XXHOFX/true/g" hofx_land.yaml  # do HOFX

   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_HOFX}"
      cp ${SCRIPTDIR}/jedi/fv3-jedi/yaml_files/${YAML_HOFX} ${WORKDIR}/hofx_land.yaml
   fi
fi

################################################
# 4. CREATE BACKGROUND ENSEMBLE (LETKFOI)
################################################

if [[ ${DAtype} == 'letkfoi_snow' ]]; then 

    B=30  # back ground error std for LETKFOI

    JEDI_EXEC="fv3jedi_letkf.x"

    # FOR LETKFOI, CREATE THE PSEUDO-ENSEMBLE
    cp -r ${RSTRDIR} $WORKDIR/mem_pos
    cp -r ${RSTRDIR} $WORKDIR/mem_neg

    echo 'do_landDA: calling create ensemble' 

    # using ioda mods to get a python version with netCDF4
    source ${SCRIPTDIR}/ioda_mods_hera

    python ${SCRIPTDIR}/letkf_create_ens.py $FILEDATE $B
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
source ${JEDI_EXECDIR}/../../../fv3_mods_hera

if [[ $do_DA == "YES" ]]; then
    srun -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} letkf_land.yaml ${LOGDIR}/jedi_letkf.log
    if [[ $? != 0 ]]; then
        echo "JEDI DA failed"
        exit 10
    fi
fi 
if [[ $do_HOFX == "YES" ]]; then  
    srun -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} hofx_land.yaml ${LOGDIR}/jedi_hofx.log
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
/
EOF

    echo 'do_landDA: calling apply snow increment'
    source ${SCRIPTDIR}/land_mods_hera

    # (n=6) -> this is fixed, at one task per tile (with minor code change, could run on a single proc). 
    srun '--export=ALL' -n 6 ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
    if [[ $? != 0 ]]; then
        echo "apply snow increment failed"
        exit 10
    fi

  fi

fi 

################################################
# 7. CLEAN UP
################################################

if  [[ $SAVE_TILE == "YES" ]]; then
   for tile in 1 2 3 4 5 6 
   do
     cp ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${OUTDIR}/modl/restarts/tile/${FILEDATE}.sfc_data_anal.tile${tile}.nc
   done
fi 

# keep IMS IODA file
if [ $SAVE_IMS == "YES"  ]; then
   if [[ -e ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ]]; then
      cp ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ${OUTDIR}/DA/IMSproc/
   fi
fi 

# keep increments
if [ $SAVE_INCR == "YES" ] && [ $do_DA == "YES" ]; then
   cp ${WORKDIR}/${FILEDATE}.xainc.sfc_data.tile*.nc  ${OUTDIR}/DA/jedi_incr/
fi 

# keep only one copy of each hofx files  
# all obs are on every processor, or is this only for Ineffcient Distribution?
if [ $REDUCE_HOFX == "YES" ]; then 
   for file in $(ls ${OUTDIR}/DA/hofx/*${YYYY}${MM}${DD}*00[123456789].nc) 
   do 
    rm $file 
   done
fi 
