R scripts to visualize Citi Bike data
=====================================

This repository contains scripts to visualize publicly available [data](http://www.citibikenyc.com/system-data) for [Citi Bikes](http://www.citibikenyc.com/) in New York.

import.R
--------

This script fetches available data files for individual rides and combines them into a single file `rides.rds`. If the file is already present, only new data is fetched and appended.
