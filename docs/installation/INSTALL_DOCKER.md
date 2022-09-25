Table of Contents
=================
<!--ts-->
<!--te-->

# Before you begin

- End users: Install locally (no containers) using the installation doc for your OS.
- Developers: For general use on a Mac M1/M2 install locally (no containers) to leverage your GPU cores. For enabling easy deployment to other environments (on-premises or cloud), follow these instructions.  

# Why containers?

They provide a flexible, reliable way to build and deploy applications. There are many ways to deploy an application on a container: On your laptop for local testing, on the cloud using either a self-managed VM or a managed container service, to name a few.  

There are also different ways to decouple storage and compute e.g. using Docker volumes, bind mounts, attached block storage, a shared file system, or mounting object storage onto the Docker container as a directory. All of these have trade-offs regarding ease of use, portability, performance, cost, features, and operational overhead such as backups. See [Processes](https://12factor.net/processes) under the Twelve-Factor App methodology for details on why running applications in such a stateless fashion is important.  

You'll take the first steps in decoupling compute and storage by storing the largest model files and all image outputs separately from the container image. Future enhancements can do this for other assets.  

# Prerequisites

1. Go to [Hugging Face](https://huggingface.co/CompVis/stable-diffusion-v-1-4-original), and click "Access repository" to Download the model file ```sd-v1-4.ckpt``` (~4 GB) to ```~/Downloads```. You'll need to create an account but it's quick and free.  
2. Also download the face restoration model.
```Shell
cd ~/Downloads
wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.3.pth
```

# Deploy to Docker on local machine 
 
This example shows a local deployment on a Mac with Apple silicon. Due to a change in how GFPGAN is installed, this Apple silicon scenario uses (for now) a branch on this fork from before that refactoring took place. 

**Other local scenarios have not been tested** but may work with the appropriate configuration changes in ```docker-compose.yml```, ```Dockerfile``` and in these instructions.  
- The platform - ```amd64``` (x86-64/Intel) or ```arm64``` (aarch64/ARM/Apple chip) depending on your architecture.
- The ```CONDA_SUBDIR``` variable - ```osx-64``` or ```osx-arm64``` for macOS; empty for a Linux amd64 host.
- Use the requirements file and Miniconda installer that match your OS/architecture.

## Install [Docker](https://github.com/santisbon/guides/blob/main/setup/docker.md)  
On the Docker Desktop app, go to Preferences, Resources, Advanced. Increase the CPUs and Memory to avoid this [Issue](https://github.com/invoke-ai/InvokeAI/issues/342). You may need to increase Swap and Disk image size too.  

## Set up the container

```Shell
REPO="https://github.com/santisbon/stable-diffusion.git"
REPO_BRANCH="orig-gfpgan"
REPO_PATH="$(echo $REPO | sed 's/\.git//' | sed 's/github/raw\.githubusercontent/')"

cd ~  && mkdir -p docker-build && cd docker-build
wget $REPO_PATH/$REPO_BRANCH/docker-build/docker-compose.yml
wget $REPO_PATH/$REPO_BRANCH/docker-build/Dockerfile
wget $REPO_PATH/$REPO_BRANCH/docker-build/entrypoint.sh && chmod +x entrypoint.sh
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O anaconda.sh && chmod +x anaconda.sh

docker compose -p invoke-ai-project create

docker cp ~/Downloads/sd-v1-4.ckpt invoke-ai:/data
docker cp ~/Downloads/GFPGANv1.3.pth invoke-ai:/data

docker compose start
```

# Usage 
Time to have fun

## Startup

With the Conda environment activated (```conda activate ldm```) use the more accurate but VRAM-intensive full precision math.  
By default the images are saved in ```outputs/img-samples/```. Set the output dir to the mount point you created: 
```Shell
python3 scripts/dream.py --full_precision -o /data
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

The output is set to the mount point. You can copy it wherever you want.  

If you're on a local installation using a Docker volume you can download the images from the Docker Desktop app. Or you can copy it from your terminal. Keep in mind ```docker cp``` can't expand ```*.png``` so you'll need to specify the image file name.  

**On your laptop (you can use the name of any container that mounted the volume)**:
```Shell
docker cp dummy:/data/000001.928403745.png /Users/<your-user>/Pictures 
```

If you're on a cloud instance using S3 as storage you can copy the files from the bucket to your laptop.
**On your laptop**
```Shell
cd ~/Pictures
aws s3 cp s3://$BUCKET/000001.928403745.png 000001.928403745.png
```

## Image to Image
You can also do text-guided image-to-image translation. For example, turning a sketch into a detailed drawing.  

```strength``` is a value between 0.0 and 1.0 that controls the amount of noise that is added to the input image. Values that approach 1.0 allow for lots of variations but will also produce images that are not semantically consistent with the input. 0.0 preserves image exactly, 1.0 replaces it completely.  

Make sure your input image size dimensions are multiples of 64 e.g. 512x512. Otherwise you'll get ```Error: product of dimension sizes > 2**31'```. If you still get the error [try a different size](https://support.apple.com/guide/preview/resize-rotate-or-flip-an-image-prvw2015/mac#:~:text=image's%20file%20size-,In%20the%20Preview%20app%20on%20your%20Mac%2C%20open%20the%20file,is%20shown%20at%20the%20bottom.) like 512x256.  

Depending on your storage solution, copy your input image into the Docker volume (local deployment) or S3 bucket (cloud deployment).
On your laptop
```Shell
docker cp /Users/<your-user>/Pictures/sketch-mountains-input.jpg dummy:/data/
# or
aws s3 cp ~/Pictures/sketch-mountains-input.jpg s3://$BUCKET/sketch-mountains-input.jpg
```

Try it out generating an image (or more).  
```Shell
dream> "A fantasy landscape, trending on artstation" -I /data/sketch-mountains-input.jpg --strength 0.75  --steps 50 -n1
```

## Web Interface
Only for local installations running directly on your laptop (not containers).  
You can use the ```dream``` script with a graphical web interface. Start the web server with:
```Shell
python3 scripts/dream.py --full_precision --web
```
Point your web browser to http://127.0.0.1:9090  

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
