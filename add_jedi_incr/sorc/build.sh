#! /usr/bin/env bash
set -eux

machine="aws"

if [ $machine == "hera" ]; then
   source ./hera_modules
elif [ $machine == 'aws' ]; then
   source ./aws_modules
fi 

export FCMP=mpiifort

# Check final exec folder exists
if [ ! -d "./exec" ]; then
  mkdir ./exec
fi

cd ./sorc/
./makefile.sh
