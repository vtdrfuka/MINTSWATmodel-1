# MINTSWATmodel [![Tests](https://github.com/mintproject/MINTSWATmodel/actions/workflows/test.yml/badge.svg)](https://github.com/mintproject/MINTSWATmodel/actions/workflows/test.yml)

Currently pulls standard ArcSWAT structured initialization out of repository

## How to use?

Start the container

```bash
$ docker build  -t mintproject/MINTSWATmodel .
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
