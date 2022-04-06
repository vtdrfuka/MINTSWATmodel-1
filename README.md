# MINTSWATmodel [![Tests](https://github.com/mintproject/MINTSWATmodel/actions/workflows/test.yml/badge.svg)](https://github.com/mintproject/MINTSWATmodel/actions/workflows/test.yml)

Currently pulls standard ArcSWAT structured initialization out of repository

## How to use?

Create the Docker Image. This image is using [R base image](https://github.com/mintproject/swatbase). Please, add new dependencies on it.

```bash
$ docker build  -t mintproject/MINTSWATmodel .
```

Run the image

```bash
$ docker run -ti mintproject/MINTSWATmodel bash
```


Run the initialization scripts

```bash
$  Rscript SWATMINT0.2.R -p deiter:10 -p rch:3 -s calib01 -d https://bit.ly/grdcdownload_external_331d632e-deba-44c2-9ed8-396d646adb8d_2021-12-03_19-13_zip
```

## Old documentation

[README.md](README-OLD.md)
