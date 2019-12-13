param(
    [Alias("f")]
    [string] $serviceFamily = "wp-containers",

    [Alias("p")]
    [string] $profileName  = "",

    [Alias("h")]
    [switch] $help = $false
)

if ($help) {
	Write-Output ("`t aws_initialize_service.ps1 will configure an existing ECS cluster tagged as part of the service family to run a new instance of the service, or create a new cluster if none exist already")
	Write-Output ("`t Prerequisites: Powershell")
	Write-Output ("`t ")
	Write-Output ("`t Parameters:")
	Write-Output ("`t ")
	Write-Output ("`t serviceFamily")
	Write-Output ("`t     The name of the service family.")
	Write-Output ("`t     Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143")
    Write-Output ("`t     Alias: f")
	Write-Output ("`t     Example: .\aws_initialize_service.ps1 -serviceFamily my-awesome-service")
    Write-Output ("`t     Example: .\aws_initialize_service.ps1 -s my-awesome-service")
	
    Write-Output ("`t ")
	Write-Output ("`t profileName")
	Write-Output ("`t     The name of the AWS configure credential profile to use, leave empty for default.")
	Write-Output ("`t     Default: {0}" -f $profileName)
    Write-Output ("`t     Alias: l")
	Write-Output ("`t     Example: .\aws_initialize_service.ps1 -profileName {0}" -f "myProfile")
    Write-Output ("`t     Example: .\aws_initialize_service.ps1 -l {0}" -f "myProfile")

    return
}

if($profileName -ne "") {
    try {
        Set-AWSCredential -ProfileName $profileName
        Write-Output ("`t AWS Profile set to {0}!" -f $profileName)
    } catch {
        Write-Output "`t Failed to set specified profile - aborting."
        return
    }
}

# navigate to library root
cd $PSScriptRoot

# pull service creation repo
git clone -q https://github.com/wjamesbonner/aws-service-provisioning.git

#$result = .\aws-service-provisioning\setup.ps1
$result = .\aws-service-provisioning\aws_provision_service_family.ps1 -serviceFamily $serviceFamily -loadBalancer $false -containerRepository $false

if($result[$result.Count - 1] -eq $false) {
    Write-Output "`t Service provisioning failed, check transcript!"
    return
}

cd $PSScriptRoot
rm aws-service-provisioning -Recurse -Force