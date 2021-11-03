# landDA_workflow
Workflow to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noah LSM only.

To install:

>cd jedi/fv3-jedi/Data 
>make_links.sh path-to-jedi-fv3-bundle-build 

Update directories and resolution in do_snowDA.sh (date variable is also currently set in here)

To run: 
>source jedi_mods_IODA_FV3
>sbatch do_snowDA.sh
