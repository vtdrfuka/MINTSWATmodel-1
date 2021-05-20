# MINTSWATmodel


```
# Docker Hub PULL Based (SKIP if you want to build from git)
docker pull drfuka/mintswatmodel:latest

# Interactive sessions
mkdir -p ~/docker/MINTSWATmodel
docker run --name MINTSWATmodel alpine/git clone https://github.com/vtdrfuka/MINTSWATmodel.git
docker cp MINTSWATmodel:/git/MINTSWATmodel/Dockerfile ~/docker/MINTSWATmodel/
docker cp MINTSWATmodel:/git/MINTSWATmodel/MINTSWATmodel.R ~/docker/MINTSWATmodel/
docker rm MINTSWATmodel
cd ~/docker/MINTSWATmodel/

# Build based (SKIP if you did docker pull based)
docker build -t mintswatmodel .
#
docker stats
docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat drfuka/mintswatmodel:latest
cp MINTSWATmodel.R mintswat/
docker exec -it mint_swat R -f MINTSWATmodel.R
docker kill mint_swat;docker rm mint_swat

# Check for data in the SQLite tables
sqlite3 ~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite .tables
sqlite3 ~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite "select * from output_hru limit 10"

#
# Cleanup
rm -rf ~/docker/MINTSWATmodel

# Note on saving to Docker Hub if your memory is as short as DRFuka
docker tag mintswatmodel drfuka/mintswatmodel
docker push drfuka/mintswatmodel

# And don't do this unless you are stupid
# docker system prune --volumes
```
