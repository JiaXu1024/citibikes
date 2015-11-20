R scripts for Citi Bike data
============================

This repository contains scripts to work with publicly available
[data](http://www.citibikenyc.com/system-data) for [Citi
Bikes](http://www.citibikenyc.com/) in New York City.
There is an associated blog post
[here](http://ilari.scheinin.fi/citi-bikes-and-neighborhoods/).

import.R
--------

Fetch available data files for individual rides and combine them into a single
file `rides.rds`. If the file is already present, only new data is fetched and
appended. Also fetches and saves station information from the JSON feed.

flow.R
--------

[Visualize](http://ilari.scheinin.fi/shiny/citibike-flow/) how bikes flow
between different parts of the city during the day.

neighborhoods.R
---------------

[K-means clustering](http://ilari.scheinin.fi/shiny/citibike-neighborhoods/)
based on the average number of bikes arriving to and leaving from each station
every hour, calculated separately for weekdays and weekends.
