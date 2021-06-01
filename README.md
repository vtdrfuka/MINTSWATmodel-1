# MINTSWATmodel
Currently pulls standard ArcSWAT structured initialization out of repository into: \
~/docker/MINTSWATmodel/mintswat/ \
runs current SWAT2012 model, and exports the output.[hru,sub,rch] SWAT output files into SQLite tables in: \
~/docker/MINTSWATmodel/mintswat/MINTSWATmodel_output/MINTSWATtables.sqlite 


```
# Docker Hub PULL Based (SKIP if you want to build from git)
docker pull drfuka/mintswatmodel:latest
mkdir -p ~/docker/MINTSWATmodel
cd ~/docker/MINTSWATmodel/
docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat drfuka/mintswatmodel:latest
docker run --rm -v ~/docker/MINTSWATmodel/:/mintswat curlimages/curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/MINTSWATmodel.R -o /mintswat/MINTSWATmodel.R

# Build based (SKIP if you did docker pull based)
mkdir -p ~/docker/MINTSWATmodel/mintswat
cd ~/docker/MINTSWATmodel/
curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/MINTSWATmodel.R > mintswat/MINTSWATmodel.R
curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/tb_s2.zip > mintswat/tb_s2.zip
curl https://raw.githubusercontent.com/vtdrfuka/MINTSWATmodel/main/Dockerfile > Dockerfile
cd mintswat/
unzip tb_s2.zip
cd ../
docker build -t mintswatmodel:latest .
docker run -dt -v ~/docker/MINTSWATmodel/mintswat/:/mintswat --name mint_swat mintswatmodel:latest

# Script-based Session
# Help without run
docker exec -it mint_swat Rscript MINTSWATmodel.R --help
# To run without parameter changes
docker exec -it mint_swat Rscript MINTSWATmodel.R 
# To run with parameter changes
docker exec -it mint_swat Rscript MINTSWATmodel.R -p GW_DELAY:12 -p CN2:75:00\*.mgt -s test1
# Kill and Cleanup
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
