# land-DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

To install: 

1. OPTIONAL: Install JEDI fv3-bundle and IODA converters (only if will modifying, otherwise use the default installation). 

Note: For tests to pass, must be same version as Clara has on hera. 

2. Create links to JEDI files: 

>cd jedi/fv3-jedi/Data 
>make_links.sh [ path-to-jedi-fv3-bundle-build ]   
>cd ../../ioda
>make_links.sh [ path-to-jedi-ioda-bundle-src ]
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


To run: 

1. Edit settings file, edit submit_landDA.sh (your account details, your settings file) 
>sbatch submit_landDA.sh

