function Select-RStudioProject {
    <#
    .SYNOPSIS
        Opens an interactive picker for RStudio projects.
    .DESCRIPTION
        Uses `Out-GridView` when available, then `Out-ConsoleGridView`, then a
        numbered prompt fallback. Returns the selected typed project object.
    .PARAMETER Project
        Project records to display. If omitted, cached projects are loaded.
    .PARAMETER UiMode
        Controls whether popup, console, or automatic UI selection is used.
    .EXAMPLE
        Select-RStudioProject

        Loads cached projects and opens the default interactive picker.
    .EXAMPLE
        Get-RStudioProject | Select-RStudioProject -UiMode Console

        Pipes project records into the console picker explicitly.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(ValueFromPipeline)]
        [psobject[]]$Project,

        [Parameter()]
        [ValidateSet('Auto', 'Popup', 'Console')]
        [string]$UiMode = 'Auto'
    )

    begin {
        $buffer = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in @($Project)) {
            if ($item) {
                $buffer.Add($item)
            }
        }
    }

    end {
        $projects = if ($buffer.Count -gt 0) {
            @($buffer)
        } else {
            @(Get-RStudioProject)
        }

        if (-not $projects -or $projects.Count -eq 0) {
            Write-Warning 'No launchable RStudio projects found.'
            return
        }

        $title = 'Select an RStudio project'
        $usePopup = $false

        switch ($UiMode) {
            'Popup' { $usePopup = $true }
            'Console' { $usePopup = $false }
            default {
                if (Get-Command -Name Out-GridView -ErrorAction SilentlyContinue) {
                    $usePopup = $true
                }
            }
        }

        $displayRows = $projects | Select-Object ProjectName, ProjectPath, LastModified, Source, ProjectFile, ProjectId

        if ($usePopup) {
            $selectedRow = $displayRows | Out-GridView -Title $title -PassThru | Select-Object -First 1
        } elseif (Get-Command -Name Out-ConsoleGridView -ErrorAction SilentlyContinue) {
            Import-Module Microsoft.PowerShell.ConsoleGuiTools -ErrorAction SilentlyContinue
            $selectedRow = $displayRows | Out-ConsoleGridView -Title $title -OutputMode Single
        } else {
            Write-Information $title -InformationAction Continue
            for ($index = 0; $index -lt $projects.Count; $index++) {
                $label = $index + 1
                Write-Information ('  [{0}] {1}  {2}' -f $label, $projects[$index].ProjectName, $projects[$index].ProjectPath) -InformationAction Continue
            }

            $rawSelection = Read-Host 'Enter number (or Enter to cancel)'
            if ([string]::IsNullOrWhiteSpace($rawSelection)) {
                return
            }

            $selectedIndex = 0
            if (-not [int]::TryParse($rawSelection.Trim(), [ref]$selectedIndex)) {
                return
            }

            if ($selectedIndex -lt 1 -or $selectedIndex -gt $projects.Count) {
                return
            }

            return $projects[$selectedIndex - 1]
        }

        if (-not $selectedRow) {
            return
        }

        $selectedProject = $projects | Where-Object { $_.ProjectFile -eq $selectedRow.ProjectFile } | Select-Object -First 1
        if ($selectedProject) {
            return $selectedProject
        }
    }
}
