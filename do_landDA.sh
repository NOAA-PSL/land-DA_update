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

GFSv17=${GFSv17:-"NO"}
machine=${machine:-"hera"}

export LOGDIR=${OUTDIR}/DA/logs/
RSTRDIR=${RSTRDIR:-$JEDIWORKDIR/restarts/tile/} # if running offline cycling will be here
OBSDIR=${OBSDIR:-"/scratch2/NCEPDEV/land/data/DA/"}
IMS_INDEX_FILE_PATH=${IMS_INDEX_FILE_PATH:-"${OBSDIR}/snow_ice_cover/IMS/index_files/"}

# executable directories
export FIMS_EXECDIR=${LANDDADIR}/IMS_proc/exec/   
export INCR_EXECDIR=${LANDDADIR}/add_jedi_incr/exec/   

# JEDI directories
export JEDI_EXECDIR=${JEDI_EXECDIR:-"/scratch2/NCEPDEV/land/data/jedi/fv3-bundle/build/bin/"}
IODA_BUILD_DIR=${IODA_BUILD_DIR:-"/scratch2/BMC/gsienkf/UFS-RNR/UFS-RNR-stack/external/ioda-bundle/build/"}
JEDI_STATICDIR=${LANDDADIR}/jedi/fv3-jedi/Data/

# storage settings 
SAVE_IMS="YES" # "YES" to save processed IMS IODA file
SAVE_INCR="YES" # "YES" to save increment (add others?) JEDI output
SAVE_TILE=${SAVE_TILE:-"NO"} # "YES" to save background in tile space
REDUCE_HOFX="NO" # "YES" to remove duplicate hofx files (one per processor)
KEEPDADIR=${KEEPDADIR:-"YES"} # delete DA workdir 

echo 'THISDATE in land DA, '$THISDATE

############################################################################################

# create output directories.
if [[ ! -e ${OUTDIR}/DA ]]; then
    mkdir -p ${OUTDIR}/DA
    mkdir ${OUTDIR}/DA/IMSproc
    mkdir ${OUTDIR}/DA/jedi_incr
    mkdir ${OUTDIR}/DA/logs
    mkdir ${OUTDIR}/DA/hofx
fi 

if [[ ! -e $JEDIWORKDIR ]]; then 
    mkdir $JEDIWORKDIR
fi


cd $JEDIWORKDIR 

################################################
# 1. FORMAT DATE STRINGS AND STAGE RESTARTS
################################################

INCDATE=${LANDDADIR}/incdate.sh

export YYYY=`echo $THISDATE | cut -c1-4`
export MM=`echo $THISDATE | cut -c5-6`
export DD=`echo $THISDATE | cut -c7-8`
export HH=`echo $THISDATE | cut -c9-10`

PREVDATE=`${INCDATE} $THISDATE -$WINLEN`

export YYYP=`echo $PREVDATE | cut -c1-4`
export MP=`echo $PREVDATE | cut -c5-6`
export DP=`echo $PREVDATE | cut -c7-8`
export HP=`echo $PREVDATE | cut -c9-10`

export FILEDATE=${YYYY}${MM}${DD}.${HH}0000

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
     #obsfile=$OBSDIR/snow_depth/GHCN/data_proc/${YYYY}/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc
     if [ $machine == 'aws' ]; then
        if [ HH == '00' ]; then 
        # GHCN obs have been time stamped at 18 on fileday. If assimilating at 00, will need previous day's file.
        obsfile=$OBSDIR/snow/ghcn/${YYYP}/${MP}/ghcn_snwd_ioda_${YYYP}${MP}${DP}.nc
        else
        obsfile=$OBSDIR/snow/ghcn/${YYYY}/${MM}/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc
        fi
     else
        if [ HH == '00' ]; then 
        obsfile=$OBSDIR/snow_depth/GHCN/data_proc/${YYYP}v3/ghcn_snwd_ioda_${YYYP}${MP}${DP}.nc
        else 
        obsfile=$OBSDIR/snow_depth/GHCN/data_proc/${YYYY}v3/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc
        fi
     fi
  elif [ ${OBS_TYPES[$ii]} == "SYNTH" ]; then 
     obsfile=$OBSDIR/synthetic_noahmp/IODA.synthetic_gswp_obs.${YYYY}${MM}${DD}${HH}.nc
  elif [ ${OBS_TYPES[$ii]} == "SMAP" ]; then
     obsfile=$OBSDIR/soil_moisture/SMAP/data_proc/${YYYY}/smap_${YYYY}${MM}${DD}T${HH}00.nc
# Zofia - any processing of the SMAP obs goes here.
  elif [ ${OBS_TYPES[$ii]} == "IMS" ]; then 

     YYYN=`echo $THISDATE | cut -c1-4`
     MN=`echo $THISDATE | cut -c5-6`
     DN=`echo $THISDATE | cut -c7-8`
     DOY=$(date -d "${YYYN}-${MN}-${DN}" +%j)
     echo DOY is ${DOY}

     if [[ $THISDATE -gt  2004060100 ]]; then   # do not assimilate before 2004, as have only 24 km obs
        if [[ $THISDATE -gt 2014120200 ]]; then  ims_vsn=1.3 ; else  ims_vsn=1.2 ; fi
        if [ $machine == 'aws' ]; then
           obsfile=${OBSDIR}/IMS/${YYYY}/${MN}/ims${YYYY}${DOY}_4km_v${ims_vsn}.nc
        else
           obsfile=${OBSDIR}/snow_ice_cover/IMS/${YYYY}/ims${YYYY}${DOY}_4km_v${ims_vsn}.nc
        fi
     else
        obsfile=${OBSDIR}/noIMSobs # set to junk file name, if before obs are available
     fi

  else
     echo "do_landDA: Unknown obs type requested ${OBS_TYPES[$ii]}, exiting" 
     exit 1 
  fi

  # check obs are available
  if [ $machine == 'aws' ]; then
       awsls=$(aws s3 ls $obsfile)
       if [ -z "$awsls" ]; then
          file_exists=false
       else
          file_exists=true
       fi
  else
     if [[ -e $obsfile ]]; then
        file_exists=true
     else
        file_exists=false
     fi
  fi
  if [[ $file_exists == "true" ]]; then
    echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile"

    if [ $machine == 'aws' ]; then
    # stage obs on AWS 
       echo "staging obs data from s3.."
       if [ ${OBS_TYPES[$ii]} != "IMS" ]; then
          # for GHCN, stage obs, convert v2 to v3
          export obsfile_updated=${OBS_TYPES[$ii]}_${YYYY}${MM}${DD}${HH}.nc
          export obsfile_tmp="${obsfile_updated}.tmp"
          aws s3 cp $obsfile $obsfile_tmp

          # convert from IODA v2 to v3
          singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif sh ${LANDDADIR}/run_iodav2tov3.sh $obsfile_tmp $obsfile_updated
          /bin/rm -f $obsfile_tmp
       fi
    else
    # stage obs on hera
       if [ ${OBS_TYPES[$ii]} != "IMS" ]; then
          ln -fs $obsfile ${OBS_TYPES[$ii]}_${YYYY}${MM}${DD}${HH}.nc
       fi
    fi
  else
    echo "${OBS_TYPES[$ii]} observations not found: $obsfile"
    JEDI_TYPES[$ii]="SKIP"
  fi

  # pre-process and call IODA converter for IMS obs.
  if [[ ${OBS_TYPES[$ii]} == "IMS"  && ${JEDI_TYPES[$ii]} != "SKIP" ]]; then

    if [[ $machine == "aws" ]]; then 
          # stage input file
          aws s3 cp $obsfile .
    else 
          cp $obsfile ${JEDIWORKDIR}
    fi

    if [[ -e fims.nml ]]; then
        rm -rf fims.nml 
    fi
cat >> fims.nml << EOF
 &fIMS_nml
  idim=$RES, jdim=$RES,
  otype=${TSTUB},
  jdate=${YYYY}${DOY},
  yyyymmddhh=${YYYY}${MM}${DD}.${HH},
  imsformat=2,
  imsversion=${ims_vsn},
  IMS_OBS_PATH="${JEDIWORKDIR}",
  IMS_IND_PATH="${IMS_INDEX_FILE_PATH}/"
  /
EOF
    echo 'do_landDA: calling fIMS'

    if [ $machine == "hera" ]; then
       source ${LANDDADIR}/land_mods_hera
    else
       source ${LANDDADIR}/land_mods_aws
    fi

    ${FIMS_EXECDIR}/calcfIMS
    if [[ $? != 0 ]]; then
        echo "fIMS failed"
        exit 10
    fi

    export IMS_IODA=${LANDDADIR}/jedi/ioda/imsfv3_scf2ioda_obs40.py

    echo 'do_landDA: calling ioda converter' 
    if [ $machine == 'aws' ]; then
       export JEDIWORKDIR=$JEDIWORKDIR
       export TSTUB=$TSTUB
       singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif sh ${LANDDADIR}/run_ioda_converter.sh
    else
       source ${LANDDADIR}/ioda_mods_hera
       python ${IMS_IODA} -i IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc -o ${JEDIWORKDIR}iodav2.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc
    fi

    if [[ $? != 0 ]]; then
        echo "IMS IODA converter failed"
        exit 10
    fi
    # convert from IODA v2 to v3

    if [ $machine == 'aws' ]; then
       obsfile=${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc
       obsfile_updated="${obsfile}.tmp"
       singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif sh ${LANDDADIR}/run_iodav2tov3.sh $obsfile $obsfile_updated
       /bin/mv -f $obsfile_updated $obsfile
    else
        # ObsSpace coppied from: fv3-bundle/src/ioda/share/ioda/yaml/validation/ObsSpace.yaml
        export iodablddir=${JEDI_EXECDIR}/..
        export LD_LIBRARY_PATH=${iodablddir}/lib:$LD_LIBRARY_PATH
        echo 'converting iodav2 to iodav3' 
        ${JEDI_EXECDIR}/ioda-upgrade-v2-to-v3.x ${JEDIWORKDIR}iodav2.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc ${LANDDADIR}/ObsSpace.yaml
       if [[ $? != 0 ]]; then
           echo "IMS IODA v2 to v3 converter failed"
           exit 10
       fi
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

      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${DAtype}.yaml ${JEDIWORKDIR}/letkf_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "DA" ]; then
        cat ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${OBS_TYPES[$ii]}.yaml >> letkf_land.yaml
        fi 
      done

   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_DA}"
      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${YAML_DA} ${JEDIWORKDIR}/letkf_land.yaml
   fi

   sed -i -e "s/XXYYYY/${YYYY}/g" letkf_land.yaml
   sed -i -e "s/XXMM/${MM}/g" letkf_land.yaml
   sed -i -e "s/XXDD/${DD}/g" letkf_land.yaml
   sed -i -e "s/XXHH/${HH}/g" letkf_land.yaml

   sed -i -e "s/XXYYYP/${YYYP}/g" letkf_land.yaml
   sed -i -e "s/XXMP/${MP}/g" letkf_land.yaml
   sed -i -e "s/XXDP/${DP}/g" letkf_land.yaml
   sed -i -e "s/XXHP/${HP}/g" letkf_land.yaml
   sed -i -e "s/XXWINLEN/${WINLEN}/g" letkf_land.yaml

   sed -i -e "s/XXTSTUB/${TSTUB}/g" letkf_land.yaml
   sed -i -e "s#XXTPATH#${TPATH}#g" letkf_land.yaml
   sed -i -e "s/XXRES/${RES}/g" letkf_land.yaml
   RESP1=$((RES+1))
   sed -i -e "s/XXREP/${RESP1}/g" letkf_land.yaml

   sed -i -e "s/XXHOFX/false/g" letkf_land.yaml  # do DA
fi

if [[ $do_HOFX == "YES" ]]; then 

   if [[ $YAML_HOFX == "construct" ]];then  # construct the yaml

      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${DAtype}.yaml ${JEDIWORKDIR}/hofx_land.yaml

      for ii in "${!OBS_TYPES[@]}";
      do 
        if [ ${JEDI_TYPES[$ii]} == "HOFX" ]; then
        cat ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${OBS_TYPES[$ii]}.yaml >> hofx_land.yaml
        fi 
      done
   else # use specified yaml 
      echo "Using user specified YAML: ${YAML_HOFX}"
      cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/${YAML_HOFX} ${JEDIWORKDIR}/hofx_land.yaml
   fi

   sed -i -e "s/XXYYYY/${YYYY}/g" hofx_land.yaml
   sed -i -e "s/XXMM/${MM}/g" hofx_land.yaml
   sed -i -e "s/XXDD/${DD}/g" hofx_land.yaml
   sed -i -e "s/XXHH/${HH}/g" hofx_land.yaml

   sed -i -e "s/XXYYYP/${YYYP}/g" hofx_land.yaml
   sed -i -e "s/XXMP/${MP}/g" hofx_land.yaml
   sed -i -e "s/XXDP/${DP}/g" hofx_land.yaml
   sed -i -e "s/XXHP/${HP}/g" hofx_land.yaml
   sed -i -e "s/XXWINLEN/${WINLEN}/g" hofx_land.yaml

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

    export JEDI_EXEC="fv3jedi_letkf.x"

    if [ $GFSv17 == "YES" ]; then
        export SNOWDEPTHVAR="snodl" 
        # field overwrite file with GFSv17 variables.
        cp ${LANDDADIR}/jedi/fv3-jedi/yaml_files/gfs-land-v17.yaml ${JEDIWORKDIR}/gfs-land-v17.yaml
    else
        export SNOWDEPTHVAR="snwdph"
    fi

    export B=30  # back ground error std for LETKFOI

    # FOR LETKFOI, CREATE THE PSEUDO-ENSEMBLE
    for ens in pos neg 
    do
        if [ -e $JEDIWORKDIR/mem_${ens} ]; then 
                rm -r $JEDIWORKDIR/mem_${ens}
        fi
        mkdir $JEDIWORKDIR/mem_${ens} 
        for tile in 1 2 3 4 5 6
        do
        cp ${JEDIWORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${JEDIWORKDIR}/mem_${ens}/${FILEDATE}.sfc_data.tile${tile}.nc
        done
        cp ${JEDIWORKDIR}/${FILEDATE}.coupler.res ${JEDIWORKDIR}/mem_${ens}/${FILEDATE}.coupler.res
    done
       

    echo 'do_landDA: calling create ensemble' 

    if [ $machine == "aws" ]; then
       export LANDDADIR=$LANDDADIR
       singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif sh ${LANDDADIR}/run_create_ens.sh
    else
       # using ioda mods to get a python version with netCDF4
       source ${LANDDADIR}/ioda_mods_hera
       python ${LANDDADIR}/letkf_create_ens.py $FILEDATE $SNOWDEPTHVAR $B
    fi
    if [[ $? != 0 ]]; then
        echo "letkf create failed"
        exit 10
    fi

fi

################################################
# 5. RUN JEDI
################################################

export NPROC_JEDI=6

if [[ ! -e Data ]]; then
    ln -s $JEDI_STATICDIR Data 
fi

echo 'do_landDA: calling fv3-jedi' 

if [[ $do_DA == "YES" ]]; then
    if [ $machine == 'aws' ]; then
       singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif $LANDDADIR/run_jedi_letkf.sh
    else
       source ${JEDI_EXECDIR}/../../../fv3_mods_Wei_gnu
       srun -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} letkf_land.yaml ${LOGDIR}/jedi_letkf.log
    fi
fi
if [[ $? != 0 ]]; then
    echo "JEDI DA failed"
    exit 10
fi
if [[ $do_HOFX == "YES" ]]; then  
    if [ $machine == 'aws' ]; then
       singularity exec --bind /lustre:/lustre ${JEDI_EXECDIR}/jcsda-internal.gnu-openmpi.sif /opt/view/bin/mpirun -np $NPROC_JEDI --oversubscribe ${JEDI_EXECDIR}/${JEDI_EXEC} hofx_land.yaml ${LOGDIR}/jedi_hofx.log
    else
       source ${JEDI_EXECDIR}/../../../fv3_mods_Wei_gnu
       srun -n $NPROC_JEDI ${JEDI_EXECDIR}/${JEDI_EXEC} hofx_land.yaml ${LOGDIR}/jedi_hofx.log
    fi
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
    if [ $machine == "aws" ]; then
       source ${LANDDADIR}/land_mods_aws
       module list
       ldd ${INCR_EXECDIR}/apply_incr
       # (n=6) -> this is fixed, at one task per tile (with minor code change, could run on a single proc). 
       srun --mpi=pmi2 -l --export=ALL -n 6 -N 1 ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
    elif [ $machine == "hera" ]; then
       source ${LANDDADIR}/land_mods_hera
       srun '--export=ALL' -n 6 -N 1 ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
    fi
    if [[ $? != 0 ]]; then
        echo "apply snow increment failed"
        exit 10
    fi

  fi

fi 

################################################
# 7. CLEAN UP
################################################

# keep IMS IODA file
if [ $SAVE_IMS == "YES"  ]; then
   if [[ -e ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ]]; then
      cp ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ${OUTDIR}/DA/IMSproc/
   fi
fi 

# keep increments
if [ $SAVE_INCR == "YES" ] && [ $do_DA == "YES" ]; then
   cp ${JEDIWORKDIR}/${FILEDATE}.xainc.sfc_data.tile*.nc  ${OUTDIR}/DA/jedi_incr/
fi 

# keep only one copy of each hofx files  
# all obs are on every processor, or is this only for Ineffcient Distribution?
if [ $REDUCE_HOFX == "YES" ]; then 
   for file in $(ls ${OUTDIR}/DA/hofx/*${YYYY}${MM}${DD}*00[123456789].nc) 
   do 
    rm $file 
   done
fi 

# clean up 
if [[ $KEEPDADIR == "NO" ]]; then
   rm -rf ${JEDIWORKDIR} 
fi 
