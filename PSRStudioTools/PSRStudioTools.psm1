# dot source public/private functions
$classes = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Classes') -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -File -Recurse -ErrorAction Stop)
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -File -Recurse -ErrorAction Stop)

foreach ($import in @($classes + $public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

Export-ModuleMember -Function @($public.BaseName)
