#!/bin/bash
#BATCH --job-name=landDA
#SBATCH -t 00:05:00
#SBATCH -A gsienkf
##SBATCH --qos=debug
#SBATCH --qos=batch
#SBATCH -o landDA.out
#SBATCH -e landDA.out
#SBATCH --nodes=1
#SBATCH --tasks-per-node=6

# C48 or C96 
##SBATCH --nodes=1
##SBATCH --tasks-per-node=6

# C768
##SBATCH --nodes=4
##SBATCH --tasks-per-node=24

# script to perform snow depth update for UFS. Includes: 
# 1. staging and preparation of obs. 
#    note: IMS obs prep currently requires model background, then conversion to IODA format
# 2. creation of pseudo ensemble 
# 3. run LETKF to generate increment file 
# 4. add increment file to restarts (=disaggregation of bulk snow depth update into updates 
#    to SWE snd SD in each snow layer).

# Clara Draper, Oct 2021.

# to-do: 
# * switch IMS back to Brasnett once fv3-bundle is updated for altitude/height
# * process GHCN obs to have height, and change QC in letkf.yaml
# check that slmsk is always taken from the forecast file (oro files has a different definition)
# make sure documentation is updated.

# user directories

WORKDIR=/scratch2/BMC/gsienkf/Clara.Draper/workdir/   
SCRIPTDIR=/scratch2/BMC/gsienkf/Clara.Draper/gerrit-hera/landDA_workflow/
OBSDIR=/scratch2/BMC/gsienkf/Clara.Draper/data_RnR/
OUTDIR=${SCRIPTDIR}/output/
LOGDIR=${OUTDIR}/logs/
#RESTART_IN=/scratch2/BMC/gsienkf/Clara.Draper/DA_test_cases/20191215_C48/ #C48
#RESTART_IN=/scratch2/BMC/gsienkf/Clara.Draper/jedi/create_ens/mem_base/  #C768 
RESTART_IN=/scratch2/BMC/gsienkf/Clara.Draper/data_RnR/example_restarts/

# executable directories

FIMS_EXECDIR=${SCRIPTDIR}/IMSobsproc/exec/   
INCR_EXECDIR=${SCRIPTDIR}/AddJediIncr/exec/   

# JEDI FV3 Bundle directories

JEDI_EXECDIR=/scratch2/BMC/gsienkf/Clara.Draper/jedi/build/bin/
JEDI_STATICDIR=${SCRIPTDIR}/jedi/fv3-jedi/Data/

# JEDI IODA-converter bundle directories

IODA_BUILD_DIR=/scratch2/BMC/gsienkf/Clara.Draper/jedi/src/ioda-bundle/build/

# EXPERIMENT SETTINGS

RES=96
B=30  # back ground error std.

# STORAGE SETTINGS 

SAVE_IMS="YES" # "YES" to save processed IMS IODA file
SAVE_DATA="YES" # "YES" to save increment (add others?) JEDI output

THISDATE=2019121518 

############################################################################################
# SHOULD NOT HAVE TO CHANGE ANYTHING BELOW HERE (except srun call for different resolutions)

source workflow_mods_bash
module list 

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
DOY=$(date -d "${YYYY}-${MM}-${DD}" +%j)

cd $WORKDIR 

# establish temporary work directory
rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR 
ln -s $OUTDIR ${WORKDIR}/output

################################################
# PREPARE OBS FILES
################################################


# SET IODA PYTHON PATHS
export PYTHONPATH="${IODA_BUILD_DIR}/lib/pyiodaconv":"${IODA_BUILD_DIR}/lib/python3.6/pyioda"

# stage GHCN
ln -s $OBSDIR/GHCN/data_proc/ghcn_snwd_ioda_${YYYY}${MM}${DD}.nc_altitude ghcn_${YYYY}${MM}${DD}.nc

# prepare IMS
for tile in 1 2 3 4 5 6 
do
ln -s $RESTART_IN/${FILEDATE}.sfc_data.tile${tile}.nc ${WORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc
done

cat >> fims.nml << EOF
 &fIMS_nml
  idim=$RES, jdim=$RES,
  jdate=${YYYY}${DOY},
  yyyymmdd=${YYYY}${MM}${DD},
  IMS_OBS_PATH="${OBSDIR}/IMS/data_in/${YYYY}/",
  IMS_IND_PATH="${OBSDIR}/IMS/index_files/"
  /
EOF

echo 'snowDA: calling fIMS'

${FIMS_EXECDIR}/calcfIMS
if [[ $? != 0 ]]; then
    echo "fIMS failed"
    exit 
fi

cp ${SCRIPTDIR}/jedi/ioda/imsfv3_scf2ioda.py $WORKDIR

echo 'snowDA: calling ioda converter' 

# use a different version of python for ioda converter (keep for create_ensemble, as latter needs netCDF4)
module load intelpython/3.6.8 

python imsfv3_scf2ioda.py -i IMSscf.${YYYY}${MM}${DD}.C${RES}.nc -o ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc 
if [[ $? != 0 ]]; then
    echo "IMS IODA converter failed"
    exit 
fi


################################################
# CREATE PSEUDO-ENSEMBLE
################################################

cp -r $RESTART_IN $WORKDIR/mem_pos
cp -r $RESTART_IN $WORKDIR/mem_neg

echo 'snowDA: calling create ensemble' 

python ${SCRIPTDIR}/letkf_create_ens.py $FILEDATE $B
if [[ $? != 0 ]]; then
    echo "letkf create failed"
    exit 
fi

################################################
# RUN LETKF
################################################
# switch back to orional python for fv3-jedi
module load intelpython/2021.3.0

# prepare namelist
cp ${SCRIPTDIR}/jedi/fv3-jedi/letkf/letkf_snow_IMS_GHCN_C${RES}.yaml ${WORKDIR}/letkf_snow.yaml

sed -i -e "s/XXYYYY/${YYYY}/g" letkf_snow.yaml
sed -i -e "s/XXMM/${MM}/g" letkf_snow.yaml
sed -i -e "s/XXDD/${DD}/g" letkf_snow.yaml
sed -i -e "s/XXHH/${HH}/g" letkf_snow.yaml

sed -i -e "s/XXYYYP/${YYYP}/g" letkf_snow.yaml
sed -i -e "s/XXMP/${MP}/g" letkf_snow.yaml
sed -i -e "s/XXDP/${DP}/g" letkf_snow.yaml
sed -i -e "s/XXHP/${HP}/g" letkf_snow.yaml

ln -s $JEDI_STATICDIR Data 

echo 'snowDA: calling fv3-jedi' 

# C768
#srun -n 96 ${JEDI_EXECDIR}/fv3jedi_letkf.x letkf_snow.yaml ${LOGDIR}/jedi_letkf.log

# C48 and C96
srun -n 6 ${JEDI_EXECDIR}/fv3jedi_letkf.x letkf_snow.yaml ${LOGDIR}/jedi_letkf.log
echo  $?

################################################
# APPLY INCREMENT TO UFS RESTARTS 
################################################

cat << EOF > apply_incr_nml
&noahmp_snow
 date_str=${YYYY}${MM}${DD}
 hour_str=$HH
 res=$RES
/
EOF

echo 'snowDA: calling apply increment'

# (n=6) -> this is fixed, at one task per tile (with minor code change, could run on a single proc). 
srun '--export=ALL' -n 6 ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
echo $?

################################################
# CLEAN UP
################################################

# keep IMS IODA file
if [ $SAVE_IMS == "YES" ]; then
        cp ${WORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.C${RES}.nc ${OUTDIR}/IMSproc/
fi 

# keep data
if [ $SAVE_DATA == "YES" ]; then
        # increments
        cp ${WORKDIR}/${FILEDATE}.xainc.sfc_data.tile*.nc  ${OUTDIR}/jedi_incr/
fi 
