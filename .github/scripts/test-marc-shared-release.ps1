param(
    [Parameter(Mandatory = $true)]
    [string]$FfmpegPath,

    [Parameter(Mandatory = $true)]
    [string]$FfprobePath,

    [Parameter(Mandatory = $true)]
    [string]$WorkDir,

    [Parameter(Mandatory = $true)]
    [string]$RequiredFeaturesPath,

    [Parameter(Mandatory = $true)]
    [string]$FeatureJsonPath,

    [Parameter(Mandatory = $true)]
    [string]$FeatureTextPath,

    [string]$PreviousFfmpegPath,
    [string]$FeatureDiffPath
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE. Arguments: $($Arguments -join ' ')"
    }
}

function Get-CommandOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE. Arguments: $($Arguments -join ' ')"
    }
    return $output
}

function Get-FlaggedNames {
    param(
        [string[]]$Lines,
        [string]$Pattern
    )

    $names = foreach ($line in $Lines) {
        if ($line -match $Pattern) {
            $name = $Matches[1]
            if ($name -and $name -ne '=') {
                $name
            }
        }
    }
    return @($names | Sort-Object -Unique)
}

function Get-SimpleList {
    param(
        [string[]]$Lines,
        [string[]]$HeadersToIgnore
    )

    $names = foreach ($line in $Lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) {
            continue
        }
        if ($HeadersToIgnore -contains $trimmed) {
            continue
        }
        if ($trimmed -match '^[A-Za-z0-9_+.-]+$') {
            $trimmed
        }
    }
    return @($names | Sort-Object -Unique)
}

function Get-FfmpegFeatures {
    param([string]$Executable)

    $encoders = Get-FlaggedNames `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-encoders')) `
        -Pattern '^\s*[VAS]\S{5}\s+(\S+)'

    $decoders = Get-FlaggedNames `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-decoders')) `
        -Pattern '^\s*[VAS]\S{5}\s+(\S+)'

    $filters = Get-FlaggedNames `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-filters')) `
        -Pattern '^\s*[TSC\.]{3}\s+(\S+)'

    $formats = Get-FlaggedNames `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-formats')) `
        -Pattern '^\s*[D ][E ]\s+(\S+)'

    $hwaccels = Get-SimpleList `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-hwaccels')) `
        -HeadersToIgnore @('Hardware acceleration methods:')

    $protocols = Get-SimpleList `
        -Lines (Get-CommandOutput -Executable $Executable -Arguments @('-hide_banner', '-protocols')) `
        -HeadersToIgnore @('Supported file protocols:', 'Input:', 'Output:')

    [ordered]@{
        encoders  = $encoders
        decoders  = $decoders
        filters   = $filters
        formats   = $formats
        hwaccels  = $hwaccels
        protocols = $protocols
    }
}

function Write-FeatureText {
    param(
        [hashtable]$Features,
        [string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($category in @('encoders', 'decoders', 'filters', 'formats', 'hwaccels', 'protocols')) {
        $lines.Add("[$category]")
        foreach ($name in @($Features[$category])) {
            $lines.Add($name)
        }
        $lines.Add('')
    }
    $lines | Set-Content -LiteralPath $Path -Encoding utf8
}

function Assert-RequiredFeatures {
    param(
        [hashtable]$Features,
        [string]$RequiredPath
    )

    $required = Get-Content -Raw -LiteralPath $RequiredPath | ConvertFrom-Json
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($property in $required.PSObject.Properties) {
        $category = $property.Name
        if (-not $Features.Contains($category)) {
            $missing.Add("$category:<category missing>")
            continue
        }

        $available = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($name in @($Features[$category])) {
            [void]$available.Add([string]$name)
        }

        foreach ($name in @($property.Value)) {
            if (-not $available.Contains([string]$name)) {
                $missing.Add("$category:$name")
            }
        }
    }

    if ($missing.Count -gt 0) {
        throw "Required Marc Shared features are missing: $($missing -join ', ')"
    }
}

function Write-FeatureDiff {
    param(
        [hashtable]$Current,
        [hashtable]$Previous,
        [string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($category in @('encoders', 'decoders', 'filters', 'formats', 'hwaccels', 'protocols')) {
        $currentItems = @($Current[$category])
        $previousItems = @($Previous[$category])
        $removed = @(Compare-Object -ReferenceObject $previousItems -DifferenceObject $currentItems -PassThru | Where-Object SideIndicator -eq '<=' | Sort-Object)
        $added = @(Compare-Object -ReferenceObject $previousItems -DifferenceObject $currentItems -PassThru | Where-Object SideIndicator -eq '=>' | Sort-Object)

        $lines.Add("[$category]")
        if ($removed.Count -eq 0 -and $added.Count -eq 0) {
            $lines.Add('No changes')
        }
        else {
            foreach ($name in $removed) {
                $lines.Add("- $name")
                Write-Warning "Feature removed since previous release: $category/$name"
            }
            foreach ($name in $added) {
                $lines.Add("+ $name")
            }
        }
        $lines.Add('')
    }

    $lines | Set-Content -LiteralPath $Path -Encoding utf8
}

function Assert-ProbeCodec {
    param(
        [string]$Path,
        [string]$ExpectedCodec,
        [string]$StreamSelector = 'v:0'
    )

    $codec = (& $FfprobePath -hide_banner -loglevel error -select_streams $StreamSelector -show_entries stream=codec_name -of default=nw=1:nk=1 $Path).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "FFprobe failed for $Path with exit code $LASTEXITCODE."
    }
    if ($codec -ne $ExpectedCodec) {
        throw "Unexpected codec for $Path. Expected '$ExpectedCodec', got '$codec'."
    }
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$FeatureJsonPath = [IO.Path]::GetFullPath($FeatureJsonPath)
$FeatureTextPath = [IO.Path]::GetFullPath($FeatureTextPath)
if ($FeatureDiffPath) {
    $FeatureDiffPath = [IO.Path]::GetFullPath($FeatureDiffPath)
}

Invoke-Checked -Executable $FfmpegPath -Arguments @('-hide_banner', '-version')
Invoke-Checked -Executable $FfprobePath -Arguments @('-hide_banner', '-version')

$currentFeatures = Get-FfmpegFeatures -Executable $FfmpegPath
$currentFeatures | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $FeatureJsonPath -Encoding utf8
Write-FeatureText -Features $currentFeatures -Path $FeatureTextPath
Assert-RequiredFeatures -Features $currentFeatures -RequiredPath $RequiredFeaturesPath

if ($PreviousFfmpegPath -and (Test-Path -LiteralPath $PreviousFfmpegPath) -and $FeatureDiffPath) {
    $previousFeatures = Get-FfmpegFeatures -Executable $PreviousFfmpegPath
    Write-FeatureDiff -Current $currentFeatures -Previous $previousFeatures -Path $FeatureDiffPath
}
elseif ($FeatureDiffPath) {
    'No previous Marc Shared release was available for comparison.' | Set-Content -LiteralPath $FeatureDiffPath -Encoding utf8
}

Push-Location $WorkDir
try {
    $png = Join-Path $WorkDir 'smoke.png'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc=size=128x72:rate=1',
        '-frames:v', '1', '-y', $png
    )
    Assert-ProbeCodec -Path $png -ExpectedCodec 'png'

    $h264 = Join-Path $WorkDir 'smoke-h264.mkv'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=30',
        '-t', '0.5', '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p', '-y', $h264
    )
    Assert-ProbeCodec -Path $h264 -ExpectedCodec 'h264'

    $hevc = Join-Path $WorkDir 'smoke-hevc.mkv'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=30',
        '-t', '0.5', '-c:v', 'libx265', '-preset', 'ultrafast', '-x265-params', 'log-level=error', '-pix_fmt', 'yuv420p', '-y', $hevc
    )
    Assert-ProbeCodec -Path $hevc -ExpectedCodec 'hevc'

    $av1 = Join-Path $WorkDir 'smoke-av1.mkv'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24',
        '-t', '0.5', '-c:v', 'libsvtav1', '-preset', '12', '-crf', '50', '-pix_fmt', 'yuv420p', '-y', $av1
    )
    Assert-ProbeCodec -Path $av1 -ExpectedCodec 'av1'

    $opus = Join-Path $WorkDir 'smoke-opus.ogg'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=0.5',
        '-c:a', 'libopus', '-b:a', '64k', '-y', $opus
    )
    Assert-ProbeCodec -Path $opus -ExpectedCodec 'opus' -StreamSelector 'a:0'

    $flac = Join-Path $WorkDir 'smoke.flac'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.5',
        '-c:a', 'flac', '-y', $flac
    )
    Assert-ProbeCodec -Path $flac -ExpectedCodec 'flac' -StreamSelector 'a:0'

    $remux = Join-Path $WorkDir 'smoke-remux.mp4'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error', '-i', $h264, '-c', 'copy', '-y', $remux
    )
    Assert-ProbeCodec -Path $remux -ExpectedCodec 'h264'

    $subtitle = Join-Path $WorkDir 'smoke.srt'
    @"
1
00:00:00,000 --> 00:00:01,000
Marc Shared subtitle smoke test
"@ | Set-Content -LiteralPath $subtitle -Encoding utf8

    $subtitlePng = Join-Path $WorkDir 'smoke-subtitles.png'
    Invoke-Checked -Executable $FfmpegPath -Arguments @(
        '-hide_banner', '-loglevel', 'error',
        '-f', 'lavfi', '-i', 'color=c=black:s=320x180:d=1',
        '-vf', 'subtitles=smoke.srt', '-frames:v', '1', '-y', $subtitlePng
    )
    Assert-ProbeCodec -Path $subtitlePng -ExpectedCodec 'png'
}
finally {
    Pop-Location
}

Write-Host 'Marc Shared runtime smoke tests and required-feature checks passed.'
