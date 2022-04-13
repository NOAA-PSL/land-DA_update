# DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

To install: 

1. Install JEDI fv3-bundle. (specific version?) 

Follow instructions on website. 

2. If doing IMS assimilation: install JEDI IODA-converters: 

Currently, need to install the full ioda-bundle.
** As of 11/24/2021, instructions in the JEDI documentation don't work (python problem, need to use own version of python with packages installed locally). See instructions below.

3. Link to JEDI files: 

>cd jedi/fv3-jedi/Data 
>make_links.sh path-to-jedi-fv3-bundle-build  
>cd ../../ioda
>make_links.sh path-to-jedi-ioda-bundle-src
>cd ../../../

4. Fetch submodules

>git submodule update --init

5. compile submodules 

>cd add_jedi_incr
>build.sh 
>cd .. 
>cd IMSobsproc/
>cd .. 
>build.sh 

To submit stand-along (not as a part of cycleDA):
6. Set your dates.
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

