# MINTSWATmodel
Curently pulls standard ArcSWAT structured initialization out of repository into: \
~/docker/MINTSWATmodel/mintswat/ \
runs currrent SWAT2012 model, and exports the output.[hru,sub,rch] SWAT output files into SQLite tables in: \
~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite 


```
# Docker Hub PULL Based (SKIP if you want to build from git)
docker pull drfuka/mintswatmodel:latest
mkdir -p ~/docker/MINTSWATmodel
cd ~/docker/MINTSWATmodel/
docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat drfuka/mintswatmodel:latest
docker run --rm -v ~/docker/MINTSWATmodel/:/mintswat curlimages/curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/MINTSWATmodel.R -o /mintswat/MINTSWATmodel.R

# Build based (SKIP if you did docker pull based)
mkdir -p ~/docker/MINTSWATmodel
cd ~/docker/MINTSWATmodel/
docker run --name MINTSWATmodel alpine/git clone https://github.com/vtdrfuka/MINTSWATmodel.git
docker cp MINTSWATmodel:/git/MINTSWATmodel/Dockerfile ~/docker/MINTSWATmodel/
docker cp MINTSWATmodel:/git/MINTSWATmodel/MINTSWATmodel.R ~/docker/MINTSWATmodel/
docker build -t mintswatmodel .
docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat mintswatmodel

# Script-based Session
cd ~/docker/MINTSWATmodel/
cp MINTSWATmodel.R mintswat/
docker exec -it mint_swat R -f MINTSWATmodel.R
docker kill mint_swat;docker rm mint_swat

# Check for data in the SQLite tables
sqlite3 ~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite .tables
sqlite3 ~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite "select * from output_hru limit 10"

# Interactive R session
docker exec -it mint_swat R
# hand enter lines from MINTSWATmodel.R
docker kill mint_swat;docker rm mint_swat

# Cleanup
cd ~/docker/
rm -rf ~/docker/MINTSWATmodel

# Note on saving to Docker Hub if your memory is as short as DRFuka
docker tag mintswatmodel drfuka/mintswatmodel
docker push drfuka/mintswatmodel

# And don't do this unless you are stupid
# docker system prune --volumes
```
