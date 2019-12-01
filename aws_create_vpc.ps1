param(
    [Alias("s")]
    [string] $serviceFamily = "wp-containers",

    [Alias("t")]
    [string] $tagName = "service-family",

    [Alias("c")]
    [string] $cidrBlock  = "10.1.1.0/24",

    [Alias("i")]
    [string] $instanceTenancy   = "default",

    [Alias("n")]
    [string[]] $subnetworks  = @("10.1.1.0/25", "10.1.1.128/25"),

    [Alias("z")]
    [string[]] $zones  = @("us-west-2a", "us-west-2b"),

    [Alias("h")]
    [switch] $help = $false
)

if ($help) {
	Write-Host "`t aws_configure_ecs.ps1 will configure an existing ECS cluster tagged as part of the service family to run a new instance of the service, or create a new cluster if none exist already"
	Write-Host "`t Prerequisites: Powershell"
	Write-Host "`t "
	Write-Host "`t Parameters:"
	Write-Host "`t "
	Write-Host "`t serviceFamily"
	Write-Host "`t     The name of the service family."
	Write-Host "`t     Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "`t     Alias: f"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -serviceFamily wp-containers"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -s wp-containers"
	
    Write-Host "`t "
	Write-Host "`t tagName"
	Write-Host "`t     The name of the tag that stores the service family name"
	Write-Host "`t     Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "`t     Alias: f"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -tagName service-family"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -t service-family"

    return
}

if($subnetworks.Length -ne $zones.Length) {
    Write-Host "`t The number of subnetworks must match the number of zones"
    return
}

# navigate to library root
cd $PSScriptRoot

# load necessary modules
.\aws_load_default_modules.ps1

Write-Host "`t Creating VPC"
$vpc = New-EC2VPC -CidrBlock $cidrBlock -InstanceTenancy $instanceTenancy

do{
    Write-Host "`t Checking VPC state..."
    $vpc = Get-EC2Vpc -VpcId $vpc.VpcId
    Start-Sleep -Seconds 5
} while($vpc.State -ne "available")

Write-Host "`t Tagging VPC"
$hash = @{Key="Name"; Value=$serviceFamily}
$nameTag = [PSCustomObject]$hash
New-EC2Tag -Resource $vpc.VpcId -Tag $nameTag

$hash = @{Key=$tagName; Value=$serviceFamily}
$serviceTag = [PSCustomObject]$hash
New-EC2Tag -Resource $vpc.VpcId -Tag $serviceTag

Write-Host "`t Building subnets"
$networks = @()
for($i=0;$i -lt $subnetworks.Length;$i++) {
    $network = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $subnetworks[$i] -AvailabilityZone $zones[$i]
    do{
        Write-Host "`t Checking subnet state..."
        $network = Get-EC2Subnet -SubnetId $network.SubnetId
        Start-Sleep -Seconds 5
    } while($network.State -ne "available")

    New-EC2Tag -Resource $network.SubnetId -Tag $nameTag
    New-EC2Tag -Resource $network.SubnetId -Tag $serviceTag
    $networks += $network
}

Write-Host "`t Retrieving route tables..."
$routeTables = Get-EC2RouteTable
foreach($routeTable in $routeTables) {
    if($routeTable.VpcId -eq $vpc.VpcId) {
        Write-Host "`t Tagging route tables"
        $result = New-EC2Tag -Resource $routeTable.RouteTableId -Tag $nameTag
        $result = New-EC2Tag -Resource $routeTable.RouteTableId -Tag $serviceTag

        Write-Host "`t Registering subnets to route table"
        foreach($network in $networks) {
            $result = Register-EC2RouteTable -RouteTableId $routeTable.RouteTableId -SubnetId $network.SubnetId
        }
    }
}

Write-Host "`t Creating internet gateway..."
$igw = New-EC2InternetGateway

Write-Host "`t Tagging internet gateway..."
$result = New-EC2Tag -Resource $igw.InternetGatewayId -Tag $nameTag
$result = New-EC2Tag -Resource $igw.InternetGatewayId -Tag $serviceTag

Write-Host "`t Attaching internet gateway to VPC..."
$result = Add-EC2InternetGateway -VpcId $vpc.VpcId -InternetGatewayId $igw.InternetGatewayId

Write-Host "`t Creating load balancer security group..."
$sg = New-EC2SecurityGroup -GroupName $serviceFamily -Description $serviceFamily -VpcId $vpc.VpcId

Write-Host "`t Configuring security group rules..."
$ipRange = New-Object -TypeName Amazon.EC2.Model.IpRange
$ipRange.CidrIp = "0.0.0.0/0"
#$ipRange.Description = $null #Do not set description or it will not match default egress rule.  Powershell differentiates null and parameter not set. https://stackoverflow.com/questions/28697349/how-do-i-assign-a-null-value-to-a-variable-in-powershell
$outPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$outPermission.FromPort = 0
$outPermission.IpProtocol = "-1"
$outPermission.Ipv4Ranges = $ipRange
$outPermission.ToPort = 0

Write-Host "`t Building security group ingress rules..."
$httpPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$httpPermission.FromPort = 80
$httpPermission.IpProtocol = "tcp"
$httpPermission.Ipv4Ranges = $ipRange
$httpPermission.ToPort = 80

$httpsPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$httpsPermission.FromPort = 443
$httpsPermission.IpProtocol = "tcp"
$httpsPermission.Ipv4Ranges = $ipRange
$httpsPermission.ToPort = 443

Write-Host "`t Applying ingress rules..."
$result = Grant-EC2SecurityGroupIngress -GroupId $sg -IpPermission $httpPermission,$httpsPermission

Write-Host "`t Revoking default agress rules..."
$result = Revoke-EC2SecurityGroupEgress -GroupId $sg -IpPermission $outPermission

Write-Host "`t Applying security group egress rules..."
$result = Grant-EC2SecurityGroupEgress -GroupId $sg -IpPermission $httpPermission,$httpsPermission

Write-Host "`t Applying egress rules..."
$result = Grant-EC2SecurityGroupEgress -GroupId $sg -IpPermission $outPermission

Write-Host "`t Tagging security group..."
$result = New-EC2Tag -Resource $sg -Tag $nameTag
$result = New-EC2Tag -Resource $sg -Tag $serviceTag

Write-Host "`t Building load balancer subnet list..."
$subnetList = @()
foreach($network in $networks) {
    $subnetList += $network.SubnetId
}

Write-Host "`t Creating elastic load balancer..."
$elb = New-ELB2LoadBalancer -IpAddressType ipv4 -Name $serviceFamily -Scheme internet-facing -SecurityGroup $sg -Subnet $subnetList -Tag $nameTag,$serviceTag -Type application