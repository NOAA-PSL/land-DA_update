#!/bin/bash

source env_GDASApp

for source in add_jedi_incr IMS_proc
do
cd $source
echo 'compiling '$source
./build.sh
cd ..
done
