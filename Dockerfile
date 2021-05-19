FROM rocker/r-base

LABEL org.label-schema.license="GPL-2.0" \
      org.label-schema.vcs-url="https://github.com/vtdrfuka" \
      maintainer="Daniel Fuka <drfuka@vt.edu>"

RUN apt update \
  && apt-get install -y gzip curl wget subversion jags
RUN apt-get -y --fix-missing install vim libxml2-dev libz-dev gdal-bin libudunits2-dev libxt6 libgdal-dev mpich mdbtools

#RUN Rscript -e ".libPaths('/usr/local/lib/R/site-library');BiocManager::install(c('BiocStyle','graph','Rgraphviz','RColorBrewer'))" 
#RUN Rscript -e "install.packages(Ncpus=6,lib='/usr/local/lib/R/site-library',c('rjags','fgm', 'hsdar', 'reticulate', 'SpatialEpi', 'colorspace', 'ggmap', 'Deriv', 'doParallel', 'fields', 'HKprocess', 'MatrixModels', 'tmap', 'matrixStats', 'mvtnorm', 'numDeriv', 'orthopolynom', 'pixmap', 'sn'), dep=TRUE)"
#RUN Rscript -e "install.packages(Ncpus=6,'INLA',lib='/usr/local/lib/R/site-library', repos='https://inla.r-inla-download.org/R/stable', dep=TRUE); install.packages(Ncpus=6, 'INLABMA', dep=TRUE)"

RUN apt-get clean
RUN mkdir /mintswat/

#RUN Rscript -e "library(reticulate); install_miniconda(path='/miniconda3',update=TRUE,force=TRUE)"
#RUN install2.r --error Seurat \
#  && install2.r --error hsdar \
#  && install2.r --error lidR \
#  && Rscript -e "library(devtools); install_github('jhollist/elevatr')"
RUN Rscript -e 'if (!require("pacman")) install.packages("pacman"); pacman::p_load(operators, topmodel, DEoptim, XML,data.table); system("svn checkout svn://scm.r-forge.r-project.org/svnroot/ecohydrology/"); install.packages(c("ecohydrology/pkg/EcoHydRology/","ecohydrology/pkg/SWATmodel/"),repos = NULL)' 
WORKDIR /mintswat
#CMD 
