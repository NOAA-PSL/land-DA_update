# land-DA_update
Scripts to perfrom the snow DA, to assimilate GHCN station snow depth and IMS snow cover obs, using the JEDI LETKF.
For the noahMP land surface model.

To install: 

1. OPTIONAL: Install JEDI fv3-bundle and IODA converters (if on hera can use the default installations - this should work with noc hanges) 

If installing own version of fv3-bundle.
1.1 May need to make changes to the yaml (letkfoi_replay_GFSv17.yaml is used by the replay).  
To see if there are changes to the yaml in the latest version of JEDI, compare land-DA_update/jedi/fv3-jedi/yaml_files/letkf_snow.yaml_jedi_testcase to the letkf_snow.yaml in your fv3-bundle (most changes will be captured here). 

1.2 Update JEDI_EXECDIR in settings_snowDA to point to your JEDI build/bin directory. 
    fv3_mods_hera is sourced in do_landDA.sh before calling JEDI. Update to point to your JEDI fv3-bundle modules.
    use land-DA_update/jedi/fv3-jedi/Data/make_links.sh to replace links in Data with your version of JEDI 

Note: The JEDI ioda converter for IMS is currently coppied into this repo, as there is a small change from the version in the repo. Will need to run this with a version of python that is consistent with the IODA converter repo (maybe need to actually install the repo, I'm not sure).
 
2. Fetch submodules

>git submodule update --init

4. compile directories

> build_all.sh 

(also creates necessary links)

To run:

1. Edit settings file, edit submit_landDA.sh (your account details, your settings file) 
>sbatch submit_landDA.sh

