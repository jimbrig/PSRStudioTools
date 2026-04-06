function ConvertTo-RStudioProjectRecord {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$ProjectId,

        [Parameter(Mandatory)]
        [string]$ProjectFile,

        [Parameter(Mandatory)]
        [string]$Source
    )

    $projectItem = Get-Item -LiteralPath $ProjectFile -ErrorAction SilentlyContinue

    [pscustomobject]@{
        PSTypeName   = 'PSRStudioTools.RStudioProject'
        ProjectId    = $ProjectId
        ProjectName  = [System.IO.Path]::GetFileNameWithoutExtension($ProjectFile)
        ProjectPath  = [System.IO.Path]::GetDirectoryName($ProjectFile)
        ProjectFile  = $ProjectFile
        LastModified = if ($projectItem) { $projectItem.LastWriteTime } else { $null }
        Source       = $Source
    }
}
