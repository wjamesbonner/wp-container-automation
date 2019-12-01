param(
    [Alias("sl")]
    [string] $httpsListenerArn = "arn:aws:elasticloadbalancing:us-west-2:548069994063:listener/app/ecs-webfarm/143841c1f7ffecd4/668ff79e27d8db0b",

    [Alias("il")]
    [string] $httpListenerArn = "arn:aws:elasticloadbalancing:us-west-2:548069994063:listener/app/ecs-webfarm/143841c1f7ffecd4/ff36611b9f2b2471",

    [Alias("s")]
    [string] $serviceId = "t1000000",

    [Alias("u")]
    [string] $url = "it.cahnrs.wsu.edu",

    [Alias("h")]
    [switch] $help = $false
)

if ($help) {
	Write-Host "aws_create_listner_rule.ps1 is a script that creates a listner for the wp-container service."
	Write-Host "Prerequisites: Powershell"
	Write-Host ""
	Write-Host "Parameters:"
	Write-Host ""
	Write-Host "httpsListenerArn"
	Write-Host "    The ARN of the https listner to update"
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_create_listner_rule.ps1 -listnerArn `"arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143`""
    Write-Host "    Example: ./aws_create_listner_rule.ps1 -l `"arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143`""
	
    Write-Host ""
	Write-Host "url"
	Write-Host "    The host/url of the service you are listening for"
	Write-Host "    Default: arn:aws:elasticloadbalancing:us-west-2:8675309:loadbalancer/app/lb-name/eff143"
    Write-Host "    Alias: f"
	Write-Host "    Example: ./aws_create_listner_rule.ps1 -url service-id.it.cahnrs.wsu.edu"
    Write-Host "    Example: ./aws_create_listner_rule.ps1 -u service-id.it.cahnrs.wsu.edu"
	
    return
}

# navigate to library root
cd $PSScriptRoot

# Check for necessary module
if (Get-Module -ListAvailable -Name AWS.Tools.ElasticLoadBalancingV2) {
    Import-Module AWS.Tools.ElasticLoadBalancingV2
} 
else {
    Write-Host "Module Import-Module AWS.Tools.ElasticLoadBalancingV2 has not been installed.  Please run this libraries setup script."
    return;
}

#$httpsListener = Get-ELB2Listener -ListenerArn $httpsListenerArn
#$httpListener = Get-ELB2Listener -ListenerArn $httpListenerArn


$ruleAlreadyExists = $false
$maxHttpsPriority = 0
$maxHttpPriority = 0
$portsInUse = @()
$minPort = 49152
$maxPort = 65535
$portToAssign = 0

# Get https rules and check if one already exists for this service
$rules = Get-ELB2Rule -ListenerArn $httpsListenerArn
foreach($rule in $rules) {
    foreach($condition in $rule.Conditions) {
        foreach($value in $condition.Values) {
            if($value.Contains($serviceId)) {
                $ruleAlreadyExists = $true
            }
        }
    }

    if($rule.Priority -gt $maxHttpsPriority) {
        $maxHttpsPriority = $rule.Priority
    }

    $portsInUse += $rule.Actions[0].RedirectConfig[0].Port
}

$rules = Get-ELB2Rule -ListenerArn $httpListenerArn
foreach($rule in $rules) {
    foreach($condition in $rule.Conditions) {
        foreach($value in $condition.Values) {
            if($value.Contains($serviceId)) {
                $ruleAlreadyExists = $true
            }
        }
    }

    if($rule.Priority -gt $maxHttpsPriority) {
        $maxHttpPriority = $rule.Priority
    }

    $portsInUse += $rule.Actions[0].RedirectConfig[0].Port
}

if($ruleAlreadyExists -eq $true) {
    Write-Host "Listener rule already exists"
    return $false
}

$portsInUse = ($portsInUse | Sort)

if($portsInUse.Length -eq 0) {
    $portToAssign = $minPort
} elseif($portsInUse[0] + $portsInUse.Length -eq $portsInUse[$portsInUse.Length - 1] + 1) {
    # no gap in used port range exists, so use either min or maxInUe+1
    if($portsInUse[0] -ne $minPort) {
        $portToAssign = $minPort
    } else {
        $portToAssign = $portsInUse[$portsInUse.Length - 1] + 1
    }
} else {
    for($i=0;$i -lt $portsInUse.Length; $i++) {
        if($portsInUse[$i] -ne ($portsInUse[$i+1]-1)) {
            $portToAssign = $portsInUse[$i] + 1
            break
        }
    }
}

$maxHttpsPriority += 1
$maxHttpPriority += 1

$condition = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.RuleCondition
$condition.Field = "host-header"
$condition.Values += ("{0}.{1}" -f $serviceId, $url)

$action = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.Action
$action.Order = 1
$action.Type = "redirect"
$action.RedirectConfig = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.RedirectActionConfig
$action.RedirectConfig.Host = "#{host}"
$action.RedirectConfig.Path = "/#{path}"
$action.RedirectConfig.Port = $maxHttpPort
$action.RedirectConfig.Protocol = "HTTPS"
$action.RedirectConfig.Query = "#{query}"
$action.RedirectConfig.StatusCode = "HTTP_301"

$result = New-ELB2Rule -ListenerArn $httpsListenerArn -Condition $condition -Action $action -Priority $maxHttpsPriority