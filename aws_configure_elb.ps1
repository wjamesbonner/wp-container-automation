param(
    [Alias("s")]
    [string] $serviceFamily = "wp-containers",

    [Alias("t")]
    [string] $tagName = "service-family",

    [Alias("h")]
    [switch] $help = $false
)

if ($help) {
	Write-Host "aws_get_elb.ps1 is a script that creates a listner for the wp-container service."
	Write-Host "Prerequisites: Powershell"
	Write-Host ""
	Write-Host "Parameters:"
	Write-Host ""
	Write-Host "serviceFamily"
	Write-Host "    The name of the service family to find loadbalancers for."
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

if (Get-Module -ListAvailable -Name AWS.Tools.ElasticLoadBalancingV2) {
    Import-Module AWS.Tools.ElasticLoadBalancingV2
} 
else {
    Write-Host "Module Import-Module AWS.Tools.ElasticLoadBalancingV2 has not been installed.  Please run this libraries setup script."
    return;
}

$elbs = Get-ELB2LoadBalancer
$serviceElbs = @()
$targetElb = ""

foreach($elb in $elbs) {
    $tags = Get-ELB2Tag -ResourceArn $elb.LoadBalancerArn
    foreach($tag in $tags.Tags) {
        if($tag.Key -eq $tagName -and $tag.Value -eq $serviceFamily) {
            $serviceElbs += $elb
        }
    }
}

foreach($elb in $serviceElbs) {
    $listeners = Get-ELB2Listener -LoadBalancerArn $elb.LoadBalancerArn
    foreach($listener in $listeners) {
        $rules = Get-ELB2Rule -ListenerArn $listener.ListenerArn
        if($rules.Count -lt 100) {
            if($listener.Protocol -eq "HTTPS") {
                $httpsListenerHasCapacity = $true
            } elseif($listener.Protocol -eq "HTTP") {
                $httpListenerHasCapacity = $true
            }
        }
    }

    if($httpsListenerHasCapacity -and $httpListenerHasCapacity) {
        $targetElb = $elbs
        break
    }
}

if($targetElb -eq "") {

    $targetElb = New-Object -TypeName Amazon.ElasticLoadBalancingV2.Model.LoadBalancer
    New-ELB2LoadBalancer
}