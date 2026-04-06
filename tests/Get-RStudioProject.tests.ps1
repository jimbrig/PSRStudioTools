BeforeAll {
    $moduleName = $env:BHProjectName
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$moduleName.psd1"

    Get-Module $moduleName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Force -ErrorAction Stop
}

Describe 'Get-RStudioProject' {
    BeforeAll {
        $testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("PSRStudioTools-" + [guid]::NewGuid().Guid)
        $projectsSettings = Join-Path -Path $testRoot -ChildPath 'projects_settings'
        $monitoredLists = Join-Path -Path $testRoot -ChildPath 'monitored/lists'
        $mappedProjectDir = Join-Path -Path $testRoot -ChildPath 'mapped-project'
        $mruProjectDir = Join-Path -Path $testRoot -ChildPath 'mru-project'
        $staleProjectDir = Join-Path -Path $testRoot -ChildPath 'stale-project'

        $null = New-Item -ItemType Directory -Path $projectsSettings -Force
        $null = New-Item -ItemType Directory -Path $monitoredLists -Force
        $null = New-Item -ItemType Directory -Path $mappedProjectDir -Force
        $null = New-Item -ItemType Directory -Path $mruProjectDir -Force

        $mappedProjectFile = Join-Path -Path $mappedProjectDir -ChildPath 'mapped-project.Rproj'
        $mruProjectFile = Join-Path -Path $mruProjectDir -ChildPath 'mru-project.Rproj'
        Set-Content -Path $mappedProjectFile -Value 'Version: 1.0' -Encoding utf8
        Set-Content -Path $mruProjectFile -Value 'Version: 1.0' -Encoding utf8

        $mappingsFile = Join-Path -Path $projectsSettings -ChildPath 'project-id-mappings'
        $mruFile = Join-Path -Path $monitoredLists -ChildPath 'project_mru'

        @(
            "mapped001=""$mappedProjectDir"""
            "stale001=""$staleProjectDir"""
            'blank001=""'
        ) | Set-Content -Path $mappingsFile -Encoding utf8

        @(
            $mappedProjectFile
            $mruProjectFile
        ) | Set-Content -Path $mruFile -Encoding utf8
    }

    AfterAll {
        if (Test-Path -LiteralPath $testRoot) {
            Remove-Item -LiteralPath $testRoot -Recurse -Force
        }
    }

    It 'returns only validated launchable projects' {
        $projects = @(Get-RStudioProject -RStudioAppData $testRoot)
        $projects.Count | Should -Be 2
    }

    It 'returns typed project records' {
        $project = Get-RStudioProject -RStudioAppData $testRoot | Select-Object -First 1
        $project.PSObject.TypeNames | Should -Contain 'PSRStudioTools.RStudioProject'
    }

    It 'keeps the mapped source when the same project also appears in MRU' {
        $mapped = Get-RStudioProject -RStudioAppData $testRoot |
            Where-Object { $_.ProjectName -eq 'mapped-project' } |
            Select-Object -First 1

        $mapped.Source | Should -Be 'project-id-mappings'
        $mapped.ProjectId | Should -Be 'mapped001'
    }
}
