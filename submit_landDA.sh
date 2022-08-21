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

# C48 or C96 
##SBATCH --nodes=1
##SBATCH --tasks-per-node=6

# C768
##SBATCH --nodes=4
##SBATCH --tasks-per-node=24

./do_landDA.sh  settings_DA_IMS


