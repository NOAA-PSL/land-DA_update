#! /usr/bin/env bash
set -eux

# check if part of workflow. If so, use those modules.
if [ -f ../land_mods ]; then 
  echo 'using land_mods'
  source ../land_mods
else
  echo 'using own modules'
  source hera_modules
fi 

export FCMP=mpiifort

# Check final exec folder exists
if [ ! -d "./exec" ]; then
  mkdir ./exec
fi

cd ./sorc/
./makefile.sh
