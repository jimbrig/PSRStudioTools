function Start-RStudioProject {
    <#
    .SYNOPSIS
        Selects and starts an RStudio project from cached RStudio state.
    .DESCRIPTION
        Loads validated RStudio project records, opens an interactive picker,
        finds `rstudio.exe`, and launches the selected `.Rproj` file.
    .PARAMETER UiMode
        Controls whether popup, console, or automatic UI selection is used.
    .PARAMETER ListOnly
        Returns validated project records without opening a picker.
    .PARAMETER PassThru
        Returns launch information instead of starting RStudio.
    .EXAMPLE
        Start-RStudioProject

        Opens the default picker and starts the selected project in RStudio.
    .EXAMPLE
        Start-RStudioProject -ListOnly

        Returns validated project records without opening any UI.
    .EXAMPLE
        Start-RStudioProject -PassThru

        Returns launch details after selection instead of starting RStudio.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([psobject])]
    param(
        [Parameter()]
        [ValidateSet('Auto', 'Popup', 'Console')]
        [string]$UiMode = 'Auto',

        [Parameter()]
        [switch]$ListOnly,

        [Parameter()]
        [switch]$PassThru
    )

    $projects = @(Get-RStudioProject)
    if (-not $projects -or $projects.Count -eq 0) {
        return
    }

    if ($ListOnly) {
        return $projects
    }

    $selectedProject = Select-RStudioProject -Project $projects -UiMode $UiMode
    if (-not $selectedProject) {
        Write-Verbose 'Selection cancelled.'
        return
    }

    $rstudioExecutable = Find-RStudioExecutable
    if (-not $rstudioExecutable) {
        Write-Error 'rstudio.exe not found in PATH or common install locations.'
        return
    }

    if ($PassThru) {
        return [pscustomobject]@{
            PSTypeName  = 'PSRStudioTools.RStudioLaunchInfo'
            RStudioExe  = $rstudioExecutable
            ProjectFile = $selectedProject.ProjectFile
            Project     = $selectedProject
        }
    }

    if ($PSCmdlet.ShouldProcess($selectedProject.ProjectFile, 'Start RStudio project')) {
        Write-Verbose "Starting RStudio with $($selectedProject.ProjectFile)"
        Start-Process -FilePath $rstudioExecutable -ArgumentList "`"$($selectedProject.ProjectFile)`""
    }
}
