Table of Contents
=================
<!--ts-->
<!--te-->

# Containers in the cloud
 
We'll use a cloud environment to illustrate the process of deploying to a container on an **amd**64 machine that can use CUDA with an NVIDIA GPU.  

For flexibility on our choice of container registry and other aspects, we'll use a VM on the cloud to build the Docker image. For simplicity we'll store the model files and images in object storage that can be mounted on our container with the help of a utility without changes to the application code.  

This example uses [AWS](https://aws.amazon.com/) but the concepts should translate to other environments. You'll need an AWS account. Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured with AWS credentials with ```AdministratorAccess```. Then follow this guide.  

# Using native Docker commands to run apps in Amazon ECS

Docker ECS integration converts the Compose application model into a set of AWS resources, described as a CloudFormation template. By default:
- The Compose application becomes an ECS cluster.
- Services using a GPU (```DeviceRequest```) get the Cluster extended with an EC2 ```CapacityProvider``` using an ```AutoscalingGroup``` based on a ```LaunchConfiguration```. The latter uses an ECS recommended AMI and machine type for GPU.
- Service discovery is done through AWS Cloud Map. 
- Service isolation is implemented by EC2 Security Groups (one per network) on your default VPC. 
- If you expose ports, a LoadBalancer routes traffic to your services.
- Volumes are based on Amazon EFS.

```Shell
# TODO: Download only the dockerbuild files needed 
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O anaconda.sh && chmod +x anaconda.sh
```

Validate your compose file with ```docker-compose config``` (not to be confused with ```docker compose config```).  
To deploy to ECS your image must be stored in a public registry like Docker Hub.
```Shell
docker-compose -f docker-compose-cloud.yml config # validate
docker compose -f docker-compose-cloud.yml build
docker login
docker compose push
```

You can use ```convert``` to generate a CloudFormation stack file from your Compose file to inspect resources or customize the template. You can define an *overlay* .yml file with only the attributes to be updated or added. It will be merged with the generated template before being applied to the AWS infrastructure. Then apply the template to AWS using the AWS CLI specifying your template files.  
```Shell
docker compose -f docker-compose-cloud.yml convert > cfn-output.yml
```

Note that cloud resources like instances and file systems have a cost so **make sure you understand AWS pricing** before launching this environment on the cloud.

You can see the current contexts e.g. Docker Engine (default) and Docker Desktop (desktop-linux)
```Shell
docker context ls
```
If your app uses an AWS SDK it retrieves temporary AWS API credentials at runtime from a metadata service. This makes local testing difficult so there's an option to create a local simulation ecs context. This allows the AWS SDK used by your app code to access a local mock container as "AWS metadata API" and retrieve credentials from you own local ```.aws/credentials``` config file. Under this context Compose doesn't deploy your app on ECS so you must run it locally.
```Shell
docker context create ecs --local-simulation ecsLocal
```

```Shell
# Create an ECS Docker context
docker context create ecs myecscontext
docker context use myecscontext

docker compose -p invoke-ai-project -f docker-compose-cloud.yml create

#TODO: Copy files to the volume (EFS)

# Start services
docker compose -p invoke-ai-project -f docker-compose-cloud.yml start
# Connect to the running container:
docker exec -it invoke-ai bash
# Stop services
docker compose -p invoke-ai-project -f docker-compose-cloud.yml stop
# Stop and remove containers, networks
docker compose -p invoke-ai-project -f docker-compose-cloud.yml down

```

# Troubleshooting

- The container on the cloud instance can't find the model files.
Make sure you followed the steps to mount the S3 bucket on the Docker host as a directory. Verify with:  
**On the cloud instance**
```Shell
# View contents of the dir mounted on the host (should match the S3 bucket).
ls /mnt/ai-data
```
**On the container**
```Shell
# View contents of the dir mounted on the container (should match the S3 bucket).
ls /data
```