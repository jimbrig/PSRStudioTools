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

function Add-UserModulePaths {
    [CmdletBinding()]
    param()

    $candidatePaths = @(
        (Join-Path $HOME 'Documents\PowerShell\Modules')
        (Join-Path $HOME 'Documents\WindowsPowerShell\Modules')
    ) | Where-Object { $_ }

    $currentPaths = $env:PSModulePath -split [System.IO.Path]::PathSeparator
    foreach ($candidatePath in $candidatePaths) {
        if ($candidatePath -notin $currentPaths) {
            $env:PSModulePath = $candidatePath + [System.IO.Path]::PathSeparator + $env:PSModulePath
            $currentPaths += $candidatePath
        }
    }
}

function Get-BuildDependencyModulePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$RequiredVersion
    )

    $availableModules = @(Get-Module -Name $Name -ListAvailable | Sort-Object Version -Descending)

    if ($RequiredVersion) {
        $exactMatch = $availableModules | Where-Object { $_.Version -eq ([version]$RequiredVersion) } | Select-Object -First 1
        if ($exactMatch) {
            return $exactMatch.Path
        }
    } elseif ($availableModules) {
        return ($availableModules | Select-Object -First 1).Path
    }

    $moduleSearchRoots = $env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ }
    foreach ($root in $moduleSearchRoots) {
        if ($RequiredVersion) {
            $manifestPath = Join-Path $root "$Name\$RequiredVersion\$Name.psd1"
            if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
                return $manifestPath
            }

            $modulePath = Join-Path $root "$Name\$RequiredVersion\$Name.psm1"
            if (Test-Path -LiteralPath $modulePath -PathType Leaf) {
                return $modulePath
            }
        }
    }

    return $null
}

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

    Add-UserModulePaths

    $installedModules = @(Get-Module -Name $Name -ListAvailable | Sort-Object Version -Descending)
    $installedModule = $installedModules | Select-Object -First 1
    $needsInstall = $true

    if ($requiredVersion) {
        $needsInstall = -not ($installedModules | Where-Object { $_.Version -eq ([version]$requiredVersion) } | Select-Object -First 1)
    } elseif ($installedModule) {
        $needsInstall = $false
    }

    if ($needsInstall) {
        Install-Module @installParams
        Add-UserModulePaths
    }

    $modulePath = Get-BuildDependencyModulePath -Name $Name -RequiredVersion $requiredVersion
    if (-not $modulePath) {
        throw "Unable to locate an importable module for '$Name' after installation."
    }

    Import-Module -Name $modulePath -Force -ErrorAction Stop
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
