function Resolve-RProjInFolder {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath
    )

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        return $null
    }

    $rprojFiles = @(Get-ChildItem -LiteralPath $FolderPath -Filter '*.Rproj' -File -ErrorAction SilentlyContinue)
    if ($rprojFiles.Count -eq 0) {
        return $null
    }

    if ($rprojFiles.Count -eq 1) {
        return $rprojFiles[0].FullName
    }

    $folderLeaf = [System.IO.Path]::GetFileName($FolderPath.TrimEnd('\', '/'))
    $matchingProject = $rprojFiles |
        Where-Object { $_.BaseName -eq $folderLeaf } |
        Select-Object -First 1

    if ($matchingProject) {
        return $matchingProject.FullName
    }

    return ($rprojFiles | Sort-Object Name | Select-Object -First 1).FullName
}
