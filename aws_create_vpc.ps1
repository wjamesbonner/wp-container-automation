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

    [Alias("m")]
    [string] $managementMode  = "automatic",

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
    Write-Host "`t     Alias: s"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -serviceFamily wp-containers"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -s wp-containers"
	
    Write-Host "`t "
	Write-Host "`t tagName"
	Write-Host "`t     The name of the tag that stores the service family name"
	Write-Host "`t     Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "`t     Alias: t"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -tagName service-family"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -t service-family"

    Write-Host "`t "
	Write-Host "`t cidrBlock"
	Write-Host "`t     The CIDR block to use for this VPC"
	Write-Host "`t     Default: 10.1.1.0/24"
    Write-Host "`t     Alias: c"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -cidrBlock 10.1.1.0/24"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -c 10.1.1.0/24"

    Write-Host "`t "
	Write-Host "`t instanceTenancy"
	Write-Host "`t     The default tenancy for this VPC, i.e. dedicated hosting versus shared hosting."
	Write-Host "`t     Default: default"
    Write-Host "`t     Alias: i"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -instanceTenancy default"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -i default"

    Write-Host "`t "
	Write-Host "`t subnetworks"
	Write-Host "`t     Array of subnetworks to define for the VPC.  Must positionally match the zones parameter."
	Write-Host "`t     Default: 10.1.1.0/25, 10.1.1.128/25"
    Write-Host "`t     Alias: n"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -subnetworks service-family"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -n service-family"

    Write-Host "`t "
	Write-Host "`t zones"
	Write-Host "`t     The zones to locate the subnets in the subnetworks parameter"
	Write-Host "`t     Default: us-west-2a, us-west-2b"
    Write-Host "`t     Alias: f"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -zones us-west-2a, us-west-2b"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -z us-west-2a, us-west-2b"

    Write-Host "`t "
	Write-Host "`t managementMode"
	Write-Host "`t     The management mode of the service, i.e. automatic or manual"
	Write-Host "`t     Default: automatic"
    Write-Host "`t     Alias: m"
	Write-Host "`t     Example: ./aws_configure_ecs.ps1 -managementMode automatic"
    Write-Host "`t     Example: ./aws_configure_ecs.ps1 -m automatic"

    return
}

if($subnetworks.Length -ne $zones.Length) {
    Write-Host "`t The number of subnetworks must match the number of zones"
    return
}

# navigate to library root
cd $PSScriptRoot

$transcriptName = ("aws_create_vpc-{0}.txt" -f [DateTimeOffset]::Now.ToUnixTimeSeconds())
Start-Transcript -Path $transcriptName

$serviceFamily
$tagName
$cidrBlock
$instanceTenancy
$subnetworks
$zones
$managementMode

# load necessary modules
.\aws_load_default_modules.ps1

# Creating the virtual private cloud
Write-Host ""
Write-Host "`t Begin building and configuring the virtual private cloud."
Write-Host "`t Creating VPC..."
$vpc = New-EC2VPC -CidrBlock $cidrBlock -InstanceTenancy $instanceTenancy
$vpc

do{
    Write-Host ("`t Checking VPC {0} state..." -f $vpc.VpcId)
    $vpc = Get-EC2Vpc -VpcId $vpc.VpcId
    Start-Sleep -Seconds 5
} while($vpc.State -ne "available")

Write-Host "`t Building environment tags..."
$hash = @{Key="Name"; Value=$serviceFamily}
$nameTag = [PSCustomObject]$hash
$nameTag

$hash = @{Key=$tagName; Value=$serviceFamily}
$serviceTag = [PSCustomObject]$hash
$serviceTag

$hash = @{Key="management-mode"; Value=$managementMode}
$managementTag = [PSCustomObject]$hash
$managementTag

Write-Host "`t Tagging VPC..."
New-EC2Tag -Resource $vpc.VpcId -Tag $nameTag
New-EC2Tag -Resource $vpc.VpcId -Tag $serviceTag
New-EC2Tag -Resource $vpc.VpcId -Tag $managementTag

Write-Host "`t Building subnets..."
$networks = @()
for($i=0;$i -lt $subnetworks.Length;$i++) {
    $network = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $subnetworks[$i] -AvailabilityZone $zones[$i]
    $network
    do{
        Write-Host ("`t Checking subnet {0} state..." -f $network.CidrBlock)
        $network = Get-EC2Subnet -SubnetId $network.SubnetId
        $network
        Start-Sleep -Seconds 5
    } while($network.State -ne "available")

    Write-Host "`t Tagging subnet..."
    New-EC2Tag -Resource $network.SubnetId -Tag $nameTag
    New-EC2Tag -Resource $network.SubnetId -Tag $serviceTag
    New-EC2Tag -Resource $network.SubnetId -Tag $managementTag
    $networks += $network
}

# Creating the internet gateway
Write-Host ""
Write-Host "`t Begin building and configuring the internet gateway."
Write-Host "`t Creating internet gateway..."
$igw = New-EC2InternetGateway
$igw

Write-Host "`t Tagging internet gateway..."
New-EC2Tag -Resource $igw.InternetGatewayId -Tag $nameTag
New-EC2Tag -Resource $igw.InternetGatewayId -Tag $serviceTag
New-EC2Tag -Resource $igw.InternetGatewayId -Tag $managementTag

Write-Host "`t Attaching internet gateway to VPC..."
Add-EC2InternetGateway -VpcId $vpc.VpcId -InternetGatewayId $igw.InternetGatewayId

do{
    Write-Host "`t Verifying IGW-VPC attachment..."
    do{
        Write-Host "`t Checking IGW-VPC attachment..."
        $igw = Get-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId
        $igw
        Start-Sleep -Seconds 5
    } while($igw.Attachments.Count -ne 1)

    Write-Host "`t Checking IGW-VPC attachment status..."
    $igw = Get-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId
    $igw
    Start-Sleep -Seconds 5
} while($igw.Attachments[0].VpcId -ne $vpc.VpcId -and $igw.Attachments[0].State -ne "available")

Write-Host "`t Internet gateway built, configured, and attached to VPC."
Write-Host ""

Write-Host "`t Retrieving route tables..."
$routeTables = Get-EC2RouteTable
$routeTables
foreach($routeTable in $routeTables) {
    if($routeTable.VpcId -eq $vpc.VpcId) {
        Write-Host "`t Tagging route tables..."
        New-EC2Tag -Resource $routeTable.RouteTableId -Tag $nameTag
        New-EC2Tag -Resource $routeTable.RouteTableId -Tag $serviceTag
        New-EC2Tag -Resource $routeTable.RouteTableId -Tag $managementTag

        Write-Host "`t Registering subnets to route table..."
        foreach($network in $networks) {
            Register-EC2RouteTable -RouteTableId $routeTable.RouteTableId -SubnetId $network.SubnetId
        }

        Write-Host "`t Creating default IGW route..."
        New-EC2Route -RouteTableId $routeTable.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId
    }
}
Write-Host "`t VPC built, configured, and tagged."
Write-Host ""

# Creating security group for load balancer
Write-Host ""
Write-Host "`t Begin building and configuring the ELB security group."
Write-Host "`t Creating load balancer security group..."
$sg = New-EC2SecurityGroup -GroupName $serviceFamily -Description $serviceFamily -VpcId $vpc.VpcId
$sg

Write-Host "`t Defining IP ranges and default egress rules..."
$ipRange = New-Object -TypeName Amazon.EC2.Model.IpRange
$ipRange.CidrIp = "0.0.0.0/0"
#$ipRange.Description = $null   # Do not set description or it will not match default egress rule.  
                                # Powershell differentiates null and parameter not set. 
                                # https://stackoverflow.com/questions/28697349/how-do-i-assign-a-null-value-to-a-variable-in-powershell
$ipRange

$outPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$outPermission.FromPort = 0
$outPermission.IpProtocol = "-1"
$outPermission.Ipv4Ranges = $ipRange
$outPermission.ToPort = 0
$outPermission

Write-Host "`t Building security group ingress rules..."
$httpPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$httpPermission.FromPort = 80
$httpPermission.IpProtocol = "tcp"
$httpPermission.Ipv4Ranges = $ipRange
$httpPermission.ToPort = 80
$httpPermission

$httpsPermission = New-Object -TypeName Amazon.EC2.Model.IpPermission
$httpsPermission.FromPort = 443
$httpsPermission.IpProtocol = "tcp"
$httpsPermission.Ipv4Ranges = $ipRange
$httpsPermission.ToPort = 443
$httpsPermission

Write-Host "`t Applying ingress rules..."
Grant-EC2SecurityGroupIngress -GroupId $sg -IpPermission $httpPermission,$httpsPermission

Write-Host "`t Revoking default egress rules..."
Revoke-EC2SecurityGroupEgress -GroupId $sg -IpPermission $outPermission

Write-Host "`t Applying new security group egress rules..."
Grant-EC2SecurityGroupEgress -GroupId $sg -IpPermission $httpPermission,$httpsPermission

Write-Host "`t Tagging security group..."
New-EC2Tag -Resource $sg -Tag $nameTag
New-EC2Tag -Resource $sg -Tag $serviceTag
New-EC2Tag -Resource $sg -Tag $managementTag

Write-Host "`t Security group created, configured, and tagged."
Write-Host ""

# Creating the load balancer
Write-Host ""
Write-Host "`t Begin creation and configuration of load balancer."
Write-Host "`t Building load balancer subnet list..."
$subnetList = @()
foreach($network in $networks) {
    $subnetList += $network.SubnetId
}
$subnetList

Write-Host "`t Creating elastic load balancer..."
$elb = New-ELB2LoadBalancer -IpAddressType ipv4 -Name $serviceFamily -Scheme internet-facing -SecurityGroup $sg -Subnet $subnetList -Tag $nameTag,$serviceTag -Type application
$elb

do{
    Write-Host "`t Checking ELB state..."
    $elb = Get-ELB2LoadBalancer -LoadBalancerArn $elb.LoadBalancerArn
    Start-Sleep -Seconds 5
} while($elb.State.Code -ne "active")

Write-Host "`t Tagging ELB..."
Add-ELB2Tag -ResourceArn  $elb.LoadBalancerArn -Tag $nameTag
Add-ELB2Tag -ResourceArn  $elb.LoadBalancerArn -Tag $serviceTag
Add-ELB2Tag -ResourceArn  $elb.LoadBalancerArn -Tag $managementTag

Write-Host "`t ELB created, tagged and active."
Write-Host ""

Write-Host ""
Write-Host "`t Service environment created successfully."

# Begin validation
Write-Host "`t Validating Environment..."
$validationPassed = $false

$vpcValidated = $false
$vpcTest = Get-EC2Vpc -VpcId $vpc.VpcId
if($vpcTest.State -eq "available") {
    Write-Host ("`t`t VPC {0} validated" -f $vpc.VpcId)
    $vpcValidated = $true
}

$networksValidated = @()
foreach($network in $networks) {
    $subnetTest = Get-EC2Subnet -SubnetId $network.SubnetId

    $networksValidated += $false
    if($subnetTest.State -eq "available") {
        Write-Host ("`t`t subnet {0} validated" -f $network.CidrBlock)
        $networksValidated[$networksValidated.Count-1] = $true
    }
}

$igwValidated = $false
$igwTest = Get-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId
if($igwTest.Attachments[0].State -eq "available") {
    Write-Host ("`t`t IGW {0} validated" -f $igw.InternetGatewayId)
    $igwValidated = $true
}

$sgValidated = $false
$sgTest = Get-EC2SecurityGroup -GroupId $sg
if($sgTest.VpcId -eq $vpc.VpcId) {
    Write-Host ("`t`t SG {0} validated" -f $sg)
    $sgValidated = $true
}

$elbValidated = $false
$elbTest = Get-ELB2LoadBalancer -LoadBalancerArn $elb.LoadBalancerArn
if($elbTest.State[0].Code -eq "active") {
    Write-Host ("`t`t ELB {0} validated" -f $elb.LoadBalancerName)
    $elbValidated = $true
}

if($vpcValidated -and (($networksValidated | Unique).Count -eq 1 -and $networksValidated[0] -eq $true) -and $igwValidated -and $sgValidated -and $elbValidated) {
    $validationPassed = $true
}

if($validationPassed) {
    Write-Host "`t Environment successfully validated"
} else {
    Write-Host "`tValidation failed, review logs."
}

Stop-Transcript