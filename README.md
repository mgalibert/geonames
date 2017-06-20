# geonames
Fetch translations from http://www.geonames.org/ for Trainline stations https://github.com/trainline-eu/stations

## Install

You'll need Ruby on your computer to run this script.

Install dependencies:

```bash
make install
```

## Run

Launch batch translations search:

```bash
make run
```

It will populate a local cache to avoid querying the API twice with the same search.
When the process is finished, you'll get the modified stations file in `stations2.csv`.

And for the final touch:

```bash
make polish
```

It will check and fix a few things about parent / child relationships and generate `stations3.csv`,
ready to be contributed back to the official stations project.

