#!/bin/bash
. /etc/profile.d/z10_spack_environment.sh
export LD_LIBRARY_PATH="/opt/view/lib:$LD_LIBRARY_PATH"
echo "mpirun -np 6 --oversubscribe ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log"
mpirun -np 6 --oversubscribe ${INCR_EXECDIR}/apply_incr ${LOGDIR}/apply_incr.log
echo "done running apply_incr"
