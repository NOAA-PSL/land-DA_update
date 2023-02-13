#!/bin/bash
. /etc/profile.d/z10_spack_environment.sh
export LD_LIBRARY_PATH=/lustre/${USER}/fv3-jedi/build/lib:$JEDI_LD_LIBRARY_PATH
ldd ${JEDI_EXECDIR}/${JEDI_EXEC}
cat letkf_land.yaml
mpirun -np $NPROC_JEDI --oversubscribe ${JEDI_EXECDIR}/${JEDI_EXEC} letkf_land.yaml ${LOGDIR}/jedi_letkf.log
cat ${LOGDIR}/jedi_letkf.log
echo "done running $JEDI_EXEC"
