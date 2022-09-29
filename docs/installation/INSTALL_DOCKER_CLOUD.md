Table of Contents
=================
<!--ts-->
<!--te-->
 
We'll use a cloud environment to illustrate the process of deploying to a container on an **amd**64 machine that can use CUDA with an NVIDIA GPU.   

This example uses [AWS](https://aws.amazon.com/) but the concepts should translate to other environments. You'll need an AWS account. Note that cloud resources like instances and file systems have a cost so **make sure you understand AWS pricing** before launching this cloud environment. For example, a [G4](https://aws.amazon.com/ec2/instance-types/g4/) ```g4dn.xlarge``` instance with 1 GPU, 4vCPUs, 16 GiB memory, and 16 GiB GPU memory at the time of this writing has a cost of $0.526 /hr on-demand.

Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured with AWS credentials with ```AdministratorAccess```. Then follow this guide.  

# Deployment to Amazon ECS

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

# To deploy to ECS your image must be stored in a registry like Docker Hub

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
# MY_IP="$(curl https://checkip.amazonaws.com)"

# Create SSH key 
mkdir -p ~/.ssh/

aws ec2 create-key-pair --region $REGION --key-name $MY_KEY --query 'KeyMaterial' --output text > ~/.ssh/$MY_KEY".pem"
chmod 400 ~/.ssh/$MY_KEY".pem"

# verify public and private keys are there
aws ec2 describe-key-pairs
ls -al ~/.ssh/$MY_KEY".pem"

# Create and start containers
docker compose -p invoke-ai-project -f docker-compose-cloud.yml up
# For some reason the cluster doesn't have any registered container instances.
# https://aws.amazon.com/premiumsupport/knowledge-center/ecs-instance-unable-join-cluster/
# ---------
# It seems like the container instance doesn't have communication with ECS service endpoint. Container instances need access to communicate with the Amazon ECS service endpoint. This can be through an interface VPC endpoint or through your container instances having public IP addresses. For more information about interface VPC endpoints, see https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html
# If you do not have an interface VPC endpoint configured and your container instances do not have public IP addresses, then they must use network address translation (NAT) to provide this access. For more information, see NAT gateways in the Amazon VPC User Guide (https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) and HTTP proxy configuration in this guide https://docs.aws.amazon.com/AmazonECS/latest/developerguide/http_proxy_config.html. For more information, see https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-public-private-vpc.html
# ---------
# Turns out the IGW was associated but dettached from the VPC.

ssh -i ~/.ssh/$MY_KEY".pem" ec2-user@<dns name of your instance>
```

Go populate EFS with the model files.  

```Shell
# View the list of relevant services that were created on AWS
docker compose ps
# Stream the logs from AWS ECS Service.
docker compose logs
# Stop and remove containers, networks
docker compose -p invoke-ai-project -f docker-compose-cloud.yml down
```

# Populate EFS with the model files
```Shell
# TODO: Copy files to the volume (EFS). Only needed once.
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
