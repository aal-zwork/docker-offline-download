param (
    [string]$Cstring = '',
    [string]$Image = '',
    [string]$Tag = '',
    [string]$Digest = '',
    [switch]$Verbose
)
$registryBase='https://registry-1.docker.io'
$authBase='https://auth.docker.io'
$authService='registry.docker.io'

$ErrorActionPreference = "stop"
[System.Net.ServicePointManager]::Expect100Continue = $true;
[System.Net.ServicePointManager]::SecurityProtocol=[System.Net.SecurityProtocolType]::Tls12


function usage {
    write-host "Save docker image``s layers in current directory" 
    write-host
    write-host "usage: docker-offline-download.ps1 -Cstring <image>[:<tag>[@digest]]>"
    write-host "       docker-offline-download.ps1 -Image <image> [-Tag <tag> [-Digest <digest>]]"
    write-host "       docker-offline-download.psq "
    exit
}
function get-webresponce ($url, $headers=$null, $file=$null) {
    Write-Verbose "url:   $url"
    $wc = new-object system.net.WebClient
    try {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $wc.proxy = $proxy
    }
    catch {}
    if ($headers -ne $null) { foreach ($h in $headers.keys) { $wc.Headers.add($h, $headers[$h]) } }
    if ($file -eq $null) { return $wc.DownloadString($url) }
    else { return $wc.DownloadFile($url, $file) }
}


if($verbose) {
    $oldverbose = $VerbosePreference
    $VerbosePreference = "continue"
}
switch ($PSVersionTable.PSVersion.Major) {
    2 { 
        $PSScriptRoot = ($MyInvocation.MyCommand.Path | Split-Path -Parent)
        function ConvertTo-Json20([object] $item){
            add-type -assembly system.web.extensions
            $ps_js=new-object system.web.script.serialization.javascriptSerializer
            return $ps_js.Serialize($item)
        }

        function ConvertFrom-Json20([object] $item){ 
            add-type -assembly system.web.extensions
            $ps_js=new-object system.web.script.serialization.javascriptSerializer
            return ,$ps_js.DeserializeObject($item)
        }
    }
    3 { write-host "CurVersion is not allowed"; exit }
    4 { write-host "CurVersion is not allowed"; exit }
    5 { 
        
    }
    Default { write-host "CurVersion is not allowed"; exit }
}
$currPath = (Get-Item -Path ".\").FullName
Write-Verbose "currPath:   $currPath"

if ($Cstring -eq '') {
    if ($Image -eq '') { usage }
    else { 
        $Cstring = "$Image"
        if ($Tag -ne '') { 
            $Cstring += ":$Tag"
            if ($Digest -ne '') { $Cstring += "@$Digest" }
        }
        if ($Digest -ne '') { usage }
    }
} else {
    $Cstring_slpit = $Cstring -split '@'
    $Digest = $Cstring_slpit[1]
    $Cstring_slpit = ($Cstring_slpit[0] -split ':')
    $Image = $Cstring_slpit[0]
    $Tag = $Cstring_slpit[1]
    
}
$tmp = (-not ($Image -match ".*/.*")) -and ($Image = "library/$Image")
$ImageFile = $Image -replace '/','_'

Write-Verbose "Cstring:   $Cstring"
Write-Verbose "Image:     $Image"
if ($Tag -eq '') { $Tag = 'latest' }
Write-Verbose "Tag:       $Tag"
if ($Digest -ne '') { Write-Verbose "Digest:    $Digest" }
Write-Verbose "ImageFile: $ImageFile"
$token_responce = get-webresponce "$authBase/token?service=$authService&scope=repository:$($Image):pull" 
#if ($token_responce -eq '') { write-host "Can``t get docker image``s info, check docker image name"; exit }
$token = (ConvertFrom-Json ($token_responce)).token
if ($Digest -eq '') { $req = $Tag } else { $req = $Digest }
$manifest = ConvertFrom-Json ( get-webresponce -url "$registryBase/v2/$Image/manifests/$req" -headers @{'Authorization' = "Bearer $token"} )
$schemaVersion = $manifest.schemaVersion
Write-Verbose "schemaVersion:`t$schemaVersion"
switch ($schemaVersion) {
    1 {
        $layersFs = $manifest.fsLayers.blobSum
        $history = $manifest.history.v1Compatibility
        for ($i=0; $i -lt $layersFs.count; $i++) {
            $imageJson = $history[$i]
            $imageLayerID = (ConvertFrom-Json $imageJson).id
            $imageLayerBlobDigest =  $layersFs[$i]
            #$currDir = join-path $currPath $imageLayerID
            #$tmp = new-item -ItemType Directory $currDir -force 
            #echo $imageJson > (join-path $currDir 'json')
            #$imageLayerPath = join-path $currDir 'layer.tar'
            $imageLayerPath = join-path $currPath "$imageLayerID.gz"
            if (test-path $imageLayerPath) {
                write-host "Skip $imageLayerID, allready downloaded"
            } else {
                write-verbose "imageLayerPath : $imageLayerPath"
                $token = (ConvertFrom-Json (get-webresponce "$authBase/token?service=$authService&scope=repository:$($Image):pull")).token
                $blob = get-webresponce -url "$registryBase/v2/$Image/blobs/$imageLayerBlobDigest" -headers @{'Authorization' = "Bearer $token"} -file $imageLayerPath
            }
        }
    }
    Default { write-host "schemaVersion $schemaVersion is not allowed"; exit }
}

$VerbosePreference = $oldverbose
#return $manifest
































