#!/bin/bash
. /etc/profile.d/z10_spack_environment.sh
export PYTHONPATH=/lustre/${USER}/soca-science/build/lib/pyiodaconv:/lustre/${USER}/soca-science/build/lib/python3.9/pyioda:${PYTHONPATH}
mpirun -np 1 --oversubscribe python ${LANDDADIR}/letkf_create_ens.py $FILEDATE $SNOWDEPTHVAR $B
echo "done running letkf_create_ens.py"
