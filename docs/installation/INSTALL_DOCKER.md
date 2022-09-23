Table of Contents
=================
<!--ts-->
* [Before you begin](#before-you-begin)
* [Why containers?](#why-containers)
* [Prerequisites](#prerequisites)
* [Option A - Local deployment](#option-a---local-deployment)
   * [Install <a href="https://github.com/santisbon/guides/blob/main/setup/docker.md">Docker</a>](#install-docker)
   * [Set up the container](#set-up-the-container)
* [Option B - Cloud deployment](#option-b---cloud-deployment)
   * [Setup the cloud instance](#setup-the-cloud-instance)
   * [Set up the container](#set-up-the-container-1)
* [Usage](#usage)
   * [Startup](#startup)
   * [Text to Image](#text-to-image)
   * [Image to Image](#image-to-image)
   * [Web Interface](#web-interface)
   * [Notes](#notes)
<!--te-->

# Before you begin

- For end users: Install locally using the installation doc for your OS.
- For developers: For container-related development tasks or for enabling easy deployment to other environments (on-premises or cloud), follow these instructions.  
For general use, install locally to leverage your machine's GPU.

# Why containers?

They provide a flexible, reliable way to build and deploy applications. There are many ways to deploy an application on a container: On your laptop for local testing, on the cloud using either a self-managed VM or a managed container service, to name a few.  

There are also different ways to decouple storage and compute e.g. using Docker volumes, bind mounts, attached block storage, a shared file system, or mounting object storage onto the host as a directory and mounting it onto the Docker container. All of these have tradeoffs regarding ease of use, portability, performance, cost, features, and operational overhead such as backups. See [Processes](https://12factor.net/processes) under the Twelve-Factor App methodology for details on why running applications in such a stateless fashion is important.  

You'll take the first steps in decoupling compute and storage by storing the largest model files and all image outputs separately from the container image. Future enhancements can do this for other assets.  

# Prerequisites

1. Go to [Hugging Face](https://huggingface.co/CompVis/stable-diffusion-v-1-4-original), and click "Access repository" to Download the model file ```sd-v1-4.ckpt``` (~4 GB) to ```~/Downloads```. You'll need to create an account but it's quick and free.  
2. Also download the face restoration model.
```Shell
cd ~/Downloads
wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.3.pth
```

# Option A - Local deployment 
Developers on Apple silicon (M1/M2): You can't access your GPU cores from Docker containers and performance is reduced compared with running it directly on macOS but for development purposes it's fine.  

This example shows local deployment on a Mac with Apple silicon. If your system is different adjust your platform to ```amd64``` and use the appropriate requirements file.

## Install [Docker](https://github.com/santisbon/guides/blob/main/setup/docker.md)  
On the Docker Desktop app, go to Preferences, Resources, Advanced. Increase the CPUs and Memory to avoid this [Issue](https://github.com/invoke-ai/InvokeAI/issues/342). You may need to increase Swap and Disk image size too.  

## Set up the container
 
```Shell
DOCKER_IMAGE_TAG="santisbon/stable-diffusion"
PLATFORM="linux/arm64"
REPO="-b orig-gfpgan https://github.com/santisbon/stable-diffusion.git"
REQS_FILE="requirements-linux-arm64.txt"
CONDA_SUBDIR="osx-arm64"
```

Create a Docker volume for the downloaded model files.
```Shell
docker volume create my-vol
```

Copy the data files to the Docker volume using a lightweight Linux container. We'll need the models at run time. You just need to create the container with the mountpoint; no need to run this dummy container.
```Shell
cd ~/Downloads # or wherever you saved the files

docker create --platform $PLATFORM --name dummy --mount source=my-vol,target=/data alpine 

docker cp sd-v1-4.ckpt dummy:/data
docker cp GFPGANv1.3.pth dummy:/data
```

Get the repo and download the Miniconda installer (we'll need it at build time). Replace the URL with the version matching your container OS and the architecture it will run on.
```Shell
cd ~  && mkdir docker-build && cd docker-build
# TODO: Change permalinks to main branch once it's merged
wget $REPO/blob/6c54d94e06a9efbfdc502a862219aa5ceb01ba9e/docker-build/Dockerfile 
wget $REPO/blob/6c54d94e06a9efbfdc502a862219aa5ceb01ba9e/docker-build/entrypoint.sh && chmod +x entrypoint.sh
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O anaconda.sh && chmod +x anaconda.sh
```

Build the Docker image. Give it any tag ```-t``` that you want.  
Choose the Linux container's host platform: x86-64/Intel is ```amd64```. Apple silicon is ```arm64```. If deploying the container to the cloud to leverage powerful GPU instances you'll be on amd64 hardware but if you're just trying this out locally on Apple silicon choose arm64.  
The application uses libraries that need to match the host environment so use the appropriate requirements file.  
Tip: Check that your shell session has the env variables set above.  
```Shell
docker build -t $DOCKER_IMAGE_TAG \
--platform $PLATFORM \
--build-arg gsd=$REPO \
--build-arg rsd=$REQS_FILE \
--build-arg cs=$CONDA_SUBDIR \
.
```

Run a container using your built image.  
Tip: Make sure you've created and populated the Docker volume (above).
```Shell
docker run -it \
--rm \
--platform $PLATFORM \
--name invoke-ai \
--hostname invoke-ai \
--mount source=my-vol,target=/data \
$DOCKER_IMAGE_TAG
```
The output dir set to the Docker volume you created earlier. 

# Option B - Cloud deployment
 
We'll use a cloud environment to illustrate the process of deploying to a container on an **amd**64 machine that can use CUDA with an NVIDIA GPU.  

For flexibility on our choice of container registry and other aspects, we'll use a VM on the cloud to build the Docker image. For simplicity we'll store the model files and images in object storage that can be mounted on our container with the help of a utility without changes to the application code.  

This example uses [AWS](https://aws.amazon.com/) but the concepts should translate to other environments. You'll need an AWS account. Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured with AWS credentials with ```AdministratorAccess```. Then follow this guide.  

## Set up the cloud instance

We will use:  
- The Deep Learning AMI with Ubuntu. It includes NVIDIA CUDA, Docker, and NVIDIA-Docker.  
- A [GPU-based instance](https://docs.aws.amazon.com/dlami/latest/devguide/gpu.html) optimized for machine learning. Note that these have a cost so make sure you understand the pricing for [G4](https://aws.amazon.com/ec2/instance-types/g4/) and [G5](https://aws.amazon.com/ec2/instance-types/g5/) instances.
- S3 Standard for storage. Make sure you understand [S3 pricing](https://aws.amazon.com/s3/pricing/).
- The default subnet on the default VPC.
- SSM Parameter Store so we can retrieve configuration parameters while creating or updating the infrastructure.  
- SSH to connect to the instance with an RSA key that we'll create.

**On your laptop**
```Shell
REPO="https://github.com/santisbon/stable-diffusion"
REGION="us-east-1"
MY_KEY="awsec2.pem"
BUCKET="invoke-ai"
AMI="$(aws ec2 describe-images \
--region $REGION \
--owners amazon \
--filters 'Name=name,Values=Deep Learning AMI (Ubuntu 18.04) Version ??.?' \
          'Name=state,Values=available' \
--query 'reverse(sort_by(Images, &CreationDate))[0].ImageId' | tr -d  '"')"

mkdir -p ~/.ssh/
aws ec2 create-key-pair --region $REGION --key-name $MY_KEY --query 'KeyMaterial' | tr -d  '"' > ~/.ssh/$MY_KEY
chmod 400 ~/.ssh/$MY_KEY

aws ssm put-parameter --type "String" --data-type "aws:ec2:image" \
    --name "ai/ec2/deep-learning-ami" \
    --value $AMI 

aws ssm put-parameter --type "String" \
    --name "ai/ec2/instance-type-dev" \
    --value "g4dn.xlarge" 

aws ssm put-parameter --type "String" \
    --name "ai/ec2/instance-type-prod" \
    --value "g5.xlarge" 

aws ssm put-parameter --type "String" \
    --name "ai/ec2/key-name" \
    --value $MY_KEY 

cd ~  && mkdir docker-build && cd docker-build
# TODO: Change permalinks to main branch once it's merged
wget $REPO/blob/6c54d94e06a9efbfdc502a862219aa5ceb01ba9e/docker-build/aws-infra.yaml

aws cloudformation create-stack \
--stack-name ai \
--template-body file://./aws-infra.yaml  \
--parameters ParameterKey=AmiId,ParameterValue=ai/ec2/deep-learning-ami \
             ParameterKey=InstanceType,ParameterValue=ai/ec2/instance-type-dev \
             ParameterKey=KeyName,ParameterValue=ai/ec2/key-name \
             ParameterKey=BucketName,ParameterValue=$BUCKET \
             ParameterKey=SSHLocation,ParameterValue=0.0.0.0/0 \
--capabilities CAPABILITY_NAMED_IAM

cd ~/Downloads
aws s3 cp ./sd-v1-4.ckpt s3://$BUCKET/sd-v1-4.ckpt
aws s3 cp ./GFPGANv1.3.pth s3://$BUCKET/GFPGANv1.3.pth

INSTANCE_PUBLIC_DNS="$(aws cloudformation describe-stacks --stack-name ai --output json \
--query "Stacks[0].Outputs[?OutputKey=='HostPublicDnsName'].OutputValue | [0]" | tr -d '"')"

ssh -i ~/.ssh/$MY_KEY ubuntu@$INSTANCE_PUBLIC_DNS
```

## Set up the container

**On the cloud instance**
```Shell
REPO="https://github.com/santisbon/stable-diffusion"
DOCKER_IMAGE_TAG="santisbon/stable-diffusion"
PLATFORM="linux/amd64"
REQS_FILE="requirements-lin.txt"

# View contents of the dir mounted on the host (should match the S3 bucket).
ls /mnt/ai-data

cd ~  && mkdir docker-build && cd docker-build
# TODO: Change permalinks to main branch once it's merged
wget $REPO/blob/6c54d94e06a9efbfdc502a862219aa5ceb01ba9e/docker-build/Dockerfile 
wget $REPO/blob/6c54d94e06a9efbfdc502a862219aa5ceb01ba9e/docker-build/entrypoint.sh && chmod +x entrypoint.sh
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O anaconda.sh && chmod +x anaconda.sh

docker build -t $DOCKER_IMAGE_TAG \
--platform $PLATFORM \
--build-arg gsd=$REPO \
--build-arg rsd=$REQS_FILE \
.

# Mount: source is the host dir and target is the container dir
docker run -it \
--rm \
--platform $PLATFORM \
--name invoke-ai \
--hostname invoke-ai \
--mount type=bind,source=/mnt/ai-data,target=/data \
$DOCKER_IMAGE_TAG
```

**On the container**
```Shell
# View contents of the dir mounted on the container (should match the S3 bucket).
ls /data
python3 scripts/dream.py --full_precision -o /data
```

# Usage 
Time to have fun

## Startup

If you're **directly on macOS follow these startup instructions**.  
With the Conda environment activated (```conda activate ldm```) use the more accurate but VRAM-intensive full precision math because half-precision requires autocast and won't work.  
By default the images are saved in ```outputs/img-samples/```.
```Shell
python3 scripts/dream.py --full_precision  
```

You'll get the script's prompt. You can see available options or quit.
```Shell
dream> -h
dream> q
```

## Text to Image
For quick (but bad) image results test with 5 steps (default 50) and 1 sample image. This will let you know that everything is set up correctly.  
Then increase steps to 100 or more for good (but slower) results.  
The prompt can be in quotes or not.
```Shell
dream> The hulk fighting with sheldon cooper -s5 -n1 
dream> "woman closeup highly detailed"  -s 150
# Reuse previous seed and apply face restoration
dream> "woman closeup highly detailed"  --steps 150 --seed -1 -G 0.75 
```

You'll need to experiment to see if face restoration is making it better or worse for your specific prompt.

If you're on a container the output is set to the Docker volume. You can copy it wherever you want.  
You can download it from the Docker Desktop app, Volumes, my-vol, data.  
Or you can copy it from your Mac terminal. Keep in mind ```docker cp``` can't expand ```*.png``` so you'll need to specify the image file name.  

On your host Mac (you can use the name of any container that mounted the volume):
```Shell
docker cp dummy:/data/000001.928403745.png /Users/<your-user>/Pictures 
```

## Image to Image
You can also do text-guided image-to-image translation. For example, turning a sketch into a detailed drawing.  

```strength``` is a value between 0.0 and 1.0 that controls the amount of noise that is added to the input image. Values that approach 1.0 allow for lots of variations but will also produce images that are not semantically consistent with the input. 0.0 preserves image exactly, 1.0 replaces it completely.  

Make sure your input image size dimensions are multiples of 64 e.g. 512x512. Otherwise you'll get ```Error: product of dimension sizes > 2**31'```. If you still get the error [try a different size](https://support.apple.com/guide/preview/resize-rotate-or-flip-an-image-prvw2015/mac#:~:text=image's%20file%20size-,In%20the%20Preview%20app%20on%20your%20Mac%2C%20open%20the%20file,is%20shown%20at%20the%20bottom.) like 512x256.  

If you're on a Docker container, copy your input image into the Docker volume
```Shell
docker cp /Users/<your-user>/Pictures/sketch-mountains-input.jpg dummy:/data/
```

Try it out generating an image (or more). The ```dream``` script needs absolute paths to find the image so don't use ```~```.  

If you're on your Mac
```Shell 
dream> "A fantasy landscape, trending on artstation" -I /Users/<your-user>/Pictures/sketch-mountains-input.jpg --strength 0.75  --steps 100 -n4
```
If you're on a Linux container on your Mac
```Shell
dream> "A fantasy landscape, trending on artstation" -I /data/sketch-mountains-input.jpg --strength 0.75  --steps 50 -n1
```

## Web Interface
You can use the ```dream``` script with a graphical web interface. Start the web server with:
```Shell
python3 scripts/dream.py --full_precision --web
```
If it's running on your Mac point your Mac web browser to http://127.0.0.1:9090  

Press Control-C at the command line to stop the web server.

## Notes

Some text you can add at the end of the prompt to make it very pretty:
```Shell
Hyper Detail, Octane Rendering, Unreal Engine, V-Ray, cinematic photo, highly detailed, cinematic lighting, ultra-detailed, ultrarealistic, photorealism, cyberpunk lights, 8K, HD, full hd, cyberpunk, abstract, 3d octane render + 4k UHD + immense detail + dramatic lighting + well lit + black, purple, blue, pink, cerulean, teal, metallic colours, + fine details, ultra photoreal, photographic, concept art, cinematic composition, rule of thirds, mysterious, eerie, photorealism, breathtaking detailed, painting art deco pattern, by hsiao, ron cheng, john james audubon, bizarre compositions, exquisite detail, extremely moody lighting, painted by greg rutkowski makoto shinkai takashi takeuchi studio ghibli, akihiko yoshida
```

The original scripts should work as well.
```Shell
python3 scripts/orig_scripts/txt2img.py --help
python3 scripts/orig_scripts/txt2img.py --ddim_steps 5 --n_iter 1 --n_samples 1  --plms --prompt "ocean" # or --klms
```
