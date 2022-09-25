FROM        debian 

ARG         gsd
ENV         REPO $gsd

ARG         rsd
ENV         REQS $rsd

ARG         cs
ENV         CONDA_SUBDIR $cs

ENV         PIP_EXISTS_ACTION="w"

# TODO: Optimize image size

SHELL       ["/bin/bash", "-c"]

WORKDIR     /
RUN         apt update && apt upgrade -y \
            && apt install -y \
            git \
            libgl1-mesa-glx \
            libglib2.0-0 \
            pip \
            python3 \
            && git clone $REPO

# Install Anaconda or Miniconda
COPY        anaconda.sh .
RUN         bash anaconda.sh -b -u -p /anaconda && /anaconda/bin/conda init bash

# SD 
WORKDIR     /stable-diffusion 
RUN         source ~/.bashrc \
            && [ -z "$CONDA_SUBDIR" ] && unset CONDA_SUBDIR \
            && conda create -y --name ldm && conda activate ldm \
            && [ -z "$CONDA_SUBDIR" ] && echo "CONDA_SUBDIR Empty or unset" || conda config --env --set subdir $CONDA_SUBDIR \
            && pip3 install -r $REQS \   
            && pip3 install basicsr facexlib realesrgan \          
            && mkdir models/ldm/stable-diffusion-v1 \
            && mkdir -p src/gfpgan/experiments/pretrained_models
            && ln -s "/data/sd-v1-4.ckpt" models/ldm/stable-diffusion-v1/model.ckpt 
            && ln -s "/data/GFPGANv1.3.pth" experiments/pretrained_models/GFPGANv1.3.pth
            && python3 scripts/preload_models.py 

CMD         ["python3", "/stable-diffusion/scripts/dream.py", "--full_precision", "/data/outputs/img-samples/"]
