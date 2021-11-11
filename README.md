# landDA_workflow
Workflow to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noah LSM only.


To install: 

1. Install JEDI fv3-bundle. 

Follow instructions on website. ( specific version?) 

2. Install JEDI IODA-converters: 

Currently, need to install the full ioda-bundle.
** As of 11/10/2021, instructions in the JEDI documentation don't work (python problem)
The python environment on hera doesn't work. Currently using Jong Kim's anaconda installation. JEDI is working on a solution.

git clone https://github.com/jcsda-internal/ioda-bundle
cd ioda-bundle
mkdir build
cd build
source jedi_mods_ioda  ** These is the file in this directory.
ecbuild -DMPIEXEC_EXECUTABLE=`which srun` -DMPIEXEC_NUMPROC_FLAG="-n" -DBUILD_IODA_CONVERTERS=ON -DBUILD_PYTHON_BINDINGS=ON ..
make -j4

To install:

>cd jedi/fv3-jedi/Data 
>make_links.sh path-to-jedi-fv3-bundle-build  
>cd ../../ioda
>make_links.sh path-to-jedi-ioda-bundle-src
>cd ../../../

Update directories and resolution in do_snowDA.sh (date variable is also currently set in here)

To run: 
>source jedi_mods_fv3
>soure jedi_mods_ioda
>sbatch do_snowDA.sh

