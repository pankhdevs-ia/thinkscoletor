# URL do seu Web App do Google Apps Script
$urlApp = "https://script.google.com/macros/s/AKfycbz_uqXcvuwSuu_iMsSGRCaotDvpGr2aKIflev5Kk2Y0KKu8Vfr6Bg60BIQj-DBMDo0jUw/exec"

param (
    [string]$empresa = "Matriz",
    [string]$setor = "TI"
)

# Coleta de Dados
$computador = $env:COMPUTERNAME
$usuario = $env:USERNAME
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$enclosure = Get-CimInstance Win32_SystemEnclosure

$fabricanteModelo = "$($cs.Manufacturer) $($cs.Model)".Trim()
$serialNumber = if ($bios.SerialNumber) { $bios.SerialNumber.Trim() } else { "N/A" }

$chassisNotebook = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
$tipoDispositivo = if ($enclosure.ChassisTypes | Where-Object { $_ -in $chassisNotebook }) { "Notebook" } else { "Desktop" }

$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join " + "

$os = Get-CimInstance Win32_OperatingSystem
$ramTotalGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$ramUso = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)

$ramModulos = Get-CimInstance Win32_PhysicalMemory
$ramFreq = ($ramModulos | Select-Object -First 1).Speed
$ramTipoCod = ($ramModulos | Select-Object -First 1).SMBIOSMemoryType
$ramTipo = switch ($ramTipoCod) { 24 { "DDR3" } 26 { "DDR4" } 34 { "DDR5" } default { "RAM" } }
$ramDetalhes = "$ramTotalGB GB ($ramFreq MHz / $ramTipo)"

$discoC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$discoTotalGB = [Math]::Round($discoC.Size / 1GB, 1)
$discoLivreGB = [Math]::Round($discoC.FreeSpace / 1GB, 1)
$discoUsadoGB = [Math]::Round($discoTotalGB - $discoLivreGB, 1)

$discoFisico = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
$tamanhoSsdGB = [Math]::Round($discoFisico.Size / 1GB, 0)
$tamanhoSsdStr = "$tamanhoSsdGB GB"

$saudeSsd = "Normal / Saudável"
try {
    $discoWin = Get-PhysicalDisk | Select-Object -First 1
    $smart = $discoWin | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($smart -and $null -ne $smart.Wear) {
        $porcentagemSaude = 100 - $smart.Wear
        $saudeSsd = "$porcentagemSaude% ($($discoWin.HealthStatus))"
    } elseif ($discoWin) {
        $saudeSsd = "$($discoWin.HealthStatus) ($($discoWin.OperationalStatus))"
    }
} catch {
    $saudeSsd = "Não foi possível ler SMART"
}

$sistemaOperacional = "$($os.Caption) ($($os.OSArchitecture))".Trim()
$net = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$ip = if ($net) { $net.IPv4Address.IPAddress } else { "Sem IP" }
$mac = if ($net) { $net.NetAdapter.MacAddress } else { (Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | Select-Object -First 1).MACAddress }
$redeInfo = "$ip | MAC: $mac"

$anydeskId = "Não instalado"
$caminhosAny = @("C:\ProgramData\AnyDesk\system.conf", "$env:APPDATA\AnyDesk\system.conf")
foreach ($caminho in $caminhosAny) {
    if (Test-Path $caminho) {
        $conteudoAny = Get-Content $caminho -ErrorAction SilentlyContinue
        $linhaId = $conteudoAny | Where-Object { $_ -match "^ad\.(anynet|anydesk)\.id=" } | Select-Object -First 1
        if ($linhaId) { 
            $anydeskId = $linhaId.Split("=")[1].Trim()
            break 
        }
    }
}

$teamviewerId = "Não instalado"
$tvReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\TeamViewer", "HKLM:\SOFTWARE\TeamViewer" -Name "ClientID" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($tvReg -and $tvReg.ClientID) { 
    $teamviewerId = $tvReg.ClientID.ToString() 
}

$payload = @{
    data              = (Get-Date -Format "dd/MM/yyyy HH:mm")
    empresa           = $empresa
    setor             = $setor
    computador        = $computador
    tipo              = $tipoDispositivo
    fabricante_modelo = $fabricanteModelo
    serial_number     = $serialNumber
    usuario           = $usuario
    processador       = $cpu
    ram_detalhes      = $ramDetalhes
    ram_total         = $ramTotalGB
    ram_uso           = "$ramUso%"
    gpu               = $gpu
    tamanho_ssd       = $tamanhoSsdStr
    disco_total       = $discoTotalGB
    disco_usado       = $discoUsadoGB
    disco_livre       = $discoLivreGB
    saude_ssd         = $saudeSsd
    so                = $sistemaOperacional
    rede              = $redeInfo
    mac               = $mac
    anydesk           = $anydeskId
    teamviewer        = $teamviewerId
} | ConvertTo-Json -Compress

try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $resposta = Invoke-RestMethod -Uri $urlApp -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
    Write-Host "Inventário enviado com sucesso para a máquina: $computador ($serialNumber)" -ForegroundColor Green
} catch {
    Write-Host "Erro ao enviar inventário: $_" -ForegroundColor Red
}