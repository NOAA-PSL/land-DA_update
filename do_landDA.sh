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

# TODO 11.09.2024: for revisions for running ensemble DA with LETKF in JEDI
# 1. tile numbers as input dictate tile loops
# 
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

# set executable directories
source ${LANDDADIR}/env_GDASApp
#echo ${PYTHONPATH}

ntiles=${ntiles:-6}

NPROC_JEDI=${NPROC_JEDI:-6}

layout_x=${layout_x:-1}
layout_y=${layout_y:-1}
io_layout_x=${io_layout_x:-1}
io_layout_y=${io_layout_y:-1}
ens_size=${ens_size:-1}
export NMEM_ENS=${ens_size}

LOGDIR=${OUTDIR}/DA/logs/
OBSDIR=${OBSDIR:-"/scratch4/NCEPDEV/land/data/DA/"}

# set executable directories
export JEDI_EXECDIR=${JEDI_EXECDIR:-"${GDASApp_root}/build/bin/"}

# create local copy of JEDI_STATICDIR, so can over-ride default files 
# (March 2024, using own fieldMetaData override file)
JEDI_STATICDIR=${LANDDADIR}/jedi/fv3-jedi/Data/

# set to "YES" to use apply_incr and IMS_proc execs from GDASAppa
# set to "NO" to use apply_incr and IMS_proc execs from workflow provided directory
# Currently only support "YES" as of 01/28/2026
UseGDASAppExec="YES"

if [[ $UseGDASAppExec == "YES" ]]; then 
    FIMS_EXECDIR=${LANDDADIR}/GDASApp/build/bin/
    INCR_EXECDIR=${LANDDADIR}/GDASApp/build/bin/
else
    FIMS_EXECDIR=${LANDDADIR}/IMS_proc/exec/bin/
    INCR_EXECDIR=${LANDDADIR}/add_jedi_incr/exec/bin/
fi

# storage settings 

SAVE_IMS=${SAVE_IMS:-"NO"} # "YES" to save processed IMS IODA file
SAVE_INCR=${SAVE_INCR:-"NO"} # "YES" to save increment (add others?) JEDI output
SAVE_TILE=${SAVE_TILE:-"NO"} # "YES" to save background in tile space
KEEPJEDIDIR=${KEEPJEDIDIR:-"NO"} # delete DA workdir 
SAVE_ANL=${SAVE_ANL:-"NO"} # "YES" to save JEDI Analysis outputs
SAVE_HOFX=${SAVE_HOFX:-"NO"} # "YES" to save hofx


echo 'THISDATE in land DA, '$THISDATE

################################################
# 0. FORMAT DATE STRINGS AND STAGE RESTARTS
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

if [[ ${DAalg} == '2DVar' || ${DAalg} == 'letkf' ]]; then   # todo: check this further and possibly make this default?
   HALFWINLEN=$(($WINLEN/2))
   DABEGIN=`${INCDATE} $THISDATE -$HALFWINLEN`
else
   DABEGIN=`${INCDATE} $THISDATE -$WINLEN`
fi

YYYB=`echo $DABEGIN | cut -c1-4`
MB=`echo $DABEGIN | cut -c5-6`
DB=`echo $DABEGIN | cut -c7-8`
HB=`echo $DABEGIN | cut -c9-10`


export PDY=`echo $THISDATE | cut -c1-8`
export cyc=`echo $THISDATE | cut -c9-10`
export cycle="t${cyc}z"

export assim_freq=${PCYC_DEL}

# make sure letkf settings are consistent
if [[ ${DAalg} == 'letkf' && "$ens_size" -lt 2 ]]; then
    echo "Error! LETKF requires at least 2 ens members. Exiting"
    exit
fi


############################################################################################
# 1. create output directories.
# we keep increment, hofx, and restart/forecast separate 
# TODO: review this later--some dirs may not be necessary
##########################################################################

if [[ ! -e ${OUTDIR}/DA ]]; then

    mkdir -p ${OUTDIR}/DA
    mkdir ${OUTDIR}/DA/IMSproc
    mkdir ${OUTDIR}/DA/jedi_incr
    mkdir ${OUTDIR}/DA/logs
    mkdir ${OUTDIR}/DA/hofx
    mkdir ${OUTDIR}/DA/jedi_anl
    mkdir ${OUTDIR}/DA/jedi_conf
    if [[ "$ens_size" -gt 1  ]]; then            
       for ie in $(seq 0 $ens_size)     
       do
           mem_ens="mem`printf %03i $ie`"
           mkdir ${OUTDIR}/DA/jedi_incr/${mem_ens}     
           mkdir ${OUTDIR}/DA/jedi_anl/${mem_ens}
       done    
    fi   
fi 

if [[ ! -e $JEDIWORKDIR ]]; then 

    mkdir $JEDIWORKDIR      
    mkdir ${JEDIWORKDIR}/restarts     

    if [[ "$ens_size" -gt 1  ]]; then  
        for ie in $(seq 0 $ens_size)
        do
            mem_ens="mem`printf %03i $ie`"
            ln -s $WORKDIR/${mem_ens} $JEDIWORKDIR/${mem_ens}               
            ln -s ${FIXorog}/${CASE}/${TSTUB}* ${JEDIWORKDIR}/${mem_ens} 
        done   
    fi 
    ln -s ${FIXorog}/${CASE}/${TSTUB}* ${JEDIWORKDIR}
    ln -s ${FIXorog}/${CASE}/${TSTUB}* ${JEDIWORKDIR}/restarts/ # to-do. change to only need one copy.

    ln -s ${OUTDIR}  ${JEDIWORKDIR}/output
	
    # separate obscom_in from workdir(DATA)
    mkdir ${JEDIWORKDIR}/COMIN_OBS 

fi

cd $JEDIWORKDIR 


FILEDATE=${YYYY}${MM}${DD}.${HH}0000

mem_ens="mem000"
RSTRDIR=${WORKDIR}/${mem_ens}

if  [[ $SAVE_TILE == "YES" ]]; then          
    for tile in $(seq 1 $ntiles)
    do 
    cp ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc  ${RSTRDIR}/${FILEDATE}.sfc_data_back.tile${tile}.nc
    done    
    
    if [[ "$ens_size" -gt 1  ]]; then 
        for ie in $(seq 0 $ens_size)
        do
            mem_ens="mem`printf %03i $ie`"     
            for tile in $(seq 1 $ntiles) 
            do 
            cp ${WORKDIR}/${mem_ens}/${FILEDATE}.sfc_data.tile${tile}.nc  ${WORKDIR}/${mem_ens}/${FILEDATE}.sfc_data_back.tile${tile}.nc
            done    
        done  
    fi
fi 

#stage restarts for applying JEDI update (files will get directly updated)
# for LETKF, mem000 (ensemble mean) used in IMS Calc 
for tile in $(seq 1 $ntiles) 
do
    ln -fs ${RSTRDIR}/${FILEDATE}.sfc_data.tile${tile}.nc ${JEDIWORKDIR}/restarts/${FILEDATE}.sfc_data.tile${tile}.nc
done

cres_file=${JEDIWORKDIR}/restarts/${FILEDATE}.coupler.res
if [[ -e  ${RSTRDIR}/${FILEDATE}.coupler.res ]]; then 
    cp ${RSTRDIR}/${FILEDATE}.coupler.res $cres_file
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

if [[ "$ens_size" -gt 1  ]]; then  
    
    for ie in $(seq 0 $ens_size)  
    do
        mem_ens="mem`printf %03i $ie`"
        cp ${cres_file} ${JEDIWORKDIR}/${mem_ens}/${FILEDATE}.coupler.res
    done
fi

################################################
# 2. PREPARE OBS FILES
################################################

echo "updating obs list. File ${OBS_LIST_YAML} will be overwritten"
> ${OBS_LIST_YAML}
echo "observations:" >> ${OBS_LIST_YAML}

for ii in "${!OBS_TYPES[@]}"; # loop through requested obs
do  #TODO: ignore file not found errors in cp ?

  # get the obs file name 
  if [ ${OBS_TYPES[$ii]} == "IMS" ]; then 
     DOY=$(date -d "${YYYY}-${MM}-${DD}" +%j)
     obsfile=${COMINobsproc_prfx}/gdas.${YYYY}${MM}${DD}/${HH}/atmos/gdas.t${HH}z.imssnow96.asc
     obs_list_i="ims_snow"  
     cp $obsfile $COMIN_OBS/gdas.t${HH}z.imssnow96.asc  
  elif [ ${OBS_TYPES[$ii]} == "GHCN" ]; then
     obsfile=$OBSDIR/snow_depth/GHCN/processed_data/${YYYY}/${YYYY}${MM}${DD}.csv
     obs_list_i="ghcn_snow"
     cp $obsfile $COMIN_OBS/gdas.t${HH}z.ghcn_snow.csv 
  elif [ ${OBS_TYPES[$ii]} == "MADIS" ]; then
     obsfile=${COMINobsproc_prfx}/gdas.${YYYY}${MM}${DD}/${HH}/atmos/gdas.t${HH}z.snocvr_snow.nc4
     obs_list_i="madis_snow"  
     cp $obsfile $COMIN_OBS
  elif [ ${OBS_TYPES[$ii]} == "SFCSNO" ]; then
     #obsfile=$OBSDIR/snow_depth/GTS/data_proc/${YYYY}${MM}/sfcsno_snow_${YYYY}${MM}${DD}${HH}.nc4
     obsfile=${COMINobsproc_prfx}/gdas.${YYYY}${MM}${DD}/${HH}/atmos/gdas.t${HH}z.sfcsno.tm00.bufr_d
     obs_list_i="sfcsno"
     cp $obsfile ${COMIN_OBS}            #/gdas.t${HH}z.${obs_list_i}.nc4
  elif [ ${OBS_TYPES[$ii]} == "SNOCVR_SNOMAD" ]; then
     obsfile=${COMINobsproc_prfx}/gdas.${YYYY}${MM}${DD}/${HH}/atmos/gdas.t${HH}z.snocvr.tm00.bufr_d
     [ -e $obsfile ] && cp $obsfile ${COMIN_OBS}
     obsfile2=${COMINobsproc_prfx}/gdas.${YYYY}${MM}${DD}/${HH}/atmos/gdas.t${HH}z.snomad.tm00.bufr_d
     [ -e $obsfile2 ] && cp $obsfile2 ${COMIN_OBS}
     obs_list_i="snocvr_snomad"
  elif [ ${OBS_TYPES[$ii]} == "SMAP" ]; then
#TODO: move to obsdir/soil_moisture
     obsfile=$OBSDIR/SMAP/data_proc/v5/${YYYY}/smap_${YYYY}${MM}${DD}T${HH}00.nc     
     obs_list_i="smap_soil"
     cp $obsfile  $COMIN_OBS/gdas.t${HH}z.${obs_list_i}.nc
  else
     echo "do_landDA: Unknown obs type requested ${OBS_TYPES[$ii]}, exiting" 
     exit 1 
  fi

  # check obs are available
  if [ ${OBS_TYPES[$ii]} == "SNOCVR_SNOMAD" ]; then
      if [[ -e $obsfile && -e $obsfile2 ]]; then
	  echo "${OBS_TYPES[$ii]} both observations found: $obsfile and $obsfile2"
      elif [[ -e $obsfile ]]; then
          echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile"
      elif [[ -e $obsfile2 ]]; then
          echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile2"
      else
          echo "${OBS_TYPES[$ii]} observations not found: $obsfile or $obsfile2"
          JEDI_TYPES[$ii]="SKIP"
      fi
  else       #TODO because of copy error, this section might never be executed 
      if [[ -e $obsfile ]]; then
          echo "do_landDA: ${OBS_TYPES[$ii]} observations found: $obsfile"
      else
          echo "${OBS_TYPES[$ii]} observations not found: $obsfile"
          JEDI_TYPES[$ii]="SKIP"
      fi
  fi

  echo "- ${obs_list_i}" >> ${OBS_LIST_YAML}
  
done # if assim

################################################
# 3. DETERMINE REQUESTED JEDI TYPE
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
         echo "do_landDA: Unknown obs action ${JEDI_TYPES[$ii]}, exiting"
         exit 1
   fi
done

if [[ $do_DA == "NO" && $do_HOFX == "NO" ]]; then 
        echo "do_landDA: No obs found, not calling JEDI" 
        exit 0 
fi

######################################################################
# 4. Run snow analysis (includes init, run jedi, add increments)
######################################################################

export SOLVER="localensembleda"   #Default solver 
if [[ ${DAalg} == '2DVar' ]]; then 
	export SOLVER="variational" 
fi

if [[ "$analType" == "snow" ]]; then

    SNOWDEPTHVAR="snodl"	
    
    ${LANDDADIR}/exglobal_snow_analysis.py   #${LANDDADIR}/snow_analysis.py
    status=$?
    if [[ "${status}" -ne 0 ]]; then 
        exit "snow analysis failed ${status}"
    fi

elif [[ "$analType" == "smc" ]]; then 
    
    SOILANLVAR="soilMoistureVolumetric"

    ${LANDDADIR}/soil_analysis.py
    status=$?
    if [[ "${status}" -ne 0 ]]; then
        exit "soil analysis failed ${status}"
    fi
else
   echo " error! unsupported analysis variable $anlvar"
   exit 1
fi
#fi


################################################
# 7. CLEAN UP
################################################

# keep IMS IODA file
if [ $SAVE_IMS == "YES"  ] && [ $UseGDASAppExec == "NO" ]; then
  if [[ -e ${JEDIWORKDIR}/ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc ]]; then
    yes |cp -u ${JEDIWORKDIR}/ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc ${OUTDIR}/DA/IMSproc/
  fi
fi

if [ $SAVE_IMS == "YES"  ] && [ $UseGDASAppExec == "YES" ]; then
  if [[ -e ${JEDIWORKDIR}/obs/gdas.t00z.ims_snow.tm00.nc ]]; then
    yes |cp -u ${JEDIWORKDIR}/obs/gdas.t00z.ims_snow.tm00.nc ${OUTDIR}/DA/IMSproc/ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc
  fi
fi

# keep diag files
if [ $SAVE_HOFX == "YES"  ] && [ $UseGDASAppExec == "YES" ]; then
    yes |cp -u ${JEDIWORKDIR}/diags/diag_*${YYYY}${MM}${DD}*.nc ${OUTDIR}/DA/jedi_anl/
fi

# keep increments
if [ $SAVE_INCR == "YES" ] && [ $do_DA == "YES" ] && [ $UseGDASAppExec == "NO" ]; then
   if [[ "$ens_size" -eq 1  ]]; then
    yes |cp -u ${JEDIWORKDIR}/snowinc.${FILEDATE}.sfc_data.tile*.nc  ${OUTDIR}/DA/jedi_incr/
   fi
fi

# clean up 
if [[ $KEEPJEDIDIR == "NO" ]]; then
   rm -rf ${JEDIWORKDIR} 
fi
