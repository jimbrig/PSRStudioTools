# PSRStudioTools

Small PowerShell script module for working with cached RStudio project state.

## Overview

The module currently provides three commands:

- `Get-RStudioProject` reads cached RStudio AppData files and returns validated typed project objects.
- `Select-RStudioProject` opens an interactive picker and returns the selected project.
- `Start-RStudioProject` launches the selected `.Rproj` file in RStudio.

## Import

```pwsh
Import-Module .\Source\Modules\PSRStudioTools\PSRStudioTools\PSRStudioTools.psd1 -Force
```

## Examples

```pwsh
Get-RStudioProject
```

```pwsh
Start-RStudioProject
```

```pwsh
Start-RStudioProject -ListOnly
```

