# Copyright (c) 2019 AL|EN (alienquake@hotmail.com)

param([Parameter(Mandatory)]$ModTopLevelDirectory)

function Get-IEModVersion {
    param($FilePath)
    $regexVersion = [Regex]::new('.*?VERSION(\s*)(|~"|~|"|)(@.+|.+)("~|"|~|)(|\s*)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($line in [System.IO.File]::ReadLines($FilePath)) {
        $line = $line -replace "\/\/(.*)(\n|)"
        if ($line -match "\S" -and $line -notmatch "\/\*[\s\S]*?\*\/") {
            if ($regexVersion.IsMatch($line)) {
                [string]$dataVersionLine = $regexVersion.Matches($line).Groups[3].Value.ToString().trimStart(' ').trimStart('~').trimStart('"').TrimEnd(' ').TrimEnd('~').TrimEnd('"')
                $dataVersionLine
                break
            }
        }
    }
}

#region Begin

$ModMainFile = try {
    (Get-ChildItem -Path $ModTopLevelDirectory -Recurse -Depth 1 -Include "*.tp2")[0]
} catch {
    Write-Host "Cannot find mod tp2 file."
    Pause
    Exit 1
}

$ModMainFolder = $ModMainFile.Directory.BaseName

$ModID = $ModMainFile.BaseName -replace 'setup-'

$weiduExeBaseName = "Setup-$ModID"

$ModVersion = Get-IEModVersion -FilePath $ModMainFile.FullName
if ($null -eq $ModVersion -or $ModVersion -eq '') {
    Write-Host "Cannot detect VERSION keyword"
    Pause
    Exit 1
} else {
    Write-Host "Version: $ModVersion"
    Write-Host "Version cut: $($ModVersion -replace "\s+", '_')"
}

$iniDataFile = try { Get-ChildItem -Path $ModTopLevelDirectory/$ModMainFolder -Filter $ModID.ini } catch { }
if ($iniDataFile) {
    $iniData = try { Get-Content $iniDataFile -EA 0 } catch { }
}
# workaround for Github release asset name limitation
if ($iniData) {
    $ModDisplayName = ((($iniData | ? { $_ -notlike "^\s+#*" -and $_ -like "Name*=*" }) -split '=') -split '#')[1].TrimStart(' ').TrimEnd(' ')
    $simplePackageBaseName = (($ModDisplayName -replace "\s+", '_') -replace "\W") -replace '_+', '-'
    $simpleVersion = $ModVersion -replace "\s+", '-'
    $PackageBaseName = ($simplePackageBaseName + '-' + $simpleVersion).ToLower()
} else {
    $simplePackageBaseName = (($ModID -replace "\s+", '_') -replace "\W") -replace '_+', '-'
    $simpleVersion = $ModVersion -replace "\s+", '-'
    $PackageBaseName = ($simplePackageBaseName + '-' + $simpleVersion).ToLower()
}
Write-Host "PackageBaseName: $PackageBaseName"

# cleanup old files
Remove-Item -Path "$ModTopLevelDirectory\*.iemod" -Force -EA 0 | Out-Null

$outIEMod = "$ModID-iemod"
$outZip = "$ModID-zip"

# temp dir
if ($PSVersionTable.PSEdition -eq 'Desktop' -or $isWindows) {
    $tempDir = Join-path -Path $env:TEMP -ChildPath (Get-Random)
} else {
    $tempDir = Join-path -Path '/tmp' -ChildPath (Get-Random)
}

Remove-Item $tempDir -Recurse -Force -EA 0 | Out-Null
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir/$outIEMod/$ModMainFolder -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir/$outZip/$ModMainFolder -ItemType Directory -Force | Out-Null

Write-Host "$tempDir/$outIEMod/$ModMainFolder"
Write-Host "$tempDir/$outZip/$ModMainFolder"

#endregion

#region Process

$regexAny = ".*", "*.bak", "*.iemod", "*.tmp", "*.temp", 'backup', 'bgforge.yml', 'Thumbs.db', 'ehthumbs.db', '__macosx', '$RECYCLE.BIN'
$excludedAny = Get-ChildItem -Path $ModTopLevelDirectory/$ModMainFolder -Recurse -Include $regexAny

#iemod package
Copy-Item -Path $ModTopLevelDirectory/$ModMainFolder/* -Destination $tempDir/$outIEMod/$ModMainFolder -Recurse -Exclude $regexAny | Out-Null

Write-Host "Creating $PackageBaseName.iemod" -ForegroundColor Green

# compress iemod package
Compress-Archive -Path $tempDir/$outIEMod/* -DestinationPath "$ModTopLevelDirectory/$PackageBaseName.zip" -Force -CompressionLevel Optimal | Out-Null
Rename-Item -Path "$ModTopLevelDirectory/$PackageBaseName.zip" -NewName "$ModTopLevelDirectory/$PackageBaseName.iemod" -Force | Out-Null

# zip package
Copy-Item -Path $ModTopLevelDirectory/$ModMainFolder/* -Destination $tempDir/$outZip/$ModMainFolder -Recurse -Exclude $regexAny | Out-Null

# get latest weidu version
$datalastRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/weiduorg/weidu/releases/latest" -Method Get
$weiduWinUrl = $datalastRelease.assets | ? name -Match 'Windows' | Select-Object -ExpandProperty browser_download_url
$weiduMacUrl = $datalastRelease.assets | ? name -Match 'Mac' | Select-Object -ExpandProperty browser_download_url

Invoke-WebRequest -Uri $weiduWinUrl -Headers $Headers -OutFile "$tempDir/WeiDU-Windows.zip" -PassThru | Out-Null
Expand-Archive -Path "$tempDir/WeiDU-Windows.zip" -DestinationPath "$tempDir/" | Out-Null

Invoke-WebRequest -Uri $weiduMacUrl -Headers $Headers -OutFile "$tempDir/WeiDU-Mac.zip" -PassThru | Out-Null
Expand-Archive -Path "$tempDir/WeiDU-Mac.zip" -DestinationPath "$tempDir/" | Out-Null

# copy latest WeiDU version
Copy-Item "$tempDir/WeiDU-Windows/bin/amd64/weidu.exe" "$tempDir/$outZip/$weiduExeBaseName.exe" | Out-Null
Copy-Item "$tempDir/WeiDU-Mac/bin/amd64/weidu" "$tempDir/$outZip/$($weiduExeBaseName.tolower())" | Out-Null

# Create .command script
'cd "${0%/*}"' + "`n" + 'ScriptName="${0##*/}"' + "`n" + './${ScriptName%.*}' + "`n" | Set-Content -Path "$tempDir/$outZip/$($weiduExeBaseName.tolower()).command" | Out-Null

Write-Host "Creating $PackageBaseName.zip" -ForegroundColor Green

Compress-Archive -Path $tempDir/$outZip/* -DestinationPath "$ModTopLevelDirectory/$PackageBaseName.zip" -Force -CompressionLevel Optimal | Out-Null

#endregion

#region End

if ($excludedAny) {
    Write-Warning "Excluded items fom the package:"
    $excludedAny.FullName.Substring($ModTopLevelDirectory.length) | Write-Warning
}

Write-Host "Finished." -ForegroundColor Green

#endregion
