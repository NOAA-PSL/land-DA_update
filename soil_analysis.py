#!/usr/bin/env python3
# exglobal_snow_analysis.py
# This script creates an SnowAnalysis class
# and runs the initialize, execute and finalize methods
# for a global Snow Depth analysis
import os

from wxflow import Logger, cast_strdict_as_dtypedict
from pygfs.task.soil_analysis import SoilAnalysis

# Initialize root logger
logger = Logger(level=os.environ.get("LOGGING_LEVEL", "DEBUG"), colored_log=True)


if __name__ == '__main__':

    # Take configuration from environment and cast it as python dictionary
    config = cast_strdict_as_dtypedict(os.environ)

    # Instantiate the analysis task
    anl = SoilAnalysis(config)

    # Initialize JEDI (2DVar) analysis
    anl.initialize()

    # Execute JEDI 
    anl.execute('soilanlvar')

    # Add increments
    anl.execute('soilanladdinc')
#    anl.add_increments()

    # Finalize analysis
    anl.finalize()
