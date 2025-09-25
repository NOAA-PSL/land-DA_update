# land-DA_update
Scripts to perfrom the land DA, with the the noahMP land surface model.

To install: 

1. Dowload and compile GDASApp (https://github.com/NOAA-EMC/GDASApp). 

2. Fetch submodules

>git submodule update --init

4. link JEDI files, and compile directories

> make_links.sh LOCATION_OF_YOUR_GDASApp
> build_all.sh

To run:  (not sure this still works) 

1. Edit settings file, edit submit_landDA.sh (your account details, your settings file) 
>sbatch submit_landDA.sh

