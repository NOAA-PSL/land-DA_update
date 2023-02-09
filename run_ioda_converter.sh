#!/bin/bash
. /etc/profile.d/z10_spack_environment.sh
export PYTHONPATH=/lustre/${USER}/soca-science/build/lib/pyiodaconv:/lustre/${USER}/soca-science/build/lib/python3.9/pyioda:${PYTHONPATH}
which python
echo $PYTHONPATH
python -c "import ioda_conv_engines as iconv"
echo "IMS_IODA = ${IMS_IODA}"
echo "JEDIWORKDIR = ${JEDIWORKDIR}"
ls -l ${JEDIWORKDIR}
echo "$YYYY $MM $DD $TSTUB"
echo "python ${IMS_IODA} -i IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc -o ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc"
ls -l ${IMS_IODA}
mpirun -np 1 --oversubscribe python ${IMS_IODA} -i IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc -o ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc 
echo "done"
ls -l ${JEDIWORKDIR}ioda.IMSscf.${YYYY}${MM}${DD}.${TSTUB}.nc
