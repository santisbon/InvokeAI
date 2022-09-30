Table of Contents
=================
<!--ts-->
* [Before you begin](#before-you-begin)
* [Why containers?](#why-containers)
* [Prerequisites](#prerequisites)
* [Local deplyment](#local-deplyment)
* [Cloud deployment](#cloud-deployment)
* [Usage](#usage)
   * [Startup](#startup)
   * [Text to Image](#text-to-image)
   * [Image to Image](#image-to-image)
   * [Notes](#notes)
<!--te-->

# Before you begin

- End users: Install locally (no containers) using the installation doc for your OS.
- Developers: 
    - For general use on a Mac M1/M2 install locally (no containers) to leverage your GPU cores. 
    - For enabling easy deployment to other environments (on-premises or cloud), follow these instructions to install on Docker containers.  

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

# Local deplyment
See [Docker local deployment](/docs/installation/docker/local.md).

# Cloud deployment
See [Docker cloud deployment](/docs/installation/docker/cloud.md).

# Usage 

## Startup

With the Conda environment activated (```conda activate ldm```) use the more accurate but VRAM-intensive full precision math.  
By default the images are saved in ```outputs/img-samples/```. Set the output dir to the mount point: 
```Shell
python3 scripts/dream.py --full_precision -o /data/outputs/img-samples/
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

## Image to Image
You can also do text-guided image-to-image translation. For example, turning a sketch into a detailed drawing.  

```strength``` is a value between 0.0 and 1.0 that controls the amount of noise that is added to the input image. Values that approach 1.0 allow for lots of variations but will also produce images that are not semantically consistent with the input. 0.0 preserves image exactly, 1.0 replaces it completely.  

Make sure your input image size dimensions are multiples of 64 e.g. 512x512. Otherwise you'll get ```Error: product of dimension sizes > 2**31'```. If you still get the error [try a different size](https://support.apple.com/guide/preview/resize-rotate-or-flip-an-image-prvw2015/mac#:~:text=image's%20file%20size-,In%20the%20Preview%20app%20on%20your%20Mac%2C%20open%20the%20file,is%20shown%20at%20the%20bottom.) like 512x256.  

Try it out generating an image (or more).  
```Shell
dream> "A fantasy landscape, trending on artstation" -I /data/sketch-mountains-input.jpg --strength 0.75  --steps 50 -n1
```

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
