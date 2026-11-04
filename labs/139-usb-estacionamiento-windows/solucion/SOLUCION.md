# Solución — USB del estacionamiento (Windows)

> Recuerda: estos cambios se aplican en tu sistema y bajo tu propio riesgo.
> Al final está cómo deshacerlos.

## Script completo (PowerShell como administrador)

```powershell
Checkpoint-Computer -Description "Antes de tclab-139" -RestorePointType MODIFY_SETTINGS
$dir = "$env:USERPROFILE\tclab-139"; New-Item -ItemType Directory -Force $dir | Out-Null

# 1. Forense
$usb = Get-PnpDevice | Where-Object InstanceId -like 'USBSTOR*' | ForEach-Object {
  $p = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_FirstInstallDate, DEVPKEY_Device_LastArrivalDate
  [pscustomobject]@{ Nombre=$_.FriendlyName; Id=$_.InstanceId; Primera=$p[0].Data; Ultima=$p[1].Data }
}
$usb | Format-List
Select-String C:\Windows\INF\setupapi.dev.log -Pattern 'Device Install.*USBSTOR' -Context 0,1
# Elige el sospechoso y anota:
#   serie=<parte final del InstanceId, sin &0>
#   primera_conexion=<fecha del 'Section start'>

# 2. AutoRun
$exp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
New-Item -Force $exp | Out-Null
Set-ItemProperty $exp NoDriveTypeAutoRun 0xFF -Type DWord
Set-ItemProperty $exp NoAutorun 1 -Type DWord

# 3. Discos extraíbles: sin ejecutar ni escribir
$rsd = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
New-Item -Force $rsd | Out-Null
Set-ItemProperty $rsd Deny_Execute 1 -Type DWord
Set-ItemProperty $rsd Deny_Write 1 -Type DWord

# 4. Lista de hardware: negar discos/MTP nuevos salvo el aprobado
$aprobado = 'USBSTOR\DISK&VEN_KINGSTON&PROD_IRONKEY&REV_1.00\0123456789&0'   # ejemplo: pon el tuyo
$r = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
New-Item -Force "$r\DenyDeviceClasses", "$r\AllowDeviceInstanceIDs" | Out-Null
Set-ItemProperty $r AllowDenyLayered 1 -Type DWord
Set-ItemProperty $r DenyDeviceClasses 1 -Type DWord
Set-ItemProperty $r DenyDeviceClassesRetroactive 0 -Type DWord
Set-ItemProperty "$r\DenyDeviceClasses" 1 '{4d36e967-e325-11ce-bfc1-08002be10318}'
Set-ItemProperty "$r\DenyDeviceClasses" 2 '{eec5ad98-8080-425f-922a-dabf3de3f69a}'
Set-ItemProperty $r AllowDeviceInstanceIDs 1 -Type DWord
Set-ItemProperty "$r\AllowDeviceInstanceIDs" 1 $aprobado

# 5. Auditoría
auditpol /set /subcategory:"{0CCE9248-69AE-11D9-BED3-505054503030}" /success:enable
auditpol /set /subcategory:"{0CCE9245-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
gpupdate /force

# Conecta un USB y recoge los eventos para el informe
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=6416} -MaxEvents 5 |
  Format-List TimeCreated, Message | Out-File -Append "$dir\informe.txt"

powershell -ExecutionPolicy Bypass -File labs\139-usb-estacionamiento-windows\verificar.ps1
```

## Por qué cada capa

- **Forense primero**: USBSTOR, las propiedades PnP y `setupapi.dev.log`
  son tres fuentes independientes de la misma conexión.
- **AutoRun** evita la ejecución automática.
- **RemovableStorageDevices** actúa al usar el disco (leer/escribir/ejecutar).
- **DeviceInstall\Restrictions** actúa antes: el disco no llega a instalarse.
  Con `AllowDenyLayered` el permiso por Instance ID gana a la clase negada.
- **6416/4663** dejan rastro en el registro de seguridad para el SIEM.

## Deshacer

```powershell
Remove-Item -Recurse -Force 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
Remove-Item -Recurse -Force 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' NoDriveTypeAutoRun, NoAutorun
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR Start 3
auditpol /set /subcategory:"{0CCE9248-69AE-11D9-BED3-505054503030}" /success:disable
auditpol /set /subcategory:"{0CCE9245-69AE-11D9-BED3-505054503030}" /success:disable /failure:disable
gpupdate /force
```
