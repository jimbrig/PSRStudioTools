[cmdletbinding(DefaultParameterSetName = 'Task')]
param(
    # Build task(s) to execute
    [parameter(ParameterSetName = 'task', position = 0)]
    [ArgumentCompleter( {
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        $psakeFile = './psakeFile.ps1'
        switch ($Parameter) {
            'Task' {
                if ([string]::IsNullOrEmpty($WordToComplete)) {
                    Get-PSakeScriptTasks -buildFile $psakeFile | Select-Object -ExpandProperty Name
                }
                else {
                    Get-PSakeScriptTasks -buildFile $psakeFile |
                        Where-Object { $_.Name -match $WordToComplete } |
                        Select-Object -ExpandProperty Name
                }
            }
            Default {
            }
        }
    })]
    [string[]]$Task = 'default',

    # Bootstrap dependencies
    [switch]$Bootstrap,

    # List available build tasks
    [parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    # Optional properties to pass to psake
    [hashtable]$Properties,

    # Optional parameters to pass to psake
    [hashtable]$Parameters,

    # Optional PowerShell Gallery credential wrapper for publish tasks
    [pscredential]$PSGalleryApiKey
)

$ErrorActionPreference = 'Stop'

function Install-BuildDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [hashtable]$Definition
    )

    $requiredVersion = $Definition.Version
    $installParams = @{
        Name         = $Name
        Repository   = 'PSGallery'
        Scope        = 'CurrentUser'
        Force        = $true
        AllowClobber = $true
        ErrorAction  = 'Stop'
    }

    if ($requiredVersion) {
        $installParams.RequiredVersion = [string]$requiredVersion
    }

    $installedModule = Get-Module -Name $Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    $needsInstall = $true

    if ($installedModule) {
        if ($requiredVersion) {
            $needsInstall = ($installedModule.Version -lt ([version]$requiredVersion))
        } else {
            $needsInstall = $false
        }
    }

    if ($needsInstall) {
        Install-Module @installParams
    }

    $importParams = @{
        Name        = $Name
        Force       = $true
        ErrorAction = 'Stop'
    }

    if ($requiredVersion) {
        $importParams.RequiredVersion = [string]$requiredVersion
    }

    Import-Module @importParams
}

# Bootstrap dependencies
if ($Bootstrap.IsPresent) {
    Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if ((Test-Path -Path ./requirements.psd1)) {
        $requirements = Import-PowerShellDataFile -Path ./requirements.psd1
        foreach ($dependencyName in $requirements.Keys) {
            if ($dependencyName -in @('PSDepend', 'PSDependOptions')) {
                continue
            }

            Install-BuildDependency -Name $dependencyName -Definition $requirements[$dependencyName]
        }
    } else {
        Write-Warning 'No [requirements.psd1] found. Skipping build dependency installation.'
    }
}

# Execute psake task(s)
$psakeFile = './psakeFile.ps1'
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-PSakeScriptTasks -buildFile $psakeFile |
        Format-Table -Property Name, Description, Alias, DependsOn
} else {
    $psakeParameters = @{}
    if ($Parameters) {
        foreach ($key in $Parameters.Keys) {
            $psakeParameters[$key] = $Parameters[$key]
        }
    }
    if ($PSBoundParameters.ContainsKey('PSGalleryApiKey')) {
        $psakeParameters.PSGalleryApiKey = $PSGalleryApiKey
    }

    Set-BuildEnvironment -Force
    Invoke-psake -buildFile $psakeFile -taskList $Task -nologo -properties $Properties -parameters $psakeParameters
    exit ([int](-not $psake.build_success))
}
