# USB del estacionamiento (Windows): endurece tu equipo

> Guía en tu sistema · almacenamiento extraíble · lista de hardware · USBSTOR · AutoRun · eventos 6416/4663 · setupapi.dev.log

> ⚠️ **Esta guía no usa contenedor: todo se hace en TU sistema y bajo TU
> propio riesgo.** Vamos a endurecer la política de dispositivos externos
> de tu Windows. Una restricción mal puesta puede impedir que instales un
> disco o un teléfono nuevo. Antes de empezar:
>
> - Mejor en una **máquina virtual con snapshot**. En tu equipo, crea antes
>   un punto de restauración (paso 0).
> - Lee la sección **Deshacer todo** antes de aplicar nada.
> - Usa **PowerShell como administrador**. Ningún comando envía datos fuera.

## Escenario

Alguien dejó un pendrive con la etiqueta "Nóminas 2026" en el
estacionamiento, y un compañero lo conectó "para ver de quién era". Tu
trabajo tiene dos partes:

1. **Forense:** demostrar qué USB se conectó a este equipo y cuándo.
2. **Hardening:** que no vuelva a pasar, sin bloquear el pendrive cifrado
   que la empresa sí aprueba.

| Capa | Qué frena | Dónde |
|------|-----------|-------|
| AutoRun desactivado | Que algo se ejecute solo al conectar | `Policies\Explorer` |
| Almacenamiento extraíble sin ejecución ni escritura | Lanzar malware desde el USB, sacar datos | `RemovableStorageDevices` |
| Lista de hardware permitido | Cualquier disco USB salvo el aprobado | `DeviceInstall\Restrictions` |
| Auditoría | Saber qué se conectó y qué se tocó | eventos 6416 y 4663 |

> **Windows Home:** no trae `gpedit.msc`. Usamos las claves de registro que
> escribe la directiva de grupo. Microsoft sólo da soporte a estas
> directivas en Pro, Enterprise y Education: en Home, comprueba cada capa
> con su prueba antes de darla por buena.

## Paso 0 · Punto de restauración y carpeta de trabajo

```powershell
Checkpoint-Computer -Description "Antes de tclab-139" -RestorePointType MODIFY_SETTINGS
New-Item -ItemType Directory -Force "$env:USERPROFILE\tclab-139" | Out-Null
Set-Location "$env:USERPROFILE\tclab-139"
reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows" respaldo-policies.reg /y
```

## Paso 1 · Forense: ¿qué USB se conectó?

Windows recuerda cada disco USB que vio, aunque ya no esté conectado.

```powershell
# Discos USB vistos alguna vez (clave USBSTOR del registro)
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR |
  ForEach-Object { Get-ChildItem $_.PSPath } |
  Select-Object PSChildName, @{n='Nombre';e={(Get-ItemProperty $_.PSPath).FriendlyName}}

# Primera instalación y última conexión de cada uno
Get-PnpDevice | Where-Object InstanceId -like 'USBSTOR*' | ForEach-Object {
  $p = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName `
       DEVPKEY_Device_FirstInstallDate, DEVPKEY_Device_LastArrivalDate
  [pscustomobject]@{ Dispositivo = $_.FriendlyName; InstanceId = $_.InstanceId
    PrimeraVez = $p[0].Data; UltimaVez = $p[1].Data }
} | Format-List
```

El número de serie es la parte de `InstanceId` después de la última `\`
(sin el `&0` final). Confírmalo en el log de instalación de controladores:

```powershell
Select-String -Path C:\Windows\INF\setupapi.dev.log -Pattern 'Device Install.*USBSTOR' -Context 0,1
```

La línea `>>>  Section start AAAA/MM/DD hh:mm:ss` debajo es la **primera vez**
que ese pendrive se conectó a este equipo.

## Paso 2 · AutoRun fuera

```powershell
$exp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
New-Item -Force $exp | Out-Null
Set-ItemProperty $exp NoDriveTypeAutoRun 0xFF -Type DWord   # todas las unidades
Set-ItemProperty $exp NoAutorun 1 -Type DWord               # ignora autorun.inf
```

GPO: *Plantillas administrativas › Componentes de Windows › Directivas de
reproducción automática › Desactivar reproducción automática = Todas las unidades*.

## Paso 3 · Almacenamiento extraíble: sin ejecutar y sin escribir

```powershell
$rsd = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
New-Item -Force $rsd | Out-Null
Set-ItemProperty $rsd Deny_Execute 1 -Type DWord
Set-ItemProperty $rsd Deny_Write   1 -Type DWord
gpupdate /force
```

GPO: *Sistema › Acceso de almacenamiento extraíble › Discos extraíbles:
denegar acceso de ejecución / de escritura*. El GUID es la clase "discos
extraíbles". Prueba: copia un fichero a un pendrive (debe fallar).

## Paso 4 · Lista de hardware permitido

Idea: **negar la instalación** de cualquier disco nuevo (clase `DiskDrive`)
y de teléfonos MTP (clase `WPD`), **salvo** el pendrive aprobado por su
Instance ID. Sólo afecta a dispositivos que se instalen a partir de ahora:
los discos que ya usas siguen funcionando.

Conecta el pendrive **aprobado** y copia su ID:

```powershell
Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USBSTOR*' | Select-Object FriendlyName, InstanceId
```

```powershell
$r = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
New-Item -Force "$r\DenyDeviceClasses", "$r\AllowDeviceInstanceIDs" | Out-Null
Set-ItemProperty $r AllowDenyLayered 1 -Type DWord          # el permiso por ID gana a la clase
Set-ItemProperty $r DenyDeviceClasses 1 -Type DWord
Set-ItemProperty $r DenyDeviceClassesRetroactive 0 -Type DWord
Set-ItemProperty "$r\DenyDeviceClasses" 1 '{4d36e967-e325-11ce-bfc1-08002be10318}'   # DiskDrive
Set-ItemProperty "$r\DenyDeviceClasses" 2 '{eec5ad98-8080-425f-922a-dabf3de3f69a}'   # WPD
Set-ItemProperty $r AllowDeviceInstanceIDs 1 -Type DWord
Set-ItemProperty "$r\AllowDeviceInstanceIDs" 1 'USBSTOR\DISK&VEN_...&PROD_...\SERIE&0'  # el tuyo
gpupdate /force
```

GPO: *Sistema › Instalación de dispositivos › Restricciones de instalación
de dispositivos*. Prueba: conecta un pendrive distinto que nunca hayas usado
en este equipo; debe salir "La instalación de este dispositivo está
prohibida por una directiva del sistema".

> **Plan B (kiosco, bloqueo total):** deshabilitar el controlador USBSTOR.
> Bloquea todos los pendrives, también el aprobado:
> `Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR Start 4`
> (3 = normal).

## Paso 5 · Auditoría: eventos 6416 y 4663

Se activan por GUID, así funciona en Windows en español o en inglés:

```powershell
auditpol /set /subcategory:"{0CCE9248-69AE-11D9-BED3-505054503030}" /success:enable                  # Eventos Plug and Play -> 6416
auditpol /set /subcategory:"{0CCE9245-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable  # Almacenamiento extraíble -> 4663
auditpol /get /subcategory:"{0CCE9248-69AE-11D9-BED3-505054503030},{0CCE9245-69AE-11D9-BED3-505054503030}"
```

Conecta un pendrive, ábrelo, y mira:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=6416} -MaxEvents 5 | Format-List TimeCreated, Message
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4663} -MaxEvents 5 | Format-List TimeCreated, Message
```

- **6416**: "El sistema reconoció un nuevo dispositivo externo" (con su ID y clase).
- **4663**: intento de acceso a un objeto en almacenamiento extraíble (qué fichero, quién, qué acceso).

## Entregable

`%USERPROFILE%\tclab-139\informe.txt` con:

```text
serie=<número de serie del pendrive sospechoso>
primera_conexion=<fecha y hora de setupapi.dev.log>
```

y, debajo, los eventos 6416 de tu prueba.

## Verificación

El script sólo **lee** la configuración; no cambia nada. En PowerShell como administrador:

```powershell
powershell -ExecutionPolicy Bypass -File labs\139-usb-estacionamiento-windows\verificar.ps1
```

## Deshacer todo

```powershell
Remove-Item -Recurse -Force 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
Remove-Item -Recurse -Force 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' NoDriveTypeAutoRun, NoAutorun
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR Start 3     # si usaste el plan B
auditpol /set /subcategory:"{0CCE9248-69AE-11D9-BED3-505054503030}" /success:disable
auditpol /set /subcategory:"{0CCE9245-69AE-11D9-BED3-505054503030}" /success:disable /failure:disable
gpupdate /force
```

Si algo sale mal: *Restaurar sistema* al punto "Antes de tclab-139".
