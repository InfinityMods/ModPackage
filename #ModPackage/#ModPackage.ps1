param($ModTopDirectory)

function Get-IEModVersion ($Path) {
    $regexVersion = [Regex]::new('.*?VERSION(\s*)(|~"|~|"|)(@.+|.+)("~|"|~|)(|\s*)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
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

function New-UniversalModPackage {
    [CmdletBinding()]
    param ($ModTopDirectory)

    begin {

        $ModMainFile = (Get-ChildItem -Path $ModTopDirectory -Recurse -Depth 1 -Include "*.tp2", "*.tp3")[0]
        $ModID = $ModMainFile.BaseName -replace 'setup-'

        $weiduExeBaseName = "Setup-$ModID"

        $ModVersion = Get-IEModVersion -Path $ModMainFile.FullName
        if ($null -eq $ModVersion -or $ModVersion -eq '') { $ModVersion = '0.0.0' }

        $PackageBaseName = "$ModID-$ModVersion"

        # cleanup old files
        Remove-Item -Path "$ModTopDirectory\*.iemod" -Force -EA 0 | Out-Null

        $outIEMod = "$ModID-iemod"
        $outZip = "$ModID-zip"

        # temp dir
        if ($PSVersionTable.PSEdition -eq 'Desktop' -or $isWindows) {
            $tempDir = Join-path -Path $env:TEMP -ChildPath (Get-Random)
        } else {
            $tempDir = Join-path -Path '/tmp' -ChildPath (Get-Random)
        }

        Remove-Item $tempDir -Recurse -Force -EA 0 | Out-Null
        New-Item -Path $tempDir\$outIEMod\$ModID -ItemType Directory  -Force | Out-Null
        New-Item -Path $tempDir\$outZip\$ModID -ItemType Directory  -Force | Out-Null

    }
    process {
        $regexAny = ".*", "*.7z", "*.bak", "*.bat", "*.iemod", "*.rar", "*.tar*", "*.tmp", "*.temp", "*.zip", 'backup', 'bgforge.ini', 'Thumbs.db', 'ehthumbs.db', '__macosx', '$RECYCLE.BIN'
        $excludedAny = Get-ChildItem -Path $ModTopDirectory\$ModID -Recurse -Include $regexAny

        #iemod package
        Copy-Item -Path $ModTopDirectory\$ModID\* -Destination $tempDir\$outIEMod\$ModID -Recurse -Exclude $regexAny | Out-Null

        Write-Host "Creating $PackageBaseName.iemod" -ForegroundColor Green

        Compress-Archive -Path $tempDir\$outIEMod\* -DestinationPath "$ModTopDirectory\$PackageBaseName.zip" -Force -CompressionLevel Optimal | Out-Null
        Rename-Item -Path "$ModTopDirectory\$PackageBaseName.zip" -NewName "$PackageBaseName.iemod" -Force | Out-Null

        # zip package
        Copy-Item -Path $ModTopDirectory\$ModID\* -Destination $tempDir\$outZip\$ModID -Recurse -Exclude $regexAny | Out-Null

        # Copy-Item over latest WeiDU versions
        Copy-Item "$PSScriptRoot\weidu\weidu.exe" "$tempDir\$outZip\$weiduExeBaseName.exe" | Out-Null
        Copy-Item "$PSScriptRoot\weidu\weidu.mac" "$tempDir\$outZip\$($weiduExeBaseName.tolower())" | Out-Null

        # Copy-Item over weidu.command script
        Copy-Item "$PSScriptRoot\weidu\weidu.command" "$tempDir\$outZip\$($weiduExeBaseName.tolower()).command" | Out-Null

        Write-Host "Creating $PackageBaseName.zip" -ForegroundColor Green

        Compress-Archive -Path $tempDir\$outZip\* -DestinationPath "$ModTopDirectory\$PackageBaseName.zip" -Force -CompressionLevel Optimal | Out-Null
    }
    end {
        if ($excludedAny) {
            Write-Warning "Excluded items fom the package:"
            $excludedAny.FullName.Substring($ModTopDirectory.length) | Write-Warning
            pause
        }
    }
}

New-UniversalModPackage -ModTopDirectory $ModTopDirectory

Write-Host "Finished." -ForegroundColor Green
