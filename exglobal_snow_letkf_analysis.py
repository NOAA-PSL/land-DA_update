#!/usr/bin/env python3
# exglobal_snow_letkf_analysis.py
# (adapted from exglobal_snowens_analysis.py)
# This script creates an SnowEnsAnalysis class instance from snow_letkf_analysis,
# which will process snow observations, run a LETKF analysis, and add increments 
# to background ensmbles to create an ensemble of snow analyses
import os

from wxflow import Logger, cast_strdict_as_dtypedict
from pygfs.task.snow_letkf_analysis import SnowEnsAnalysis

# Initialize root logger
logger = Logger(level=os.environ.get("LOGGING_LEVEL", "DEBUG"), colored_log=True)


if __name__ == '__main__':

    # Take configuration from environment and cast it as python dictionary
    config = cast_strdict_as_dtypedict(os.environ)

    # Instantiate the snow ensemble analysis task
    snow_ens_anl = SnowEnsAnalysis(config)

    # Initialize JEDI 2DVar snow analysis
    snow_ens_anl.initialize()

    # stage ensemble mean backgrounds ??why?

    # Process SNOCVR and SNOMAD (if applicable)
    if snow_ens_anl.task_config.DO_SNOCVR_SNOMAD:
        snow_ens_anl.prepare_SNOCVR_SNOMAD()

    # Process IMS snow cover (if applicable)
    if snow_ens_anl.task_config.DO_IMS_SCF:
        snow_ens_anl.execute('scf_to_ioda')

    # Process GHCN (if applicable)
    if snow_ens_anl.task_config.DO_GHCN:
        snow_ens_anl.prepare_GHCN()

    # Execute JEDI snow analysis
    snow_ens_anl.execute('snowensanlletkf')

    # Add increments
    snow_ens_anl.add_increments()

    # Finalize JEDI snow analysis
    snow_ens_anl.finalize()
