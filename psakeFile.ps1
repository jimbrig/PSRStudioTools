param(
    [pscredential]$PSGalleryApiKey
)

properties {
    $moduleName = 'PSRStudioTools'
    $moduleRoot = Join-Path $PSScriptRoot $moduleName
    $manifestPath = Join-Path $moduleRoot "$moduleName.psd1"
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $outputRoot = Join-Path $PSScriptRoot 'Output'
    $releaseRoot = Join-Path $outputRoot $moduleName
    $releasePath = Join-Path $releaseRoot $manifest.ModuleVersion
    $testResultsPath = Join-Path $PSScriptRoot 'out/testResults.xml'
}

task Default -depends Test

task Clean {
    Remove-Item -Path $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $PSScriptRoot 'out') -Recurse -Force -ErrorAction SilentlyContinue
}

task Stage -depends Clean {
    $null = New-Item -Path $releaseRoot -ItemType Directory -Force
    Copy-Item -Path $moduleRoot -Destination $releasePath -Recurse -Force
    $null = New-Item -Path (Split-Path -Path $testResultsPath -Parent) -ItemType Directory -Force
}

task Analyze {
    $analysis = Invoke-ScriptAnalyzer -Path $moduleRoot -Recurse -Severity Error, Warning
    if ($analysis) {
        $analysis | Format-Table -AutoSize | Out-String | Write-Host
        throw 'PSScriptAnalyzer reported issues.'
    }
}

task Test -depends Stage, Analyze {
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = (Join-Path $PSScriptRoot 'tests')
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputFormat = 'NUnit2.5'
    $pesterConfig.TestResult.OutputPath = $testResultsPath
    $pesterConfig.Output.Verbosity = 'Detailed'
    $testResults = Invoke-Pester -Configuration $pesterConfig
    if ($testResults.FailedCount -gt 0) {
        throw "$($testResults.FailedCount) Pester test(s) failed."
    }
}

task Publish -depends Test {
    if (-not $PSGalleryApiKey) {
        throw 'PSGalleryApiKey is required for the Publish task.'
    }

    $apiKey = $PSGalleryApiKey.GetNetworkCredential().Password
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'PSGalleryApiKey did not contain a usable API key.'
    }

    Publish-Module -Path $releasePath -NuGetApiKey $apiKey -Repository PSGallery -Force
}
