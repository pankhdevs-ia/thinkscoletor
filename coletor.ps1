# --- CONFIGURAÇÃO ---
$UrlAppsScript = "https://script.google.com/macros/s/AKfycbwHzxH392RRSn27s6WBhoGndDG6GTRJ5__NlA9XC4pJTVtpe1anwDf1JTtY-3eZfD6F/exec"
# --------------------

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   INVENTÁRIO DE HARDWARE TI   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$Empresa = Read-Host "Digite o nome da empresa"
$Setor = Read-Host "Digite o setor"

Write-Host "`nColetando informações do computador..." -ForegroundColor Yellow

# Dados Básicos
$Hostname = $env:COMPUTERNAME
$Usuario = $env:USERNAME
$Cpu = (Get-WmiObject Win32_Processor).Name

# Memória RAM
$Memoria = Get-CimInstance Win32_OperatingSystem
$RamTotal = [Math]::Round($Memoria.TotalVisibleMemorySize / 1MB, 2)
$RamLivre = [Math]::Round($Memoria.FreePhysicalMemory / 1MB, 2)
$RamUso = [Math]::Round((($RamTotal - ($RamLivre / 1024)) / $RamTotal) * 100, 2)

# Disco C: (Partição lógica)
$DiscoC = Get-PSDrive C
$DiscoTotal = [Math]::Round(($DiscoC.Used + $DiscoC.Free) / 1GB, 2)
$DiscoLivre = [Math]::Round($DiscoC.Free / 1GB, 2)
$DiscoUsado = [Math]::Round($DiscoC.Used / 1GB, 2)

# Endereço MAC
$Mac = (Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1).MacAddress

# AnyDesk
$AnyDesk = "Não encontrado"
$CaminhoAD1 = "$env:APPDATA\AnyDesk\system.conf"
$CaminhoAD2 = "C:\ProgramData\AnyDesk\system.conf"
if (Test-Path $CaminhoAD1) {
    $Conteudo = Get-Content $CaminhoAD1
    foreach ($linha in $Conteudo) {
        if ($linha -like "ad.anydesk.id=*") { $AnyDesk = $linha.Split('=')[1].Trim() }
    }
} elseif (Test-Path $CaminhoAD2) {
    $Conteudo = Get-Content $CaminhoAD2
    foreach ($linha in $Conteudo) {
        if ($linha -like "ad.anydesk.id=*") { $AnyDesk = $linha.Split('=')[1].Trim() }
    }
}

# Tamanho do SSD e Saúde (CrystalDisk style)
$TamanhoSsd = "Indisponível"
$SaudeSsd = "Indisponível"
try {
    $PhysicalDisk = Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, Size
    if ($PhysicalDisk) {
        # Pega o tamanho do primeiro disco físico principal em GB
        $TamanhoSsd = [Math]::Round($PhysicalDisk[0].Size / 1GB, 2).ToString() + " GB"
        $SaudeSsd = ($PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus | ConvertTo-Json -Compress)
    }
} catch {
    $SaudeSsd = "Erro ao coletar"
}

$DataColeta = Get-Date -Format "dd/MM/yyyy HH:mm"

# Monta o JSON para enviar ao Google Sheets
$Body = @{
    data         = $DataColeta
    empresa      = $Empresa
    setor        = $Setor
    computador   = $Hostname
    usuario      = $Usuario
    processador  = $Cpu
    ram_total    = $RamTotal
    ram_uso      = $RamUso
    disco_total  = $DiscoTotal
    disco_livre  = $DiscoLivre
    disco_usado  = $DiscoUsado
    mac          = $Mac
    anydesk      = $AnyDesk
    tamanho_ssd  = $TamanhoSsd
    saude_ssd    = $SaudeSsd
} | ConvertTo-Json

Write-Host "Enviando dados para a nuvem..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri $UrlAppsScript -Method Post -Body $Body -ContentType "application/json"
    Write-Host "`n[SUCESSO] Dados enviados para a planilha com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "`n[ERRO] Falha ao enviar os dados: $_" -ForegroundColor Red
}

Read-Host "`nPressione ENTER para fechar"