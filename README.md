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

Download the data from GRDC

```bash
$ wget ...
```


Run the initialization scripts

```bash
$ Rscript SandBoxMINT.R 
```

## Old documentation

[README.md](README-OLD.md)
