#!/bin/bash
. /etc/profile.d/z10_spack_environment.sh
IODA_V2_FILE=$1
IODA_V3_FILE=$2
export LD_LIBRARY_PATH=/lustre/Jeffrey.S.Whitaker/fv3-jedi/build/lib:$JEDI_LD_LIBRARY_PATH
mpirun -np 1 --oversubscribe /lustre/Jeffrey.S.Whitaker/soca-science/build/bin/ioda-upgrade-v2-to-v3.x $IODA_V2_FILE $IODA_V3_FILE /lustre/Jeffrey.S.Whitaker/soca-science/bundle/ioda/share/ioda/yaml/validation/ObsSpace.yaml
echo "done running ioda v2 to v3 converter"
