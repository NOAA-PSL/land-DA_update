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

# C48
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

# to do: 
# get/write program to deal with julian day
# add program to update the restarts with the increments 
# remove hardwired path from IMS IODA converter 
# use Henry's python path

# question: 
# Do we need to do anything regarding fractional grids? Currently screening DA update according to slmsk.


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
PYTHON2=/contrib/anaconda/anaconda2-4.4.0/bin/python2.7 

# JEDI FV3 Bundle directories

JEDI_EXECDIR=/scratch2/BMC/gsienkf/Clara.Draper/jedi/build/bin/
JEDI_STATICDIR=${SCRIPTDIR}/jedi/fv3-jedi/Data/

# JEDI IODA-converter bundle directories

IODA_BUILD_DIR=/scratch1/NCEPDEV/da/Youlong.Xia/ioda-bundle/build
PYTHON3=/scratch2/NCEPDEV/marineda/Jong.Kim/anaconda3-save/bin/python
#PYTHON3=/apps/intel/intelpython3/bin/python # from Henry

#setenv PYTHONPATH ${PYTHONPATH}:/home/Clara.Draper/.local/lib/python3.6/site-packages

# EXPERIMENT SETTINGS

RES=96
B=30  # back ground error std.

# STORAGE SETTINGS 

SAVE_IMS="YES" # "YES" to save processed IMS IODA file

THISDATE=2019121518 
JDAY=350 # CSD sort out.

############################################################################################
# SHOULD NOT HAVE TO CHANGE ANYTHING BELOW HERE (except srun call for different resolutions)

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

# establish temporary work directory
rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR 
ln -s $OUTDIR ${WORKDIR}/output

################################################
# PREPARE OBS FILES
################################################

# stage GHCN
ln -s $OBSDIR/GHCN/ghcn_snod2iodaV2_${YYYY}${MM}${DD}UTC${HH}.nc ghcn_${YYYY}${MM}${DD}UTC${HH}.nc

# prepare IMS
for tile in 1 2 3 4 5 6 
do
ln -s $RESTART_IN/${FILEDATE}.sfc_data.tile${tile}.nc ${WORKDIR}/${FILEDATE}.sfc_data.tile${tile}.nc
done

cat >> fims.nml << EOF
 &fIMS_nml
  idim=$RES, jdim=$RES,
  jdate=${YYYY}${JDAY},
  yyyymmdd=${YYYY}${MM}${DD},
  IMS_OBS_PATH="${OBSDIR}/IMS/${YYYY}/",
  IMS_IND_PATH="${OBSDIR}/IMS/index_files/"
  /
EOF

${FIMS_EXECDIR}/calcfIMS

# ioda converter
IODAPY=$IODA_BUILD_DIR/lib/python3.7/
PYTHONPATH=${PYTHONPATH}:${IODAPY}
IODALIB=$IODA_BUILD_DIR/lib
#LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${IODALIB} # doesn't seem to be needed, breaks fv3-bundle

cp ${SCRIPTDIR}/jedi/ioda/imsFV3_scf2ioda_newV2.py $WORKDIR

$PYTHON3 imsFV3_scf2ioda_newV2.py -i IMSscf.${YYYY}${MM}${DD}.C${RES}.nc -o ${WORKDIR}ioda.ims_${YYYY}${MM}${DD}.nc 

################################################
# CREATE PSEUDO-ENSEMBLE
################################################

cp -r $RESTART_IN $WORKDIR/mem_pos
cp -r $RESTART_IN $WORKDIR/mem_neg

# can use either python version here
$PYTHON3 ${SCRIPTDIR}/letkf_create_ens.py $FILEDATE $B


################################################
# RUN LETKF
################################################

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

# C768
#srun -n 96 ${JEDI_EXECDIR}/fv3jedi_letkf.x letkf_snow.yaml ${LOGDIR}/jedi_letkf.log

# C48 and C96
srun -n 6 ${JEDI_EXECDIR}/fv3jedi_letkf.x letkf_snow.yaml ${LOGDIR}/jedi_letkf.log

################################################
# APPLY INCREMENT TO UFS RESTARTS 
################################################

################################################
# CLEAN UP
################################################

# keep IMS IODA file
if [ $SAVE_IMS == "YES" ]; then
        cp ${WORKDIR}ioda.ims_${YYYY}${MM}${DD}.nc ${OUTDIR}/IMSproc/
fi 

