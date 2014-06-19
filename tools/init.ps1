param($installPath, $toolsPath, $package)
$templatesPath = Join-Path $toolsPath "templates"
$solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
$solutionFile = (Get-Item $solution.FileName)
$solutionDir = $solutionFile.Directory

Write-Host Installing Ciao templates from $toolsPath to $solutionDir

$propsPath = Join-Path $solutionDir "Ciao.props"

if (-Not(Test-Path $propsPath)) {
    (Get-Content (Join-Path $templatesPath "Ciao.props")).replace('REPLACE_ME_IN_Ciao.props_PLEASE.sln', $solutionFile.Name) | Set-Content $propsPath
    Copy-Item (Join-Path $templatesPath "Ciao.targets") $solutionDir
}

# Always overwrite:
Copy-Item (Join-Path $templatesPath "Ciao.proj") $solutionDir

$folder = $solution.Projects | Where-Object {$_.ProjectName -eq "Ciao"}

if ($folder -eq $null) {
    $folder = $solution.AddSolutionFolder("Ciao")
}

$folder.ProjectItems.AddFromFile((Join-Path $solutionDir "Ciao.proj"))
$folder.ProjectItems.AddFromFile((Join-Path $solutionDir "Ciao.props"))

if (Test-Path (Join-Path $solutionDir "Ciao.targets")) {
    $folder.ProjectItems.AddFromFile((Join-Path $solutionDir "Ciao.targets"))
}