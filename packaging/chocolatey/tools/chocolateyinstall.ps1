$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName   = 'scottimizer'
  unzipLocation = $toolsDir
  url           = 'https://github.com/SCOTTYinCntrl/Scottimizer/releases/download/v2.1.2/Scottimizer-Advanced.zip'
  checksum      = '297240AEB5FA8001FAE700327CC2064BE7285F865870E9DEFDFABF1C9A3B291B'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Scottimizer is a GUI app; expose it on PATH and the Start Menu.
$exe = Join-Path $toolsDir 'Scottimizer.exe'
if (Test-Path -LiteralPath $exe) {
  Install-BinFile -Name 'scottimizer' -Path $exe
  $menu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
  if (Test-Path -LiteralPath $menu) {
    Install-ChocolateyShortcut -ShortcutFilePath (Join-Path $menu 'Scottimizer.lnk') `
      -TargetPath $exe -WorkingDirectory $toolsDir -IconLocation $exe
  }
}