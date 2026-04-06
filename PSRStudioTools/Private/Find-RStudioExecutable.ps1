function Find-RStudioExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $command = Get-Command -Name rstudio.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    $candidates = @()

    if ($Env:ProgramFiles) {
        $candidates += (Join-Path $Env:ProgramFiles 'RStudio\rstudio.exe')
    }

    if ($programFilesX86) {
        $candidates += (Join-Path $programFilesX86 'RStudio\rstudio.exe')
    }

    if ($Env:LOCALAPPDATA) {
        $candidates += (Join-Path $Env:LOCALAPPDATA 'Programs\RStudio\rstudio.exe')
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}
