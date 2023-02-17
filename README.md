# land-DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

Note, this branch is intended for use as part of the land-offline_workflow public release-v1.0.0. It should be
cloned as part of a recursive clone of that repository and build using ecbuild and the module files that
are provided under land-offline_workflow/modulefiles. If installing on a machine other than Hera or Orion,
it is recommended to use the singularity container provided with the public release.

To run standalone: 

1. Edit settings file, edit submit_landDA.sh (your account details, your settings file) 
>sbatch submit_landDA.sh

