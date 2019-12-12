# Sample Service Automation using WordPress micro-containers

This library highlights one strategy to operationalize and automate services within AWS using tags and the AWS PowerShell tools.  The tagging strategy builds upon the  service management library (https://github.com/wjamesbonner/aws-service-management) which expects AWS resources to be tagged with one or both of the service-id and service-name tags as a means of identifying what resources support what service.  In addition, this library adds the tag management-mode with supported values of automatic and manual.

# In progress - expected completion end of December 2019
Currently we have a mix of manual and automated tasks that I am stitching together into a cohesive management library.  Specifically, I am adding in significant validation checks and logging, with the intent that after initial service initialization the deployment of new service instances can be managed by T1 staff, and issues can be easily troubleshooted by T2 and T3 staff from the extensive logs generated.

The library consists of three main management functions.

 1. service-initialization.ps1 (in progress)
The first service-initialization portion of the library prepares the AWS account for the service by creating and configuring the VPC< subnets, route tables, security groups, and load balancer.  The second portion builds the Elastic Container Repository, publishes the latest WordPress container image, builds a linux EC2 instance for NFS volume management (running chmod against EFS volumes), and builds an initial ECS cluster.
 
 2. service-deployment.ps1
The service-deployment script deploys a new instance of the service, and returns the details of the DNS records to be created for service consumption.  The script takes as an input the desired parent domain, e.g., cahnrs.wsu.edu, and builds as needed additional ELB's, listeners, listener rules, target groups, and ECS nodes and clusters.  The script tests existing ECS clusters for spare capacity, and then builds out new clusters if existing clusters don't have available space.
 
 3. service-deprovisioning.ps1
 This script removes all resources that with matching service-family tags and with a mangement mode of automatic.
