# DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

To install: 

1. OPTIONAL: Install JEDI fv3-bundle and IODA converters (only if will modifying it, otherwise use the default installation). 

Note: For tests to pass, must be same version as Clara has on hera. 

Follow instructions on website. 

** As of 11/24/2021, instructions in the JEDI documentation  for the IODA converters don't work (python problem, need to use own version of python with packages installed locally). See instructions below.

2. Link to JEDI files: 

default: 
path-to-jedi-fv3-bundle-build=/scratch2/BMC/gsienkf/Clara.Draper/jedi/build/
path-to-jedi-ioda-bundle-src=/scratch2/BMC/gsienkf/Clara.Draper/jedi/src/ioda-bundle

>cd jedi/fv3-jedi/Data 
>make_links.sh path-to-jedi-fv3-bundle-build  
>cd ../../ioda
>make_links.sh path-to-jedi-ioda-bundle-src
>cd ../../../

3. Fetch submodules

>git submodule update --init

4. compile directories

>cd add_jedi_incr
>build.sh 
>cd .. 
>cd IMS_proc/
>build.sh 
>cd .. 

To submit stand-alone (not as a part of cycleDA - probably doesn't work at the moment): 

5. Set your dates.
>cp analdates.sh_keep analdates.sh 

Then edit start and end dates.

7.  edit and submit script.

Update directories and resolution in do_snowDA.sh (date variable is also currently set in here)

To run: 
>sbatch do_snowDA.sh

====================

11/24/2021: temporary instructions for installing ioda bundle on hera.

Install required packages locally: 
>source jedi_mods_ioda  ** This is the file in this directory.

>git clone  https://github.com/Unidata/cftime
>cd cftime
>/apps/intel/intelpython3/bin/python setup.py build
>/apps/intel/intelpython3/bin/python setup.py install --user
>git clone https://github.com/Unidata/netcdf4-python
>cd netcdf4-python
>/apps/intel/intelpython3/bin/python setup.py build
>/apps/intel/intelpython3/bin/python setup.py install --user

install ioda bundle  
>git clone https://github.com/jcsda-internal/ioda-bundle
>cd ioda-bundle
>mkdir build
>cd build
>source jedi_mods_ioda  ** This is the file in this directory.
ecbuild -DMPIEXEC_EXECUTABLE=`which srun` -DMPIEXEC_NUMPROC_FLAG="-n" -DBUILD_IODA_CONVERTERS=ON -DBUILD_PYTHON_BINDINGS=ON ..
>make -j4

