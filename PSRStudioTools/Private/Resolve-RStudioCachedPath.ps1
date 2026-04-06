function Resolve-RStudioCachedPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$RawPath
    )

    if ([string]::IsNullOrWhiteSpace($RawPath)) {
        return $null
    }

    $resolvedPath = Resolve-Path -Path $RawPath.Trim() -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty ProviderPath

    if ($resolvedPath) {
        return $resolvedPath
    }

    return $null
}
