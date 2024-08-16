# land-DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS(or VIIRS) snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

To install: 

1. OPTIONAL: Install JEDI fv3-bundle and IODA converters (only if will modifying, otherwise use the default installation). 

2. Fetch submodules

>git submodule update --init

4. link JEDI files, and compile directories

> make_links.sh
> build_all.sh

To run:  (not sure this still works) 

1. Edit settings file, edit submit_landDA.sh (your account details, your settings file) 
>sbatch submit_landDA.sh

