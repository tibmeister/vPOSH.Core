<#
	.SYNOPSIS
		Common collection of frequently used Powershell and PowerCLI functions.
	.DESCRIPTION
		Common collection of frequently used Powershell and PowerCLI functions.  PowerCLI specific functions will have "[PowerCLI]" at the beginning of the Synopsis
#>
$global:vCenterCredentials = ''
$global:VMGuestCredentials = ''
function Initialize-Config
{
	## The $Global:vPOSHConfigPath variable must be set before calling this, such as in a profile.
    $global:vCenterObjects = [PSCustomObject[]](Get-Content $Global:vPOSHConfigPath/vcenters.json | ConvertFrom-JSON)
}

Initialize-Config

Function Connect-vCenter
{
    <#
	.SYNOPSIS
		[PowerCLI]Wrapper for Connect-VIServer
	.DESCRIPTION
		This is a wrapper for Connect-VIServer that allows for a stored session credential and checks for existing connections.
		Also, you can pass a credential object into the command to allow for externally stored credentials to be used.
	.EXAMPLE
		Connect-vCenter -vCenters myvcenter.mydomain.com
	.EXAMPLE
		Connect-vCenter -vCenters myvcenter.mydomain.com -CredentialObject $credObject
	.PARAMETER vCenters
		Which vCenter(s) to connect to
    .PARAMETER vCenter
		Which vCenter to connect to
	.PARAMETER CredentialObject
		Credential object to use if you already have one
	.PARAMETER ClearPreviousCreds
		Clear out any previous credentials?
	.PARAMETER UseSSPI
		Use current users credentials
	.PARAMETER Menu
		Indicate that you want to select a connection server from a list of recently connected servers.
	.PARAMETER SSHNoDomain
		Creates a new SSHCredential object that strips the domain name (in format {domain}\{username}), by default this is done.
	#>
    [CmdletBinding(DefaultParameterSetName = 'base')]
    param
    (
        [Parameter(Mandatory = $true,
            HelpMessage = 'Which vCenter(s) to connect to',
            ParameterSetName = 'base',
            Position = 0)]
        [alias("vCenter")]
        [string[]]$vCenters,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Credential object to use',
            ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'menu')]
        $CredentialObject = '',

        [Parameter(mandatory = $false,
            HelpMessage = 'Clear out any previous credentials?',
            ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'menu')]
        [Parameter(ParameterSetName = 'all')]
        [switch]$ClearPreviousCreds = $false,

        [Parameter(mandatory = $false,
            HelpMessage = 'Use current users credentials',
            ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'menu')]
        [Parameter(ParameterSetName = 'all')]
        [Parameter(ParameterSetName = 'sspi')]
        [switch]$UseSSPI = $false,

      #   [Parameter(mandatory = $true,
      #       HelpMessage = 'Indicate that you want to select a connection server from a list of recently connected servers.',
      #       ParameterSetName = 'menu')]
      #   [switch]$Menu = $false,

        [Parameter(mandatory = $true,
            HelpMessage = 'Indicate that you want to connect to all vCenters.',
            ParameterSetName = 'all')]
        [switch]$All = $false,

        [Parameter(mandatory = $false,
            HelpMessage = "Strip domain from SSH Credentials",
            ParameterSetName = 'base')]
        [Parameter(ParameterSetName = 'all')]
        [Parameter(ParameterSetName = 'menu')]
        [Parameter(ParameterSetName = 'sspi')]
        [switch]$SSHNoDomain = $true
    )

    DynamicParam
    {
        # Define the dictionary object
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

		# Set the first parameter
		## Set the dynamic parameters' name
        $ParamName_Location = 'Location'
        ## Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        ## Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$ParameterAttribute.Mandatory = $false
		$ParameterAttribute.ParameterSetName = 'specified'
		$ParameterAttribute.HelpMessage = 'Location to filter vCenters by as defined in the vcenters.json file'
        ## Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)
        ## Generate and set the ValidateSet
        $arrSet = @(($global:vCenterObjects | Select -Unique Location).Location)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        ## Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)
        ## Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_Location, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParamName_Location, $RuntimeParameter)
        # End of first parameter

		# Set the first parameter
		## Set the dynamic parameters' name
        $ParamName_Environment = 'Environment'
        ## Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        ## Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
		$ParameterAttribute.Mandatory = $false
		$ParameterAttribute.ParameterSetName = 'specified'
		$ParameterAttribute.HelpMessage = 'Environment to filter vCenters by as defined in the vcenters.json file'
        ## Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)
        ## Generate and set the ValidateSet
        $arrSet = @(($global:vCenterObjects | Select -Unique Environment).Environment)
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        ## Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)
        ## Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParamName_Environment, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParamName_Environment, $RuntimeParameter)
		# End of second parameter

        # Return the entire set
        return $RuntimeParameterDictionary
    }

    begin { }
    process
    {
		$Location = $PSBoundParameters[$ParamName_Location]
		$Environment = $PSBoundParameters[$ParamName_Environment]

        if ($Menu)
        {
            Clear-Host
            [int]$i = 1
            #$recentConnections = Get-RecentConnections
            if ($ClearPreviousCreds)
            {
                Write-Verbose "Clearing previous credentials"
                $recentConnections = Get-vCentersFromDashboard
            }
            elseif ($CredentialObject)
            {
                $recentConnections = Get-vCentersFromDashboard
            }
            elseif ($UseSSPI)
            {
                Write-Verbose "Using SSPI style conenction"
                $recentConnections = Get-vCentersFromDashboard
            }
            else
            {
                $recentConnections = Get-vCentersFromDashboard
            }

            Write-Host "Items in " -NoNewline -ForegroundColor Yellow
            Write-Host "Green " -NoNewline -ForegroundColor Green
            Write-Host "are able to be contacted and selected.  Items in " -NoNewline -ForegroundColor Yellow
            Write-Host "Red " -NoNewline -ForegroundColor Red
            Write-Host "failed a ping check." -ForegroundColor Yellow
            Write-Host

            foreach ($entry in $recentConnections)
            {
                if ($entry.Length -gt 0)
                {
                    if (!(Test-Connection -ComputerName $entry -Count 1 -Quiet))
                    {
                        Write-Host "$i - $($entry)" -ForegroundColor Red
                    }
                    else
                    {
                        Write-Host "$i - $($entry)" -ForegroundColor Green
                    }

                    $i++
                }
            }
            [int]$menuChoice = Read-Host 'Please make a selection'

            $vCenters = $($recentConnections[$menuChoice - 1])
        }

        if ($All)
        {
            $vCenters = ($global:vCenterObjects).vCenter
        }

        if ($Location)
        {
            $vCenters = @(($global:vCenterObjects | Where Location -match $Location).vCenter)
		}

		if($Environment)
		{
			$vCenters = @(($global:vCenterObjects | Where Environment -match $Environment).vCenter)
		}

		if($Environment -and $Location)
		{
			$vCenters = @(($global:vCenterObjects | Where {($_.Environment -match $Environment) -and ($_.Location -match $Location)}).vCenter)
		}

        Write-Verbose "$vCenters"

        foreach ($vCenter in $vCenters)
        {
            if ($vCenter.Length -gt 0)
            {
                if ($UseSSPI)
                {
                    Connect-VIServer -Server $vCenter -ErrorAction Stop
                }
                else
                {
                    if ($ClearPreviousCreds)
                    {
                        $global:vCenterCredentials = $Host.UI.PromptForCredential("Domain Credentials for vCenter", 'Enter your domain account used to access this vCenter', '', '')
                        $global:DefaultVIServers = $null
                    }

                    if ($CredentialObject)
                    {
                        $global:vCenterCredentials = $CredentialObject
                    }
                    else
                    {
                        if (!$global:vCenterCredentials)
                        {
                            $global:vCenterCredentials = $Host.UI.PromptForCredential("Domain Credentials for vCenter", 'Enter your domain account used to access this vCenter', '', '')
                        }
                    }
                    if ($global:DefaultVIServers -notcontains $vCenter)
                    {
                        if (Test-Connection -ComputerName $vCenter -Count 1 -Quiet)
                        {
                            Connect-VIServer -Server $vCenter -Credential $global:vCenterCredentials -ErrorAction SilentlyContinue | Out-Null
                            if ($?)
                            {
                                Write-Host "Connected to $($vCenter)" -ForegroundColor Green
                            }
                            else
                            {
                                Write-Host "Could not connect to $($vCenter)" -ForegroundColor Red
                            }
                        }
                        else
                        {
                            Write-Host "Could not connect to $($vCenter)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
    }
    end { }
}

#TODO: Check this function before release
function Move-OldFile
{
	<#
	.SYNOPSIS
		Performs a file rotation of the given file.
	.DESCRIPTION
		Performs a file rotation of the given file, moving the existing file to a new file with a sequence number in Parenthases
	.EXAMPLE
		Move-OldFile -OutputFile C:\Temp\test.xml
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Full Path and Name of the file to rotate')]
		[string]$OutputFile
	)

	if(Test-Path -Path $OutputFile)
	{
		$baseFile = Get-Item -Path $OutputFile
		$basePath = $baseFile.Directory
		$baseFileName = $baseFile.BaseName
		$files = @(Get-ChildItem -Path $basePath | Where-Object {$_.BaseName -match $baseFile.BaseName})
		$newFile = "$basePath\$baseFileName(" + $files.Count + ')' + $baseFile.Extension
		Move-Item -Path $baseFile -Destination $newFile
	}
}

#TODO: Check this function before release
function Get-GuestCredentials
{
	<#
	.SYNOPSIS
		[PowerCLI]Sets the global VMGuest Credentials that can be easily passed to cmdlets
	.DESCRIPTION
		Allows for easy setting of the global VMGuestCredentials variable
	.PARAMETER ClearPreviousCreds
		Clears out credentials stored in session memory
	.EXAMPLE
		Get-GuestCredentials
	.EXAMPLE
		Get-GuestCredentials -ClearPreviousCreds
	#>
	param
	(
		[Parameter(Mandatory=$false)]
		[switch]$ClearPreviousCreds=$false
	)

	if($ClearPreviousCreds)
	{
		$global:VMGuestCredentials=$null
	}

	if(!$global:VMGuestCredentials)
	{
		$global:VMGuestCredentials = $Host.UI.PromptForCredential('VMGuest Credentials','Enter a set of credentials to access a VM Guest with','','')
	}
}

#TODO: Check this function before release
Function Connect-ESXiHost
{
	<#
	.SYNOPSIS
		[PowerCLI]Wrapper for Connect-VIServer
	.DESCRIPTION
		This is a wrapper for Connect-VIServer that allows for a stored session credential and checks for existing connections.
		Also, you can pass a credential object into the command to allow for externally stored credentials to be used.
	.EXAMPLE
		Connect-ESXiHost -ESXiHosts myHost.mydomain.com
	.EXAMPLE
		Connect-ESXiHost -ESXiHosts myHost.mydomain.com -CredentialObject $credObject
	.PARAMETER ESXiHosts
		Name of host(s) to connect to
	.PARAMETER CredentialObject
		Credential object to use if you already have one
	.PARAMETER ClearPreviousCreds
		Clear out any previous credentials
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Which ESXi Host(s) to connect to')]
        [alias("ESXiHost")]
		[string[]]$ESXiHosts,

		[Parameter(Mandatory=$false,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Credential object to use')]
		$CredentialObject='',

		[Parameter(mandatory=$false,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Clear out any previous credentials?')]
		[switch]$ClearPreviousCreds=$false
	)

	foreach($ESXiHost in $ESXiHosts)
	{
		if($ClearPreviousCreds)
		{
			$global:vCenterCredentials=$Host.UI.PromptForCredential("Domain Credentials for ESXi Host $ESXiHost",'Enter your domain account used to access this ESXi Host','','')
			$global:DefaultVIServers=$null
		}

		if($CredentialObject)
		{
			$global:vCenterCredentials=$CredentialObject
		}
		else
		{
			if(!$global:vCenterCredentials)
			{
				$global:vCenterCredentials=$Host.UI.PromptForCredential("Domain Credentials for ESXi Host $ESXiHost",'Enter your domain account used to access this ESXi Host','','')
			}
		}

		if($global:DefaultVIServers -notcontains $ESXiHost)
		{
			Connect-VIServer -Server $ESXiHost -Credential $global:vCenterCredentials -ErrorAction Stop
		}
		if($?)
		{
			Write-Host $true
		}
		else
		{
			Write-Host $false
		}
	}
}

Function Get-VMCPUReadyPercentDatacenter
{
	<#
	.SYNOPSIS
		[PowerCLI]Gathers the vCPU Ready % statistics for a given Datacenter for the given interval
	.DESCRIPTION
		Gathers the vCPU Ready % statistics for a given Datacenter for the given interval
	.EXAMPLE
		Get-VMCPUReadyPercentDatacenter -DataCenter prod -Interval day
	.PARAMETER DataCenter
		Which Datacenter to gather metrics from
	.PARAMETER Interval
		Interval for the metrics.  Valid values are day, week, month
	#>
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Which Datacenter to gather metrics from')]
		[string]$DataCenter,
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Interval for the metrics.  Valid values are day, week, month')]
		[ValidateSet('day','week','month')]
		[string]$Interval
	)
	Switch ($Interval)
	{
		'day' {$days=-1;$mins=5;$divider=3000}
		'week' {$days=-7;$mins=30;$divider=18000}
		'month' {$days=-30;$mins=120;$divider=72000}
	}

	$groups=Get-Stat -Entity (Get-vm -Location $DataCenter ) -Stat cpu.ready.summation -start (Get-date).adddays($days) -finish (Get-date) -interval $mins -instance '' -ea silentlycontinue|Group-Object entity

	$output=@()
	ForEach ($group in $groups)
	{
		$objOut = New-Object PSObject | Select-Object Name, CPURdyPcnt

		$objOut.Name=$group.Name
		$objOut.CPURdyPcnt= '{0:n2}' -f ((($group.group |measure-object value -ave).average/$divider) * 100 )
		$output+=$objOut
	}

	return $output
}

Function Get-VMCPUReadyPercentVM
{
	<#
	.SYNOPSIS
		[PowerCLI]Gathers the vCPU Ready % statistics for a given Datacenter for the given interval
	.DESCRIPTION
		Gathers the vCPU Ready % statistics for a given Datacenter for the given interval
	.EXAMPLE
		Get-VMCPUReadyPercentDatacenter -VMs fdxsql65,fdxsql66 -Interval day
	.PARAMETER VMs
		Which VM(s) to gather metrics from
	.PARAMETER Interval
		Interval for the metrics.  Valid values are day, week, month, year
	#>
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Which VM(s) to gather metrics from')]
		[string[]]$VMs,
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Interval for the metrics.  Valid values are day, week, month, year')]
		[ValidateSet('day','week','month','year')]
		[string]$Interval
	)
	Switch ($interval)
	{
		'day' {$days=-1;$mins=5;$divider=3000}
		'week' {$days=-7;$mins=30;$divider=18000}
		'month' {$days=-30;$mins=120;$divider=72000}
		'year' {$days=-365;$mins=1440;$divider=864000}
	}

	$output=@()
	foreach ($vm in $VMs)
	{
		$vmStat=Get-Stat -Entity (Get-vm -Name $vm ) -Stat cpu.ready.summation -start (Get-date).adddays($days) -finish (Get-date) -interval $mins -instance '' -ea silentlycontinue|Group-Object entity
		$objOut = New-Object PSObject | Select-Object Name, CPURdyPcnt

		$objOut.Name=$vmStat.Name
		$objOut.CPURdyPcnt= '{0:n2}' -f ((($vmStat.group |measure-object value -ave).average/$divider) * 100)
		$output+=$objOut
	}

	return $output
}

#TODO: Implement this in a .1 release
#region futurerelease
# Function Watch-Output {
#     <#
#         .SYNOPSIS
#             Runs a scriptblock or the preceeding pipeline repeatedly until there is change.

#         .DESCRIPTION
#             The Watch-Output cmdlet runs a specified scriptblock repeatedly at the specified interval (or
#             every 1 second by default) and returns the result of the scriptblock when the output has changed.
#             For the command to work the specified scriptblock must return a result to the pipeline.

#         .PARAMETER ScriptBlock
#             The scriptblock to execute, specified via curly braces. If you provide input via the pipleine that
#             isn't a scriptblock then the entire invocation line that preceeded the cmdlet will be used as the
#             scriptblock input.

#         .PARAMETER Seconds
#             Number of seconds to wait between checks. Default = 10

#         .PARAMETER Difference
#             Switch: Use to only output items in the collection that have changed
#             dditions or modifications).

#         .PARAMETER Continuous
#             Switch: Run continuously (even after a change has occurred) until exited with CTRL+C.

#         .PARAMETER AsString
#             Switch: Converts the result of the scriptblock into an array of strings for comparison.

#         .PARAMETER ClearScreen
#             Switch: Clears the screen between each result. You can also use 'cls' as an alias.

#         .PARAMETER Property
#             Manually specify one or more property names to be used for comparison. If not specified,
#             the default display property set is used. If there is not a default display property set,
#             all properties are used. You can also use '*' to force all properties.

#         .EXAMPLE
#             Watch-Output -ScriptBlock { Get-Process }

#             Runs Get-Process and waits for any returns the result when the data has changed.

#         .EXAMPLE
#             Get-Service | Watch-Output -Diff -Cont

#             Runs Get-Service and returns any differences in the resultant data, continuously until interrupted
#             by CTRL+C.

#         .EXAMPLE
#             Watch-Output { Get-Content test.txt } -Difference -Verbose -ClearScreen

#             Uses Get-Content to monitor test.txt. Shows any changes and clears the screen between changes.

#         .EXAMPLE
#             Get-ChildItem | Watch-Output -Difference -AsString

#             Monitors the result of GEt-ChildItem for changes, returns any differences. Treats the input as
#             strings not objects.

#         .EXAMPLE
#             Get-Process | Watch-Output -Difference -Property processname,id -Continuous

#             Monitors Get-Process for differences in the specified properties only, continues until interrupted
#             by CTRL+C.
#     #>
#     [cmdletbinding()]
#     Param(
#         [parameter(ValueFromPipeline, Mandatory)]
#         [object]
#         $ScriptBlock,

#         [int]
#         $Seconds = 10,

#         [switch]
#         $Difference,

#         [switch]
#         $Continuous,

#         [switch]
#         $AsString,

#         [alias('cls')]
#         [switch]
#         $ClearScreen,

#         [string[]]
#         $Property
#     )

#     if ($ScriptBlock -isnot [scriptblock]) {
#         if ($MyInvocation.PipelinePosition -gt 1) {
#             $ScriptBlock = [Scriptblock]::Create( ($MyInvocation.Line -Split "\|\s*$($MyInvocation.InvocationName)")[0] )
#         }
#         else {
#             Throw 'The -ScriptBlock parameter must be provided an object of type ScriptBlock unless invoked via the Pipeline.'
#         }
#     }

#     Write-Verbose "Started executing $($ScriptBlock | Out-String)"

#     $FirstResult = Invoke-Command $ScriptBlock

#     if ($AsString) {
#         $FirstResult = $FirstResult | Out-String -Stream
#     }
#     elseif (($FirstResult | Select-Object -First 1) -isnot [string]){
#         if (-not $Property) {
#             $Property = ($FirstResult | Select-Object -First 1).PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
#         }

#         if (-not $Property -or $Property -eq '*') {
#             $Property = ($FirstResult | Select-Object -First 1).PSObject.Properties.Name
#         }

#         Write-Verbose "Watched properties: $($Property -Join ',')"
#     }


#     do {
#         do {
#             if ($Result) {
#                 Start-Sleep $Seconds
#             }

#             if ($ClearScreen) {
#                 Clear-Host
#             }

#             $Result = Invoke-Command $ScriptBlock

#             if ($AsString) {
#                 $Result = $Result | Out-String -Stream
#             }

#             $CompareParams = @{
#                 ReferenceObject  = @($FirstResult | Select-Object)
#                 DifferenceObject = @($Result | Select-Object)
#             }

#             if ($Property) {
#                 $CompareParams.Add('Property', $Property)
#             }

#             $Diff = Compare-Object @CompareParams -PassThru
#         }
#         until ($Diff)

#         Write-Verbose "Change occurred at $(Get-Date)"

#         if ($Difference) {
#             $Diff | Where-Object {$_.SideIndicator -eq '=>'}
#         }
#         else {
#             $Result
#         }

#         $FirstResult = $Result
#     }
#     until (-not $Continuous)
# }
#endregion

#TODO: Add in last update at top of screen
Function Watch-Command
{
	<#
	.SYNOPSIS
		[PowerCLI]Continually runs a command at the specified interval
	.DESCRIPTION
		Continually runs a command at the specified interval
	.EXAMPLE
		Watch-Command -CommandToRun Get-proc
	.EXAMPLE
		Watch-Command -CommandToRun Get-proc -WaitSeconds 5
	.PARAMETER CommandToRun
		Command to run in the form of a script block.
	.PARAMETER WaitSeconds
		Amount of time to wait to repeat the task, in seconds.  Default of 5.
	#>
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Command to run in the form of a script block')]
		[scriptblock]$CommandToRun,

		[Parameter(Mandatory=$false,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Amount of time to wait to repeat the task, in seconds.  Default of 5')]
		[int]$WaitSeconds=5
	)

	$private:sb = New-Object System.Text.StringBuilder
	$private:w0 = $private:h0 = 0
	for(;;)
	{

	    # invoke command, format output data
	    $private:n = $sb.Length = 0
	    $private:w = $Host.UI.RawUI.BufferSize.Width
	    $private:h = $Host.UI.RawUI.WindowSize.Height-1
	    [void]$sb.EnsureCapacity($w*$h)
	    .{
	        & $CommandToRun | Out-String -Stream | .{process{
	            if ($_ -and ++$n -le $h)
				{
	                $_ = $_.Replace("`t", ' ')
	                if ($_.Length -gt $w)
					{
	                    [void]$sb.Append($_.Substring(0, $w-1) + '*')
	                }
	                else
					{
	                    [void]$sb.Append($_.PadRight($w))
	                }
	            }
	        }}
	    }>$null

	    # fill screen
	    if ($w0 -ne $w -or $h0 -ne $h)
		{
	        $w0 = $w; $h0 = $h
	        Clear-Host; $private:origin = $Host.UI.RawUI.CursorPosition
	    }
	    else
		{
	        $Host.UI.RawUI.CursorPosition = $origin
		}
		Write-Host "Update Interval: $($WaitSeconds)s`tLast Update: $(Get-Date -Format T)`n"
	    Write-Host $sb -NoNewLine
	    $private:cursor = $Host.UI.RawUI.CursorPosition
	    if ($n -lt $h)
		{
	        Write-Host (' '*($w*($h-$n)+1)) -NoNewLine
	    }
	    elseif($n -gt $h)
		{
	        Write-Host '*' -NoNewLine
	    }
	    $Host.UI.RawUI.CursorPosition = $cursor
	    Start-Sleep $WaitSeconds

	}
}

Function Start-RollingReboot
{
	<#
	.SYNOPSIS
		[PowerCLI]Performs a rolling reboot of hosts that are supplied
	.DESCRIPTION
		Performs a rolling reboot of hosts that are supplied, for instance all hosts in a cluster, etc.  This will place the host in Maintenance Mode,
		reboot the host, wait for the hsot to return to the Maintenance status, then bring the host out of Maintenance Mode and continue to the next
		host in the supplied array.
	.EXAMPLE
		Start-RollingReboot -VMHostsToReboot "vlabapp19.uu.deere.com","vlabapp18.uu.deere.com"
	.PARAMETER VMHostsToReboot
		Array of VM Hosts you wish to reboot in a rolling fashion.  The order of this array is not modified from what is supplied.
	.PARAMETER HostPause
		Pause between hosts to allow the cluster DRS to normalize in seconds.  Defaults to 300 seconds, or 5 minutes.
	#>
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='VM Hosts to Reboot in a rolling fashion')]
		[string[]]$VMHostsToReboot,

		[Parameter(Mandatory=$false,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Pause between hosts in seconds')]
		[int]$HostPause = 300
	)

	foreach ($VMHostToReboot in $VMHostsToReboot)
	{
		[switch]$MaintMode=$false

		$tmpVMHost = Get-VMHost $VMHostToReboot -WarningAction SilentlyContinue
		if($tmpVMHost)
		{
			if($tmpVMHost.State -eq "Maintenance")
			{
				$MaintMode=$true
			}
			else
			{
				$tmpVMHost | Set-VMHost -State Maintenance -Evacuate -Confirm:$false -ErrorAction Stop
			}

			$tmpVMHost | Restart-VMHost -Confirm:$false | Out-Null

			# Wait for Server to show as down
			do
			{
				Start-Sleep 15
				$ServerState = (Get-vmhost $VMHostToReboot).ConnectionState
			}
			while ($ServerState -ne 'NotResponding')

			Write-Host "$VMHostToReboot is Down"

			do
			{
				Start-Sleep 60
				$ServerState = (Get-vmhost $VMHostToReboot).ConnectionState
				Write-Host 'Waiting for Reboot ...'
			}
			while ($ServerState -ne 'Maintenance')

			Write-Host "$VMHostToReboot is back up"

			if(!$MaintMode)
			{
				Set-VMHost $VMHostToReboot -State Connected -ErrorAction Stop
			}

			#Wait 5 minutes for DRS to normalize before moving to the next host
			Write-Host "Waiting 5 minutes for DRS to normalize"
			Start-Sleep -Seconds $HostPause
		}
	}
}

Function Wait-VMShutdown
{
	<#
	.SYNOPSIS
		[PowerCLI]Waits for a VM to power off
	.DESCRIPTION
		When shutting down a VM, it returns when the shutdown command is good, not waiting for the VM to actually power off.
		This will wait for the VM to completly power off.
	.EXAMPLE
		Wait-VMShutdown -VM (Get-VM linuxtest-fsdevcr3)
	.PARAMETER VMName
		Name of VM Object to watch
	.PARAMETER WaitSeconds
		Number of seconds before performing a hard kill, defaults to 360 (5 min)
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Name of VM Object to watch')]
		[string]$VMName,

		[Parameter(Mandatory=$false,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='Number of seconds before performing a hard kill')]
		[int]$WaitSeconds = 360
	)
	process
	{
		#Check to see if we are connected, if not, warn the user to connect first and exit
		if(!$global:DefaultVIServer)
		{
			Write-Host ''
			Write-Host 'You must first connect to a vCenter before proceeding' -ForegroundColor Red
			Exit
		}

		$tempvm = Get-VM $VMName
		$guestView = Get-View -ViewType VirtualMachine -Filter @{'Name'=$tempvm.Name}

		$guestView.UpdateViewData('Runtime.PowerState')
		if ($guestView.Runtime.PowerState -ne 'poweredOff')
		{
			$tempVM | Wait-Tools -TimeoutSeconds $WaitSeconds
			Shutdown-VMGuest -VM $tempVM -Confirm:$false
			$guestView.UpdateViewData('Runtime.PowerState')
		}
		$i = 0
      $waitRemain = $WaitSeconds

		while (($guestView.Runtime.PowerState -ne 'poweredOff') -and ($i -le [Math]::Ceiling($WaitSeconds / 5)))
		{
			Write-Progress -id 99337 -Activity "Wait for VM Shutdown" -SecondsRemaining $waitRemain
			Start-Sleep -Seconds 5
			try
			{
				$guestView.UpdateViewData('Runtime.PowerState')
			}
			catch
			{
			}
			$i++
			$waitRemain = $waitRemain - 5
		}
		Write-Progress -id 99337 -Completed -Activity "Wait for VM Shutdown"
	}
	end
	{
		return $tempvm
	}
}

Function Get-vCenterSessions
{
    <#
        .SYNOPSIS
            Lists vCenter Sessions.
        .DESCRIPTION
			Lists all connected vCenter Sessions, and some added properties such as idle time.
		.PARAMETER ExportPath
			Where to save the file to, including filename
        .EXAMPLE
            Get-vCenterSessions
        .EXAMPLE
            Get-vCenterSessions | Where { $_.IdleMinutes -gt 5 }
    #>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false,
		ParameterSetName='export')]
		[string]$ExportPath
	)

    $SessionMgr = Get-View $DefaultViserver.ExtensionData.Client.ServiceContent.SessionManager
    $AllSessions = @()
    $SessionMgr.SessionList | Foreach {
        $Session = New-Object -TypeName PSObject -Property @{
            Key = $_.Key
            UserName = $_.UserName
            FullName = $_.FullName
            LoginTime = ($_.LoginTime).ToLocalTime()
            LastActiveTime = ($_.LastActiveTime).ToLocalTime()

        }
        If ($_.Key -eq $SessionMgr.CurrentSession.Key)
		{
            $Session | Add-Member -MemberType NoteProperty -Name Status -Value 'Current Session'
        } Else
		{
            $Session | Add-Member -MemberType NoteProperty -Name Status -Value 'Idle'
        }
        $Session | Add-Member -MemberType NoteProperty -Name IdleMinutes -Value ([Math]::Round(((Get-Date) - ($_.LastActiveTime).ToLocalTime()).TotalMinutes))
    	$AllSessions += $Session
    }

	if($ExportPath)
	{
		$AllSessions | Export-Csv -NoTypeInformation -Path $ExportPath -NoClobber
	}

    return $AllSessions
}

function Get-LastPowerOn
{
	<#
		.SYNOPSIS
			Retrieves the last time a VM was powered on
		.DESCRIPTION
			Retrieves the last time a VM was powered on
		.EXAMPLE
			Get-LastLogOn -VM vm-object
		.PARAMETER VM
			VM to work on.
	#>
	param
	(
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		HelpMessage='VM Object')]
		[VMware.VimAutomation.Types.VirtualMachine]$VM
#		[Parameter(Mandatory=$false,
#		HelpMessage='Hours timeframe')]
#		[string]$Hours=""
	)

#	if($Hours)
#	{
#		$events = $VM | Get-VIEvent -Start (Get-Date).AddHours($Hours) | where {$_.FullFormattedMessage -match "Power On Virtual"}
#	}
#	else
#	{
		$events = $VM | Get-VIEvent | Where-Object {$_.FullFormattedMessage -match 'Power On Virtual'}
#	}

	return ($events | Select-Object -Last 1 | Select-Object @{N='VM';E={$_.VM.Name}},@{N='LastPoweredOnTime';E={$_.CreatedTime}})
}

function Get-ConsolidationRatio
{
    <#
    .SYNOPSIS
        Retrieves the consolidation ratio of vRAM and vCPU in a given Datacenter/Cluster
    .DESCRIPTION
        Retrieves the consolidation ratio of vRAM and vCPU in a given Datacenter/Cluster
    .PARAMETER Datacenters
        Comma-seperated list of Datacenter(s) you wish the script to act on.  If this is left blank, it will get all datacenters on the vCenter
    .EXAMPLE
	    Get-consolidationRatio.ps1 -Datacenters "fdxvcr3"
        Get-consolidationRatio.ps1 -Datacenters "fdxvcr3","fsdevcr3"
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false,
        Position=0,
	    HelpMessage='Comma-seperated list of Datacenter(s) you wish the script to act on.')]
	    [string[]]$Datacenters
    )

    #Clear-Host

    #Check to see if we are connected, if not, warn the user to connect first
    if(!$global:DefaultVIServer)
    {
	    Write-Host ''
	    Write-Host 'You must first connect to a vCenter before proceeding' -ForegroundColor Red
	    Exit
    }

    if(!$Datacenters)
    {
    	$Datacenters = Get-Datacenter
    }

    $objDataCenters=Foreach ($dc in $Datacenters)
    {
	    $cluster = get-cluster -location $dc
	    $objClusters=foreach ($cl in $cluster)
	    {
		    $ClusterVMs = $cl | Get-VM
		    if($ClusterVMs.Count -gt 0)
		    {
			    $ClusterMemory = [math]::round($cl.ExtensionData.Summary.TotalMemory / 1GB,0)

			    $ClusterCPUCores = $cl.ExtensionData.Summary.NumCpuCores

			    $ClusterAllocatedvCPUs = ($ClusterVMs | Measure-Object -Property NumCPu -Sum).Sum
			    $ClusterAllocatedvRAM = [Math]::Round(($ClusterVMs | Measure-Object -Property MemoryGB -Sum).Sum,0)

			    $CPUClusterRatio = 0
			    $RAMClusterRatio = 0


			    try
			    {
				    $CPUClusterRatio = [math]::round($ClusterAllocatedvCPUs / $ClusterCPUCores,2)
			    }
			    catch
			    {
			    }

			    try
			    {
				    $RAMClusterRatio = [Math]::Round($ClusterAllocatedvRAM / $ClusterMemory,2)
			    }
			    catch
			    {
			    }

          New-Object PSObject -Property @{
              'Cluster Name'=$cluster
              'pCPU Available'=$ClusterCPUCores
              'vCPU Allocated'=$ClusterAllocatedvCPUs
              'pRAM Available'=$ClusterMemory
              'vRAM Allocated'=$ClusterAllocatedvRAM
              'v/pCPU Ratio'=" $CPUClusterRatio : 1"
              'v/pRAM Ratio'=" $RAMClusterRatio : 1 "
          }
       }

        New-Object PSObject -Property @{
            Datacenter=$dc
            Clusters=$objClusters
        }
	    }
    }

    return $objDatacenters
}

function Get-ConsoleAsText
{
	<#
    .SYNOPSIS
        The script captures console screen buffer up to the current cursor position and returns it in plain text format.
    .DESCRIPTION
        The script captures console screen buffer up to the current cursor position and returns it in plain text format. ASCII-encoded string.
    .PARAMETER Datacenter
        Comma-seperated list of Datacenter(s) you wish the script to act on.  If this is left blank, it will get all datacenters on the vCenter
    .EXAMPLE
	    $textFileName = "$env:temp\ConsoleBuffer.txt"
		Get-ConsoleAsText | out-file $textFileName -encoding ascii
    #>

	# Check the host name and exit if the host is not the Windows PowerShell console host.
	if ($host.Name -ne 'ConsoleHost')
	{
		write-host -ForegroundColor Red "This script runs only in the console host. You cannot run this script in $($host.Name)."
		exit -1
	}

	# Initialize string builder.
	$textBuilder = new-object system.text.stringbuilder

	# Grab the console screen buffer contents using the Host console API.
	$bufferWidth = $host.ui.rawui.BufferSize.Width
	$bufferHeight = $host.ui.rawui.CursorPosition.Y
	$rec = new-object System.Management.Automation.Host.Rectangle 0,0,($bufferWidth - 1),$bufferHeight
	$buffer = $host.ui.rawui.GetBufferContents($rec)

	# Iterate through the lines in the console buffer.
	for($i = 0; $i -lt $bufferHeight; $i++)
	{
		for($j = 0; $j -lt $bufferWidth; $j++)
		{
			$cell = $buffer[$i,$j]
			$null = $textBuilder.Append($cell.Character)
		}

		$null = $textBuilder.Append("`r`n")
	}

	return $textBuilder.ToString()
}

function Get-VMXPath
{
	<#
    .SYNOPSIS
        [PowerCLI]The will return the full path to a VMs VMX file, useful in regestering a VM on a new host
    .DESCRIPTION
        The will return the full path to a VMs VMX file, useful in regestering a VM on a new host
    .PARAMETER VM
        The VM object you need the VMX file for
    .EXAMPLE
	    Get-VM myVM | Get-VMX
		Get-Datacenter MyDC | Get-VM | %{Get-VMX $_}
    #>
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true,
		Position=1,
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true)]
		[VMware.VimAutomation.Types.VirtualMachine]$VM
	)

	Begin
	{
		Write-Verbose "Retrieving VMX Path Info . . ."
	}
	Process
	{
		try
		{
			$VM | Add-Member -MemberType ScriptProperty -Name 'VMXPath' -Value {$this.extensiondata.config.files.vmpathname} -Passthru -Force | Select-Object Name,VMXPath
		}
		catch
		{
			"Error: You must connect to vCenter first." | Out-host
		}
	}
	End
	{

	}
}

function Get-ConnectedvCenters
{
	$vCenterData = @()

	foreach($vCenter in $global:DefaultVIServers)
	{
		$vCenter | Select Name, Version, Build, User
	}

	return $vCenterData
}

function Get-Lsh
{
    <#
    .SYNOPSIS
        Bitwise Left-Shift
    .DESCRIPTION
        Bitwise Left-Shift
    .PARAMETER n
    .PARAMETER bits
    #>
    [CmdletBinding()]
    param
    (
        [uint32]$n,

        [byte]$bits
    )

    $n * [Math]::Pow(2, $bits)
}

function Get-VersionStringAsObject
{
    <#
	.SYNOPSIS
		Takes a dot-noted versions string (major.minor.build) and converts it into a parsable object
	.DESCRIPTION
		Takes a dot-noted versions string (major.minor.build) and converts it into a parsable object
	.PARAMETER VersionString
    #>
    [CmdletBinding()]
	param
	(
		[CmdletBinding()]
		[Parameter(Mandatory=$true)]
		[String]$VersionString
	)

	$parts = $VersionString.Split(".")

	if($parts.Count -le 3)
	{
		$tmpObj = New-Object PSObject -Property @{
			Major = $parts[0]
			Minor = $parts[1]
			Build = $parts[2]
		}
	}
	else
	{
		$tmpObj = New-Object PSObject -Property @{
			Major = $parts[0]
			Minor = $parts[1]
			Build = $parts[2]
		}
	}

	return $tmpObj
}

function Get-VersionStringAsArray
{
    <#
    .SYNOPSIS
        Returns a dotted version string as a numeric array for easier comparision
    .DESCRIPTION
        Returns a version number "a.b.c.d" as a two-element numeric array. The first array element is the most significant 32 bits, and the second element is the least significant 32 bits.
    .PARAMETER Version
        Dotted Version number string
    #>
    [CmdletBinding()]
    param
    (
        [string]$version
    )

    $parts = $version.Split(".")
    if ($parts.Count -lt 5)
    {
        for ($n = $parts.Count; $n -lt 5; $n++)
        {
            $parts += "0"
        }
    }
    [UInt32] ((Get-Lsh $parts[1] 16) + $parts[2])
}

function Test-IsEven
{
	param
	(
		[string]$NumToCheck
	)

	[bool]$retVal = $true

	if([Math]::Truncate( [Int32]($NumToCheck % 2) ))
	{
		$retVal = $false
	}

	return $retVal
}

function Get-VMPerfStat
{
    <#
	.SYNOPSIS
		[PowerCLI]Get's the given VM's performance stats
	.DESCRIPTION
		Get's the given VM's performance stats and returns the results as either the average of CPU and Mem over the given time period or as the raw values
	.PARAMETER VMName
		Name of the VM to get data for
	.PARAMETER Hours
		Hours to go back from current time; defaults to 6
	.PARAMETER rawData
		Returns an object of rawData instead of avereged data
	.OUTPUT
		PSObject
	.EXAMPLE
		Just get the averaged data for the default of 6 hours

		Get-VMPerfStat -VMName (get-vm myVMName).Name
	.EXAMPLE
		Get the averaged data for the last 2 hours

		Get-VMPerfStat -VMName (get-vm myVMName).Name -Hours 2
	.EXAMPLE
		Get the raw data returned as arrays in the object's members.

		$myVariable = Get-VMPerfStat (get-vm myVMName).Name -rawData
    #>
    [CmdletBinding()]
    param
	(
			[string]$VMName,
            [int]$Hours = 6,
			[switch]$rawData
    )


    $vm = Get-VM $VMName

	$cpustat = $vm | Get-Stat -Stat cpu.usage.average -Start (Get-Date).AddHours(($Hours * -1)) -Finish (Get-Date) | where{ $_.Instance -eq "" }
    $cpuuse = ( $cpustat | Measure-Object -Property Value -Maximum -Minimum -Average )

    $memstat = $vm | Get-Stat -Stat mem.usage.average -Start (Get-Date).AddHours(($Hours * -1)) -Finish (Get-Date) | where{ $_.Instance -eq "" }
    $memuse = ( $memstat | Measure-Object -Property Value -Maximum -Minimum -Average )

	if($rawData)
	{
		$PerfStat = New-Object PSObject -Property @{
			VMName = $VMName
			"CpuUsageRaw" = $cpustat
			"MemUsageRaw" = $memstat
			"TimeStart" = (Get-Date).AddHours(($Hours * -1))
			"TimeSpan" = $Hours
		}
	}
	else
	{
		$PerfStat = New-Object PSObject -Property @{
			VMName = $VMName
			"CPUAv%" = ( [System.Math]::Round( $cpuuse.Average,2 ) )
			"CPUMax%" = ( [System.Math]::Round( $cpuuse.Maximum,2 ) )
			"CPUMin%" = ( [System.Math]::Round( $cpuuse.Minimum,2 ) )
			"MemAv%" = ( [System.Math]::Round( $memuse.Average,2 ) )
			"MemMax%" = ( [System.Math]::Round( $memuse.Maximum,2 ) )
			"MemMin%" = ( [System.Math]::Round( $memuse.Minimum,2 ) )
		}
	}

	return $PerfStat
}

function Get-VMHostPerfStat
{
	param (
		[string]$VMhostName,
		[int]$Days = "30"
	)
	Begin
	{
		$PerfStat = New-Object PSObject
		$VMhost = Get-VMhost $VMhostName
		$todayMidnight = ( Get-Date -Hour 0 -Minute 0 -Second 0 ).AddMinutes( -1 )


		$cpustat = $VMhost | Get-Stat -Stat cpu.usage.average -Start $todayMidnight.AddDays( - $Days ) -Finish $todayMidnight.AddDays( -1 ) | where { $_.Instance -eq "" }
		$cpuuse = ( $cpustat | Measure-Object -Property Value -Maximum -Minimum -Average )
		$memstat = $VMhost | Get-Stat -Stat mem.usage.average -Start $todayMidnight.AddDays( - $Days ) -Finish $todayMidnight.AddDays( -1 ) | where { $_.Instance -eq "" }
		$memuse = ( $memstat | Measure-Object -Property Value -Maximum -Minimum -Average )
	}
	Process
	{
		$PerfStat | add-member -MemberType NoteProperty -name "VMhostName" -Value $VMhost.Name
		$PerfStat | add-member -MemberType NoteProperty -name "CPUAv%" -Value ( [System.Math]::Round( $cpuuse.Average, 2 ) )
		$PerfStat | add-member -MemberType NoteProperty -name "CPUMax%" -Value ( [System.Math]::Round( $cpuuse.Maximum, 2 ) )
		$PerfStat | add-member -MemberType NoteProperty -name "CPUMin%" -Value ( [System.Math]::Round( $cpuuse.Minimum, 2 ) )
		$PerfStat | add-member -MemberType NoteProperty -name "MemAv%" -Value ( [System.Math]::Round( $memuse.Average, 2 ) )
		$PerfStat | add-member -MemberType NoteProperty -name "MemMax%" -Value ( [System.Math]::Round( $memuse.Maximum, 2 ) )
		$PerfStat | add-member -MemberType NoteProperty -name "MemMin%" -Value ( [System.Math]::Round( $memuse.Minimum, 2 ) )
	}
	End
	{
		$PerfStat
	}
}

function Get-CapacityPlanningData
{
    <#
        .SYNOPSIS
            [PowerCLI] Get's the Capacity Planning data
        .DESCRIPTION
            Get's the Capacity Planning data for a specified cluster(s) or all connected clusters
        .PARAMETER Clusters
            Non-mandatory parameter that is a comma-seperated list
        .EXAMPLE
            Get the capacity report for all clusters on all connected vCenters and output to a GridView

            Get-CapacityPlanningData | Out-GridView
        .EXAMPLE
            Get the capacity report for a specific cluster

            Get-CapacityPlanningData -Clusters Cluster1
        .EXAMPLE
            Get the capacity report for a specific clusters

            Get-CapacityPlanningData -Clusters Cluster1, Cluster2, Cluster3
        .INPUTS
            Cluster names
        .OUTPUTS
            Custom object
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false)]
        [string[]]$Clusters
    )

	$yesterdayStart = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays(-1)
	$todayStart = (Get-Date -Hour 0 -Minute 0 -Second 0)

	if(!($clusters))
	{
		$clusters = Get-Cluster
	}

	$retObj = foreach($cluster in $Clusters)
	{
		$cpustat = $cluster | Get-Stat -Stat cpu.usagemhz.average -Start $yesterdayStart -Finish $todayStart -IntervalMins 15 | where{ $_.Instance -eq "" }
		$cpuuse = ( $cpustat | Measure-Object -Property Value -Maximum -Minimum -Average )

		$memstat = $cluster | Get-Stat -Stat mem.consumed.average -Start $yesterdayStart -Finish $todayStart -IntervalMins 15 | where{ $_.Instance -eq "" }
		$memuse = ( $memstat | Measure-Object -Property Value -Maximum -Minimum -Average )

		$maxvcpu = '{0:N0}' -f (($cluster | Get-VMHost | Measure-Object -Property NumCpu -Sum | Select Sum).Sum)
		$usedvcpu = '{0:N0}' -f (($cluster | get-vm | Measure-Object -Property NumCpu -Sum | Select Sum).Sum)

		New-Object PSObject -Property @{
			clusterName = $cluster.Name
			usedMhzAvg = [Math]::Round($cpuuse.Average,2)
			usedMhzMax = [Math]::Round($cpuuse.Maximum,2)
			usedMhzMin = [Math]::Round($cpuuse.Minimum,2)
			percentUsedMhz = '{0:N2}' -f (($cluster | Get-VMHost | Measure-Object -Property CpuUsageMhz -Sum | Select Sum).Sum / $cluster.UsableCpuMhz * 100)
			usedMemAvg = [Math]::Round($memuse.Average * 1KB / 1GB,2) #Little funky math because we are given value in KB not B
			usedMemMax = [Math]::Round($memuse.Maximum * 1KB / 1GB,2) #Little funky math because we are given value in KB not B
			usedMemMin = [Math]::Round($memuse.Minimum * 1KB / 1GB,2) #Little funky math because we are given value in KB not B
			maxMhz = $cluster.UsableCpuMhz
			maxMem = $cluster.UsableRamGb
			maxVcpus = $maxvcpu
			usedVcpu = $usedvcpu
			availVcpu = $maxvcpu - $usedvcpu
		}
	}

    return $retObj
}

function Get-VIEventPlus
{
	<#
		.SYNOPSIS
			Returns vSphere events
		.DESCRIPTION
			The function will return vSphere events. With the available parameters, the execution time can be improved, compered to the original Get-VIEvent cmdlet.
		.PARAMETER Entity
			When specified the function returns events for the specific vSphere entity. By default events for all vSphere entities are returned.
		.PARAMETER EventType
			This parameter limits the returned events to those specified on this parameter.
		.PARAMETER Start
			The start date of the events to retrieve
		.PARAMETER Finish
			The end date of the events to retrieve.
		.PARAMETER Recurse
			A switch indicating if the events for the children of the Entity will also be returned
		.PARAMETER User
			The list of usernames for which events will be returned
		.PARAMETER System
			A switch that allows the selection of all system events.
		.PARAMETER ScheduledTask
			The name of a scheduled task for which the events will be returned
		.PARAMETER FullMessage
			A switch indicating if the full message shall be compiled. This switch can improve the execution speed if the full message is not needed.
		.EXAMPLE
			Get-VIEventPlus -Entity $vm
		.EXAMPLE
			Get-VIEventPlus -Entity $cluster -Recurse:$true
	#>
	[CmdletBinding()]
	param(
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$Entity,

		[string[]]$EventType,

		[DateTime]$Start,

		[DateTime]$Finish = (Get-Date),

		[switch]$Recurse,

		[string[]]$User,

		[Switch]$System,

		[string]$ScheduledTask,

		[switch]$FullMessage = $false
	)
	process
	{
		$eventnumber = 100
		$events = @()
		$eventMgr = Get-View EventManager
		$eventFilter = New-Object VMware.Vim.EventFilterSpec
		$eventFilter.disableFullMessage = ! $FullMessage
		$eventFilter.entity = New-Object VMware.Vim.EventFilterSpecByEntity
		$eventFilter.entity.recursion = & { if ($Recurse) { "all" }else { "self" } }
		$eventFilter.eventTypeId = $EventType

		if ($Start -or $Finish)
		{
			$eventFilter.time = New-Object VMware.Vim.EventFilterSpecByTime
			if ($Start)
			{
				$eventFilter.time.beginTime = $Start
			}
			if ($Finish)
			{
				$eventFilter.time.endTime = $Finish
			}
		}

		if ($User -or $System)
		{
			$eventFilter.UserName = New-Object VMware.Vim.EventFilterSpecByUsername
			if ($User)
			{
				$eventFilter.UserName.userList = $User
			}
			if ($System)
			{
				$eventFilter.UserName.systemUser = $System
			}
		}

		if ($ScheduledTask)
		{
			$si = Get-View ServiceInstance
			$schTskMgr = Get-View $si.Content.ScheduledTaskManager
			$eventFilter.ScheduledTask = Get-View $schTskMgr.ScheduledTask |
			where { $_.Info.Name -match $ScheduledTask } |
			Select -First 1 |
			Select -ExpandProperty MoRef
		}

		if (!$Entity)
		{
			$Entity = @(Get-Folder -Name Datacenters)
		}

		$entity | % {
			$eventFilter.entity.entity = $_.ExtensionData.MoRef
			$eventCollector = Get-View ($eventMgr.CreateCollectorForEvents($eventFilter))
			$eventsBuffer = $eventCollector.ReadNextEvents($eventnumber)
			while ($eventsBuffer)
			{
			$events += $eventsBuffer
			$eventsBuffer = $eventCollector.ReadNextEvents($eventnumber)
			}
			$eventCollector.DestroyCollector()
		}

		$events
	}
}

function Get-MotionHistory
{
	<#
		.SYNOPSIS
			Returns the vMotion/svMotion history
		.DESCRIPTION
			The function will return information on all the vMotions and svMotions that occurred over a specific interval for a defined number of virtual machines
		.PARAMETER Entity
			The vSphere entity. This can be one more virtual machines, or it can be a vSphere container. If the parameter is a container, the function will return the history for all the virtual machines in that container.
		.PARAMETER Days
			An integer that indicates over how many days in the past the function should report on.
		.PARAMETER Hours
			An integer that indicates over how many hours in the past the function should report on.
		.PARAMETER Minutes
			An integer that indicates over how many minutes in the past the function should report on.
		.PARAMETER Sort
			An switch that indicates if the results should be returned in chronological order.
		.EXAMPLE
			Get-MotionHistory -Entity $vm -Days 1
		.EXAMPLE
			Get-MotionHistory -Entity $cluster -Sort:$false
		.EXAMPLE
			Get-Datacenter -Name $dcName | Get-MotionHistory -Days 7 -Sort:$false
	#>
	[CmdletBinding(DefaultParameterSetName = "Days")]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$Entity,

		[Parameter(ParameterSetName = 'Days')]
		[int]$Days = 1,

		[Parameter(ParameterSetName = 'Hours')]
		[int]$Hours,

		[Parameter(ParameterSetName = 'Minutes')]
		[int]$Minutes,

		[switch]$Recurse = $false,

		[switch]$Sort = $true
	)
	begin
	{
		$history = @()
		switch ($psCmdlet.ParameterSetName)
		{
			'Days'
			{
				$start = (Get-Date).AddDays(- $Days)
			}
			'Hours'
			{
				$start = (Get-Date).AddHours(- $Hours)
			}
			'Minutes'
			{
				$start = (Get-Date).AddMinutes(- $Minutes)
			}
		}

		$eventTypes = "DrsVmMigratedEvent", "VmMigratedEvent"
	}
	process
	{
		$history += Get-VIEventPlus -Entity $entity -Start $start -EventType $eventTypes -Recurse:$Recurse |
		Select CreatedTime,
		@{N = "Type"; E = {
			if ($_.SourceDatastore.Name -eq $_.Ds.Name) { "vMotion" }else { "svMotion" } }
		},
		@{N = "UserName"; E = { if ($_.UserName) { $_.UserName }else { "System" } } },
		@{N = "VM"; E = { $_.VM.Name } },
		@{N = "SrcVMHost"; E = { $_.SourceHost.Name.Split('.')[0] } },
		@{N = "TgtVMHost"; E = { if ($_.Host.Name -ne $_.SourceHost.Name) { $_.Host.Name.Split('.')[0] } } },
		@{N = "SrcDatastore"; E = { $_.SourceDatastore.Name } },
		@{N = "TgtDatastore"; E = { if ($_.Ds.Name -ne $_.SourceDatastore.Name) { $_.Ds.Name } } }
	}
	end
	{
		if ($Sort)
		{
			$history | Sort-Object -Property CreatedTime
		}
		else
		{
			$history
		}
	}
}

#region "PowerCLI Settings"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DefaultVIServerMode Multiple -DisplayDeprecationWarnings $true -Scope Session -Confirm:$false
#endregion

#region "Custom VIProperty Definitions"
New-VIProperty -Name PercentFree -ObjectType Datastore -Value {
					param($datastore)

					'{0:P0}' -f ($datastore.FreeSpaceMB/$datastore.CapacityMB)
				} -Force

New-VIProperty -Name PercentUsed -ObjectType Datastore -Value {
					param($datastore)

					'{0:P0}' -f (1-($datastore.FreeSpaceMB/$datastore.CapacityMB))
				} -Force

New-VIProperty -Name ProvisionedVMStorageGB -ObjectType Datastore -Value {
					param($datastore)

					'{0:N2}' -f ((get-vm -Datastore $datastore).ProvisionedSpaceGB | Measure-Object -Sum).Sum
				}

New-VIProperty -Name UsedStorageGB -ObjectType Datastore -Value {
                param($datastore)

                [math]::Round($datastore.CapacityGB - $datastore.FreeSpaceGB,2)
}

New-VIProperty -Name OverCommitPercent -ObjectType Datastore -Value {
                    param($datastore)

                    '{0:P0}' -f ($datastore.ProvisionedVMStorageGB / $datastore.CapacityGB)
                }

New-VIProperty -Name OverCommitRatio -ObjectType Datastore -Value {
                    param($datastore)

                	'{0:N2}' -f ($datastore.ProvisionedVMStorageGB / $datastore.CapacityGB)
                }

New-VIProperty -Name RemoteHost -ObjectType Datastore -Value {
					param($datastore)

					$datastore.ExtensionData.Info.Nas.RemoteHost
				} -Force

New-VIProperty -Name vCenter -ObjectType VirtualMachine -Value {
					param($vm)

					return ((($vm.Uid.Split("/")[1] -split("="))[1] -split("@"))[1] -split(":"))[0]
	} -Force

New-VIProperty -Name vCenter -ObjectType VMHost -Value {
					param($vmHost)

					return ((($vmHost.Uid.Split("/")[1] -split("="))[1] -split("@"))[1] -split(":"))[0]
	} -Force

New-VIProperty -Name vCenter -ObjectType Cluster -Value {
		param($cluster)

		return ((($cluster.Uid.Split("/")[1] -split("="))[1] -split("@"))[1] -split(":"))[0]
	} -Force

New-VIProperty -Name vCenter -ObjectType DataCenter -Value {
					param($dataCenter)

					return ((($dataCenter.Uid.Split("/")[1] -split("="))[1] -split("@"))[1] -split(":"))[0]
	} -Force

New-VIProperty -Name vCenter -ObjectType Datastore -Value {
					param($datastore)

					return ((($datastore.Uid.Split("/")[1] -split("="))[1] -split("@"))[1] -split(":"))[0]
	} -Force

New-VIProperty -Name SanLunId -ObjectType Datastore -Value {
					param([VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl]$datastore)

					[string]$lunID = ""

					if($datastore.Type -eq "VMFS")
					{
						$lunID = $datastore.ExtensionData.Info.Vmfs.Extent.DiskName.Substring($datastore.ExtensionData.Info.Vmfs.Extent.DiskName.Length - 4)
					}

					return $lunID
				} -Force | Out-Null

New-VIProperty -Name IOPSRead -ObjectType VirtualMachine -Value {
					param($vm)

					[math]::round((Get-Stat $vm -stat "datastore.numberReadAveraged.average" -RealTime | Select -Expand Value | measure -average).Average, 1)
				} -Force

New-VIProperty -Name IOPSWrite -ObjectType VirtualMachine -Value {
					param($vm)

					[math]::round((Get-Stat $vm -stat "datastore.numberWriteAveraged.average" -RealTime | Select -Expand Value | measure -average).Average, 1)
				} -Force

New-VIProperty -Name ProvisionedStorageGB -ObjectType VirtualMachine -Value {
					param($vm)

					'{0:N2}' -f $([Math]::Round($vm.ProvisionedSpaceGB, 2))
				} -Force

New-VIProperty -Name UsedStorageGB -ObjectType VirtualMachine -Value {
					param($vm)

					#'{0:N2}' -f $([Math]::Round($vm.UsedSpaceGB, 2))
					'{0:N2}' -f [math]::round((($vm.Guest.Disks | measure -Property capacitygb -Sum).Sum - ($vm.Guest.Disks | measure -Property freespacegb -Sum).Sum),2)

				} -Force

New-VIProperty -Name MACAddress -ObjectType VirtualMachine -Value {
					param($vm)

					(Get-NetworkAdapter (Get-vm $vm) | Select-Object MacAddress).MacAddress
				} -Force

New-VIProperty -Name Cluster -ObjectType VirtualMachine -Value {
					param($vm)

					($vm | Select-Object -ExpandProperty VMHost | Select-Object Parent).Parent
				} -Force

New-VIProperty -Name lunID -ObjectType ScsiLun -Value {
					param([VMware.VimAutomation.ViCore.Impl.V1.Host.Storage.Scsi.ScsiLunImpl]$lun)

					[int](Select-String ":L(?<lunID>\d+)$" -InputObject $lun.RuntimeName).Matches[0].Groups['lunID'].Value
				} -Force | Out-Null

New-VIProperty -Name PercentUsedRAM -ObjectType VMHost -Value {
				param($vmhost)

				'{0:P0}' -f ($vmhost.MemoryUsageMB / $vmhost.MemoryTotalMB)
			} -Force

New-VIProperty -Name TotalRamGb -ObjectType Cluster -Value {
					param($cluster)

					[int](($cluster | Get-VMHost | Measure-Object -Property MemoryTotalGB -Sum | Select Sum).Sum)
				} -Force

New-VIProperty -Name UsableRamGb -ObjectType Cluster -Value {
					param($cluster)

					#This is as follows
					#(({AllHostsInClusterRAM - LargestHostInClusterRAM) * {MaxClusterUsage}) - ({HostRAMBuffer} * {CountOfHosts})
					$clusterHosts = $cluster | Get-VMHost
					[Math]::Round(((($clusterHosts | Measure-Object -Property MemoryTotalGB -Sum).Sum - ($clusterHosts | Sort -Descending -Property MemoryTotalGB | Select -First 1 | Select MemoryTotalGB).MemoryTotalGB) * .9) - ($clusterHosts.Count * 3),2)
				} -Force

New-VIProperty -Name TotalCpuMhz -ObjectType Cluster -Value {
					param($cluster)

					[int](($cluster | Get-VMHost | Measure-Object -Property CpuTotalMhz -Sum | Select Sum).Sum)
				} -Force

New-VIProperty -Name UsableCpuMhz -ObjectType Cluster -Value {
					param($cluster)

					[int](($cluster | Get-VMHost | Measure-Object -Property CpuTotalMhz -Sum | Select Sum).Sum - ($cluster | Get-VMHost | Sort -Descending -Property CpuTotalMhz | Select -First 1 | Select CpuTotalMhz).CpuTotalMhz)
				} -Force

New-VIProperty -Name PercentUsedCPU -ObjectType VMHost -Value {
					param($vmhost)

					'{0:P0}' -f ($vmhost.CpuUsageMhz / $vmhost.CpuTotalMhz)
				} -Force

New-VIProperty -Name UsedCpuMhz -ObjectType Cluster -Value {
                    param($cluster)

                    [int]($cluster | Get-VMHost | Measure-Object -Property CpuUsageMhz -Sum | Select Sum).Sum
                } -Force

New-VIProperty -Name PercentUsedCPU -ObjectType Cluster -Value {
					param($cluster)

					'{0:P0}' -f (($cluster | Get-VMHost | Measure-Object -Property CpuUsageMhz -Sum | Select Sum).Sum / $cluster.UsableCpuMhz)
				} -Force

New-VIProperty -Name ProvisionedRamGb -ObjectType Cluster -Value {
					param($cluster)

					[int](($cluster | Get-VM | Where {$_.PowerState -eq "PoweredOn"} | measure -Property MemoryGB -Sum).Sum)
				} -Force -WarningAction SilentlyContinue

New-VIProperty -Name ActualUsageRamGb -ObjectType Cluster -Value {
					param($cluster)

					[int](($cluster | Get-VMHost | Measure-Object -Property MemoryUsageGB -Sum | Select Sum).Sum)
				} -Force

New-VIProperty -Name UsableRemainingRamPercent -ObjectType Cluster -Value {
					param($cluster)

					'{0:P0}' -f ($cluster.RemainingUsableRAMGB / $cluster.UsableRAMGB)
				} -Force

New-VIProperty -Name RAMOverCommitRatio -Object Cluster -Value {
                    param($cluster)

                    '{0:N2}' -f ($cluster.ProvisionedRamGb / $cluster.UsableRamGb)
                }

New-VIProperty -Name RemainingUsableRamGb -ObjectType Cluster -Value {
					param($cluster)

                    $usableGB = ($cluster.UsableRAMGB - $cluster.ProvisionedRAMGB)
                    if($usableGB -le 0)
                    {
					    [Math]::Floor($usableGB)
                    }
                    else
                    {
                        [Math]::Ceiling($usableGB)
                    }
				} -Force

New-VIProperty -Name DatastoreList -ObjectType VirtualMachine -Value {
					param($VirtualMachine)

					($VirtualMachine.ExtensionData.Config.DatastoreUrl | Select Name).Name
				} -ErrorAction SilentlyContinue -Verbose:$false -WarningAction SilentlyContinue

New-VIProperty -ObjectType VMHost -Name AvgRAMUsage24Hr -Value {
                    param($vmHost)

                    "{0:p2}" -f (($vmHost | Get-Stat -Stat mem.usage.average -Start (Get-Date).AddDays(-1) | Measure-Object -Property Value -Average).Average/100)
                } -Force

New-VIProperty -ObjectType Cluster -Name NumPoweredOnVMs -Value {
                    param($cluster)

                    ($cluster | get-vm | Where {$_.PowerState -eq "PoweredOn"} | Measure-Object).Count
                } -Force -WarningAction SilentlyContinue

New-VIProperty -ObjectType VMHost -Name NumPoweredOnVMs -Value {
                    param($vmhost)

                    ($vmhost | get-vm | Where {$_.PowerState -eq "PoweredOn"} | Measure-Object).Count
                } -Force -WarningAction SilentlyContinue

New-VIProperty -ObjectType VIServer -Name NumPoweredOnVms -Value {
                    param($viServer)

                    (get-vm -Server $viServer | Where {$_.PowerState -eq "PoweredOn"} | Measure-Object).Count
                } -Force -WarningAction SilentlyContinue

New-VIProperty -ObjectType VMHost -Name SerialNumber -Value {
					param($viServer)

					(Get-EsxCli -VMHost $viServer).hardware.platform.get().SerialNumber
				} -Force -WarningAction SilentlyContinue

New-VIProperty -Name LastBootTime -ObjectType VirtualMachine -Value {
					param($vm)

					get-stat -Entity $vm -Stat sys.uptime.latest -MaxSamples 1 -Realtime | select @{N="LastBoot";E={(Get-Date).AddSeconds(- $_.value).ToString("MM/dd/yyyy HH:mm:ss")}}
				} -Force
#endregion

#region "Custom Alias definitions"
New-Alias -Name RTFM -Value Get-Help -Description 'Read The Fabulous Manual'
New-Alias -Name Disconnect-vCenter -Value Disconnect-VIServer -Description 'Wrapper for Disconnect-VIServer so we have consistency'
#endregion