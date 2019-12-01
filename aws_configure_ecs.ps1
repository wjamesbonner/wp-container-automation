param(
    [Alias("s")]
    [string] $serviceFamily = "wp-containers",

    [Alias("t")]
    [string] $tagName = "service-family",

    [Alias("e")]
    [string] $ecrUri = "548069994063.dkr.ecr.us-west-2.amazonaws.com/production/wordpress",

    [Alias("i")]
    [string] $imgUri = "",#"548069994063.dkr.ecr.us-west-2.amazonaws.com/production/wordpress@sha256:76fb6367fcd31cfac39d544d56ca14357facf54c9a980ac422fed26586157e08",

    [Alias("h")]
    [switch] $help = $false
)

if ($help) {
	Write-Host "aws_configure_ecs.ps1 will configure an existing ECS cluster tagged as part of the service family to run a new instance of the service, or create a new cluster if none exist already"
	Write-Host "Prerequisites: Powershell"
	Write-Host ""
	Write-Host "Parameters:"
	Write-Host ""
	Write-Host "serviceFamily"
	Write-Host "    The name of the service family."
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_configure_ecs.ps1 -serviceFamily wp-containers"
    Write-Host "    Example: ./aws_configure_ecs.ps1 -s wp-containers"
	
    Write-Host ""
	Write-Host "tagName"
	Write-Host "    The name of the tag that stores the service family name"
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_configure_ecs.ps1 -tagName service-family"
    Write-Host "    Example: ./aws_configure_ecs.ps1 -t service-family"

    Write-Host ""
	Write-Host "ecrUri"
	Write-Host "    The path to the ECR repository.  Will create a task definition that points to the SHA256 URI of the latest image"
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_configure_ecs.ps1 -ecrUri 123456789.dkr.ecr.us-west-2.amazonaws.com/production/wordpress"
    Write-Host "    Example: ./aws_configure_ecs.ps1 -e 123456789.dkr.ecr.us-west-2.amazonaws.com/production/wordpress"
	
    Write-Host ""
	Write-Host "imgUri"
	Write-Host "    [Optional] The URI of the image to deploy; supersedes ecrUri."
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_configure_ecs.ps1 -imgUri 123456789.dkr.ecr.us-west-2.amazonaws.com/production/wordpress@sha256:50D858E0985ECC7F60418AAF0CC5AB587F42C2570A884095A9E8CCACD0F6545C"
    Write-Host "    Example: ./aws_configure_ecs.ps1 -i 123456789.dkr.ecr.us-west-2.amazonaws.com/production/wordpress@sha256:50D858E0985ECC7F60418AAF0CC5AB587F42C2570A884095A9E8CCACD0F6545C"

    return
}

# navigate to library root
cd $PSScriptRoot

# load necessary modules
.\aws_load_default_modules.ps1

# Prompt for name if not specified
if ($serviceFamily -eq "") {
	$serviceFamily = Read-Host "Enter the name of the service family"
}
$serviceFamily = $serviceFamily.ToLower()

# Prompt for name if not specified
if ($tagName -eq "") {
	$tagName = Read-Host "Enter the name of the tag that contains the service family in your environment"
}
$tagName = $tagName.ToLower()

if ($imgUri -eq "" -and $ecrUri -eq "") {
	$ecrUri = Read-Host "Enter the ECR URI, or restart the script and specify the imgUri"
}

$serviceClusters = @()
$clusters = Get-ECSClusterList
foreach($cluster in $clusters) {
    $tags = Get-ECSTagsForResource -ResourceArn $cluster
    
    foreach($tag in $tags) {
        if($tag.Key -eq $tagName -and $serviceFamily -eq $serviceFamily) {
            $serviceClusters += $cluster
        }
    }
}

foreach($cluster in $serviceClusters) {

    # build array of objects of instances and their running tasks
    # identify instance with least load
    # create new task from json template, find and replace unique values

    #if no instance has enough resources, continue looping over clusters

    # save container instance that task is launched on for use by targeting group in elb
    $instances = Get-ECSContainerInstanceList -Cluster $cluster
    foreach($instance in $instances) {
        
    }

    $temp = Get-ECSClusterDetail -Cluster $cluster
    $temp2 = Get-ECSTaskList -Cluster $cluster
    $temp3 = Get-ECSTaskDetail -Cluster $temp.Clusters[0].ClusterArn -Task $temp2[0]
    $temp4 = Get-ECSContainerInstanceList -Cluster $cluster
    $temp5 = Get-ECSContainerInstanceDetail -Cluster $cluster -ContainerInstance $temp4.Split("/")[1]
}