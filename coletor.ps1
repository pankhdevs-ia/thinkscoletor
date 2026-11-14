$Empresa = if($env:CLI_EMPRESA){ $env:CLI_EMPRESA } else { "Matriz" }
$Setor   = if($env:CLI_SETOR){ $env:CLI_SETOR } else { "TI" }

$WebAppUrl = "https://script.google.com/macros/s/AKfycbz5rMscgiibL3OjlVEm71nxxnLQ65F_YyuQvlY3bJjG7tSgJK5-YJRbYDBTzvjwwEdjZA/exec"

Write-Host "Coletando dados de hardware e rede..." -ForegroundColor Cyan

# 1. Identificação do Sistema
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$enclosure = Get-CimInstance Win32_SystemEnclosure

# Chassis portátil: 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
$notebookTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
$isNotebook = $false
foreach ($type in $enclosure.ChassisTypes) {
    if ($notebookTypes -contains $type) { $isNotebook = $true }
}
$tipoDispositivo = if ($isNotebook) { "Notebook" } else { "Desktop" }
$fabricanteModelo = "$($cs.Manufacturer) $($cs.Model)".Trim()
$serial = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { "SEM-SERIAL-$env:COMPUTERNAME" }

# 2. CPU, RAM e GPU
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()

$os = Get-CimInstance Win32_OperatingSystem
$ramTotalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$ramFreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$ramUsoPct = [math]::Round((($ramTotalGB - $ramFreeGB) / $ramTotalGB) * 100, 1)

$memModules = Get-CimInstance Win32_PhysicalMemory
$ramFreq = ($memModules | Select-Object -First 1).Speed
$smbiosType = ($memModules | Select-Object -First 1).SMBIOSMemoryType
$ramTipo = switch ($smbiosType) {
    24 { "DDR3" }
    26 { "DDR4" }
    34 { "DDR5" }
    default { "Desconhecido ($smbiosType)" }
}

$gpus = (Get-CimInstance Win32_VideoController).Name -join " + "

# 3. Armazenamento e Saúde SMART
$diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$cTotal = [math]::Round($diskC.Size / 1GB, 1)
$cLivre = [math]::Round($diskC.FreeSpace / 1GB, 1)
$cUsado = [math]::Round($cTotal - $cLivre, 1)

$physDisk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 } | Select-Object -First 1
if (-not $physDisk) { $physDisk = Get-PhysicalDisk | Select-Object -First 1 }
$discoFisicoGB = [math]::Round($physDisk.Size / 1GB, 0)

$reliability = $physDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
if ($null -ne $reliability.Wear) {
    $ssdSaude = 100 - $reliability.Wear
    $ssdStatus = if ($ssdSaude -ge 80) { "Saudável ($ssdSaude%)" } elseif ($ssdSaude -ge 50) { "Alerta ($ssdSaude%)" } else { "Crítico ($ssdSaude%)" }
} else {
    $ssdSaude = "N/A"
    $ssdStatus = $physDisk.HealthStatus
}

# 4. Rede e SO
$soNome = "$($os.Caption) ($($os.OSArchitecture))"
$netConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$ip = if ($netConfig) { $netConfig.IPv4Address.IPAddress } else { "Sem IP" }
$mac = if ($netConfig) { $netConfig.NetAdapter.MacAddress } else { "Sem MAC" }

# 5. AnyDesk e TeamViewer
$anydeskId = "Não instalado"
$adPaths = @(
    "$env:ProgramData\AnyDesk\system.conf",
    "$env:APPDATA\AnyDesk\system.conf"
)
foreach ($path in $adPaths) {
    if (Test-Path $path) {
        $match = Select-String -Path $path -Pattern "ad.anynet.id=(\d+)"
        if ($match) {
            $anydeskId = $match.Matches.Groups[1].Value
            break
        }
    }
}

$tvId = "Não instalado"
$tvPaths = @(
    "HKLM:\SOFTWARE\TeamViewer",
    "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"
)
foreach ($reg in $tvPaths) {
    if (Test-Path $reg) {
        $prop = Get-ItemProperty -Path $reg -Name "ClientID" -ErrorAction SilentlyContinue
        if ($prop.ClientID) {
            $tvId = $prop.ClientID
            break
        }
    }
}

# 6. Monta JSON e Envia
$payload = @{
    SerialNumber     = $serial
    Empresa          = $Empresa
    Setor            = $Setor
    Hostname         = $env:COMPUTERNAME
    TipoDispositivo  = $tipoDispositivo
    FabricanteModelo = $fabricanteModelo
    UsuarioAtual     = $env:USERNAME
    CPU              = $cpu
    RAMTotalGB       = $ramTotalGB
    RAMUsoPct        = $ramUsoPct
    RAMFreqMHz       = $ramFreq
    RAMTipo          = $ramTipo
    GPU              = $gpus
    DiscoFisicoGB    = $discoFisicoGB
    C_TotalGB        = $cTotal
    C_UsadoGB        = $cUsado
    C_LivreGB        = $cLivre
    SSDSaudePct      = $ssdSaude
    SSDStatus        = $ssdStatus
    SO               = $soNome
    IP               = $ip
    MAC              = $mac
    AnyDesk          = $anydeskId
    TeamViewer       = $tvId
    DataHora         = (Get-Date -Format "dd/MM/yyyy HH:mm")
} | ConvertTo-Json -Depth 3

try {
    $response = Invoke-RestMethod -Uri $WebAppUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8"
    Write-Host "Sucesso! Equipamento ($serial) sincronizado com a planilha." -ForegroundColor Green
} catch {
    Write-Host "Erro ao enviar dados: $_" -ForegroundColor Red
}
