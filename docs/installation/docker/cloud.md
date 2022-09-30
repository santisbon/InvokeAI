Table of Contents
=================
<!--ts-->
* [Deployment](#deployment)
* [Populate EFS with the model files](#populate-efs-with-the-model-files)
* [Cleanup](#cleanup)
* [Notes](#notes)
<!--te-->
 
We'll use a cloud environment to illustrate the process of deploying to a container on an **amd**64 machine that can use CUDA with an NVIDIA GPU.   

This example uses [AWS](https://aws.amazon.com/) so you'll need an AWS account. Note that cloud resources like instances and file systems have a cost so **make sure you understand AWS pricing** before launching this cloud environment. For example, a [G4](https://aws.amazon.com/ec2/instance-types/g4/) ```g4dn.xlarge``` instance with 1 GPU, 4vCPUs, 16 GiB memory, and 16 GiB GPU memory at the time of this writing has a cost of $0.526 /hr on-demand.

Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured with AWS credentials with ```AdministratorAccess```. Then follow this guide.  

# Deployment

You can use native Docker commands to run apps on [Amazon Elastic Container Service (ECS)](https://aws.amazon.com/ecs/). Docker ECS integration converts the Compose application model into a set of AWS resources, described as a CloudFormation template. By default:
- The Compose application becomes an ECS cluster.
- Services using a GPU (```DeviceRequest```) get the Cluster extended with an EC2 ```CapacityProvider``` using an ```AutoscalingGroup``` based on a ```LaunchConfiguration```. Keep in mind this limits your ability to use [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html#ecs-exec-considerations). The launch configuration uses an ECS recommended AMI and machine type for GPU.
- Service discovery is done through AWS Cloud Map. 
- Service isolation is implemented by EC2 Security Groups (one per network) on your default VPC. All the resources are deployed to the Default VPC. In a real life scenario, you can deploy to your own VPC and subnets using the x-aws-vpc extension.
- If you expose ports, a LoadBalancer routes traffic to your services.
- Volumes are based on [Amazon EFS](https://aws.amazon.com/efs/).  

```Shell
# TODO: Download only the docker-build files needed 
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O anaconda.sh && chmod +x anaconda.sh

# To deploy to ECS your image must be stored in a registry like Docker Hub or ECR

# Build the image 
docker compose -f docker-compose-cloud.yml build
# View the image built
docker images
# Push it to Docker Hub
docker login # docker logout registry-1.docker.io
docker compose push

# Create the ECS context
docker context create ecs myecscontext
docker context use myecscontext

REGION="us-east-1"
MY_KEY="invokeaiec2"
# In case you want to limit SSH access to your IP in the docker-compose-cloud.yml file
# MY_IP="$(curl https://checkip.amazonaws.com)"

# Create SSH key 
mkdir -p ~/.ssh/
aws ec2 create-key-pair --region $REGION --key-name $MY_KEY --query 'KeyMaterial' --output text > ~/.ssh/$MY_KEY".pem"
chmod 400 ~/.ssh/$MY_KEY".pem"

# Verify public and private keys are there
aws ec2 describe-key-pairs
ls -al ~/.ssh/$MY_KEY".pem"

# Create and start containers
docker compose -p invoke-ai-project -f docker-compose-cloud.yml up
```

Ignore the ```unsupported attribute``` warnings. After about 9 minutes you should see something like this:
```Shell
+] Running 21/21
 ⠿ invoke-ai-project                           CreateComplete    494.1s
 ⠿ InvokeaiTaskExecutionRole                   CreateComplete     21.0s
 ⠿ EC2InstanceRole                             CreateComplete     20.0s
 ⠿ InvokeaidataAccessPoint                     CreateComplete      8.0s
 ⠿ DefaultNetwork                              CreateComplete      9.0s
 ⠿ LogGroup                                    CreateComplete      3.2s
 ⠿ CloudMap                                    CreateComplete     51.2s
 ⠿ InvokeaiTaskRole                            CreateComplete     22.0s
 ⠿ InvokeaidataNFSMountTargetOnSubnet621e2558  CreateComplete     86.0s
 ⠿ InvokeaidataNFSMountTargetOnSubnet82b327a9  CreateComplete     82.0s
 ⠿ InvokeaidataNFSMountTargetOnSubnet6ce68435  CreateComplete     81.0s
 ⠿ DefaultNetworkIngress                       CreateComplete      1.0s
 ⠿ InvokeaidataNFSMountTargetOnSubnet7a266f0d  CreateComplete     82.0s
 ⠿ EC2InstanceProfile                          CreateComplete    134.1s
 ⠿ InvokeaiTaskDefinition                      CreateComplete      2.9s
 ⠿ InvokeaiServiceDiscoveryEntry               CreateComplete      1.9s
 ⠿ LaunchConfiguration                         CreateComplete      3.0s
 ⠿ AutoscalingGroup                            CreateComplete     34.0s
 ⠿ CapacityProvider                            CreateComplete      3.0s
 ⠿ Cluster                                     CreateComplete     10.0s
 ⠿ InvokeaiService                             CreateComplete    268.0s
```

SSH into the Docker host instance
```Shell
INSTANCE_PUBLIC_DNS="$(aws ec2 describe-instances \
--filters Name=key-name,Values=$MY_KEY \
--query 'Reservations[].Instances[].PublicDnsName' \
--output text)"

ssh -i ~/.ssh/$MY_KEY".pem" ec2-user@$INSTANCE_PUBLIC_DNS
docker ps
```

Now populate EFS with the model files. You only need to do that once.  

# Populate EFS with the model files
Copy files to the volume (EFS) via the host instance. You need to do this only once.  

**On your local machine**
```Shell
BUCKET="invoke-ai"

aws cloudformation create-stack \
--stack-name invoke-ai-uploads \
--template-body file://docker-build/aws-uploads-infra.yml  \
--parameters ParameterKey=BucketName,ParameterValue=$BUCKET 

# Copy files to S3 bucket
aws s3 cp ~/Downloads/GFPGANv1.3.pth s3://$BUCKET/GFPGANv1.3.pth
aws s3 cp ~/Downloads/sd-v1-4.ckpt s3://$BUCKET/sd-v1-4.ckpt

# Connect to host instance  
ssh -i ~/.ssh/$MY_KEY".pem" ec2-user@$INSTANCE_PUBLIC_DNS

sudo yum install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**On the Docker host instance**
```Shell
BUCKET="invoke-ai"
# Copy files from S3 into the Docker volume (EFS).

# S3FullAccess only for the purposes of this exercise. Do not do this in production
INSTANCE_ROLE=invoke-ai-project-EC2InstanceRole-1KWMORSDQIC72 # change to the name in your AWS environment
aws iam attach-role-policy --role-name $INSTANCE_ROLE --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam list-attached-role-policies --role-name $INSTANCE_ROLE

aws s3 sync s3://$BUCKET . 
# docker ps to get the container id e.g. 0aabb52fdc37
docker cp ~/GFPGANv1.3.pth <container-id>:/data
docker cp ~/sd-v1-4.ckpt <container-id>:/data
rm -rf ~/GFPGANv1.3.pth ~/sd-v1-4.ckpt
aws s3 rm s3://$BUCKET --recursive
aws cloudformation delete-stack --stack-name invoke-ai-uploads
aws iam detach-role-policy --role-name $INSTANCE_ROLE --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Verify from the container
docker exec -it <container-id> bash
```

**On the container**
```Shell
ls /data
conda activate ldm
python3 scripts/dream.py --full_precision -o /data/outputs/img-samples/
# Quick test
dream> your prompt goes here -s5 -n1  # RuntimeError: expected scalar type BFloat16 but found Float
dream> q
```

# Cleanup
```Shell
# Stop and remove containers, networks
docker compose -p invoke-ai-project down
# The EFS file system is configured to persist after tearing down the infrastructure so you won't lose your data.
```

# Notes

Validate your compose file with ```docker-compose config``` (not to be confused with ```docker compose config```).  
```Shell
# Validate
docker-compose -f docker-compose-cloud.yml config 
```

Each context contains all of the endpoint and security information required to manage a different cluster or node.  
You can list the current contexts e.g. Docker Engine (default) and Docker Desktop (desktop-linux).  
```Shell
docker context ls
```

If your app uses an AWS SDK it retrieves temporary AWS API credentials at runtime from a metadata service. This makes local testing difficult so there's an option to create a local simulation ECS context. This allows the AWS SDK used by your app code to access a local mock container as "AWS metadata API" and retrieve credentials from you own local ```.aws/credentials``` config file. Under this context Compose doesn't deploy your app on ECS so you must run it locally.
```Shell
docker context create ecs --local-simulation ecsLocal
```

You can use ```convert``` to generate a CloudFormation stack file from your Compose file to inspect resources or customize the template. You can define a compose file *overlay* .yml file with only the attributes to be updated or added. It will be merged with the generated template before being applied to the AWS infrastructure. Make sure you're using the ECS context.
```Shell
docker compose -f docker-compose-cloud.yml convert > cfn-output.yml
```

You can copy files from an S3 bucket to your local machine.
```Shell
cd ~/Pictures
aws s3 cp s3://$BUCKET/000001.928403745.png 000001.928403745.png
```

For image-to-image translation you can temporarily copy input images to the S3 bucket to populate the EFS filssystem just like you did with the model files.
```Shell
aws s3 cp ~/Pictures/sketch-mountains-input.jpg s3://$BUCKET/sketch-mountains-input.jpg
```
