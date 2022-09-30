Table of Contents
=================
<!--ts-->
* [Install <a href="https://github.com/santisbon/guides/blob/main/setup/docker.md">Docker</a>](#install-docker)
* [Setup](#setup)
* [Notes](#notes)
<!--te-->
 
This example shows a local Docker deployment on a Mac with Apple silicon. Due to a change in how GFPGAN is installed, this Apple silicon scenario uses (for now) a branch on this fork from before that refactoring took place. 

**Other local Docker scenarios have not been tested** but may work with the appropriate configuration changes in ```docker-compose.yml```, ```Dockerfile``` and in these instructions.  
- The platform - ```amd64``` (x86-64/Intel) or ```arm64``` (aarch64/ARM/Apple chip) depending on your architecture.
- The ```CONDA_SUBDIR``` variable - ```osx-64``` or ```osx-arm64``` for macOS; empty for a Linux amd64 host.
- Use the requirements file and Miniconda installer that match your OS/architecture.

# Install [Docker](https://github.com/santisbon/guides/blob/main/setup/docker.md)  
On the Docker Desktop app, go to Preferences, Resources, Advanced. Increase the CPUs and Memory to avoid this [Issue](https://github.com/invoke-ai/InvokeAI/issues/342). You may need to increase Swap and Disk image size too.  

# Setup

```Shell
REPO="https://github.com/santisbon/stable-diffusion.git"
REPO_BRANCH="orig-gfpgan"
REPO_PATH="$(echo $REPO | sed 's/\.git//' | sed 's/github/raw\.githubusercontent/')"

cd ~  && mkdir -p docker-build && cd docker-build
wget $REPO_PATH/$REPO_BRANCH/docker-build/docker-compose.yml
wget $REPO_PATH/$REPO_BRANCH/docker-build/Dockerfile
wget $REPO_PATH/$REPO_BRANCH/docker-build/entrypoint.sh && chmod +x entrypoint.sh
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O anaconda.sh && chmod +x anaconda.sh

# Creates containers for a service
docker compose -p invoke-ai-project create

# Copy files to the volume
docker cp ~/Downloads/sd-v1-4.ckpt invoke-ai:/data
docker cp ~/Downloads/GFPGANv1.3.pth invoke-ai:/data

# Start services
docker compose -p invoke-ai-project start
# Connect to the running container:
docker exec -it invoke-ai bash
# Stop services
docker compose -p invoke-ai-project stop
# Or stop and remove containers, networks
docker compose -p invoke-ai-project down
```

# Notes
The output is set to the mount point to decouple storage and compute. You can copy it wherever you want.  

You can download the images from the Docker Desktop app or you can copy them from your terminal. Keep in mind ```docker cp``` can't expand ```*.png``` so you'll need to specify the image file name.  

**On your laptop (you can use the name of any container that mounted the volume)**:
```Shell
docker cp <container-name>:/data/000001.928403745.png /Users/<your-user>/Pictures 
```

For image-to-image translation copy your input image into the Docker volume
```Shell
docker cp /Users/<your-user>/Pictures/sketch-mountains-input.jpg <container-name>:/data/
```
