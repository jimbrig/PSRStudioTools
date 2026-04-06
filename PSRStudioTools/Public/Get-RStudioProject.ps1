function Get-RStudioProject {
    <#
    .SYNOPSIS
        Reads RStudio cached AppData and returns validated project records.
    .DESCRIPTION
        Parses RStudio cache files under `%LOCALAPPDATA%\RStudio`, resolves only
        existing paths, filters to launchable `.Rproj` files, and returns typed
        project objects suitable for future formatting or tooling.
    .PARAMETER RStudioAppData
        Optional override for the RStudio AppData root.
    .EXAMPLE
        Get-RStudioProject

        Returns validated RStudio project records from the default cache location.
    .EXAMPLE
        Get-RStudioProject -RStudioAppData 'C:\Temp\RStudio'

        Uses a custom cache root, which is useful for testing.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter()]
        [string]$RStudioAppData = (Join-Path $Env:LOCALAPPDATA 'RStudio')
    )

    if (-not (Test-Path -LiteralPath $RStudioAppData -PathType Container)) {
        Write-Error "RStudio AppData folder not found: $RStudioAppData"
        return
    }

    $mappingsFile = Join-Path $RStudioAppData 'projects_settings\project-id-mappings'
    $mruFile = Join-Path $RStudioAppData 'monitored\lists\project_mru'

    if (-not (Test-Path -LiteralPath $mappingsFile -PathType Leaf)) {
        Write-Error "RStudio projects file not found: $mappingsFile"
        return
    }

    $projectsByFile = [ordered]@{}

    Get-Content -LiteralPath $mappingsFile -ErrorAction Stop | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            return
        }

        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -lt 1) {
            return
        }

        $projectId = $line.Substring(0, $separatorIndex).Trim()
        $cachedPath = $line.Substring($separatorIndex + 1).Trim().Trim('"')
        $folderPath = Resolve-RStudioCachedPath -RawPath $cachedPath
        if (-not $folderPath) {
            return
        }

        $projectFile = Resolve-RProjInFolder -FolderPath $folderPath
        if (-not $projectFile) {
            return
        }

        $projectKey = $projectFile.ToLowerInvariant()
        if ($projectsByFile.Contains($projectKey)) {
            return
        }

        $projectsByFile[$projectKey] = ConvertTo-RStudioProjectRecord `
            -ProjectId $projectId `
            -ProjectFile $projectFile `
            -Source 'project-id-mappings'
    }

    if (Test-Path -LiteralPath $mruFile -PathType Leaf) {
        Get-Content -LiteralPath $mruFile -ErrorAction SilentlyContinue | ForEach-Object {
            $line = $_.Trim()
            if ([string]::IsNullOrWhiteSpace($line)) {
                return
            }

            $projectFile = Resolve-RStudioCachedPath -RawPath $line
            if (-not $projectFile -or $projectFile -notmatch '\.[Rr]proj$') {
                return
            }

            $projectKey = $projectFile.ToLowerInvariant()
            if ($projectsByFile.Contains($projectKey)) {
                return
            }

            $projectsByFile[$projectKey] = ConvertTo-RStudioProjectRecord `
                -ProjectFile $projectFile `
                -Source 'project_mru'
        }
    }

    $projectsByFile.Values |
        Sort-Object -Property @{ Expression = 'LastModified'; Descending = $true }, ProjectName
}
