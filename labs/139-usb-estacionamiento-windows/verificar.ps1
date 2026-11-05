# Lab 139 - verificacion de la guia USB en Windows.
# Solo LEE la configuracion de este equipo: no cambia nada.
# Uso (PowerShell como administrador):
#   powershell -ExecutionPolicy Bypass -File verificar.ps1
# (Fichero en ASCII a proposito: Windows PowerShell 5.1 lee los .ps1 sin BOM como ANSI.)

$pass = 0; $fail = 0; $warn = 0
function Ok($m)    { Write-Host "  [OK] $m" -ForegroundColor Green;  $script:pass++ }
function No($m)    { Write-Host "  [X]  $m" -ForegroundColor Red;    $script:fail++ }
function Aviso($m) { Write-Host "  [~]  $m" -ForegroundColor Yellow; $script:warn++ }
function Val($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "Ejecutalo en PowerShell como administrador."; exit 2 }

Write-Host "== Lab 139 - USB del estacionamiento (Windows) - verificacion =="

# 1. AutoRun
$exp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
if ((Val $exp 'NoDriveTypeAutoRun') -eq 0xFF) { Ok "AutoRun desactivado en todas las unidades (0xFF)." }
else { No "NoDriveTypeAutoRun debe ser 0xFF." }
if ((Val $exp 'NoAutorun') -eq 1) { Ok "autorun.inf ignorado (NoAutorun=1)." } else { No "NoAutorun debe ser 1." }

# 2. Almacenamiento extraible
$rsd = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}'
if ((Val $rsd 'Deny_Execute') -eq 1) { Ok "Discos extraibles: ejecucion denegada." } else { No "Falta Deny_Execute=1 en discos extraibles." }
if ((Val $rsd 'Deny_Write') -eq 1)   { Ok "Discos extraibles: escritura denegada." } else { No "Falta Deny_Write=1 en discos extraibles." }

# 3. Lista de hardware permitido (o plan B: USBSTOR deshabilitado)
$r = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
$usbstor = Val 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' 'Start'
$clases = @((Get-ItemProperty "$r\DenyDeviceClasses" -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object Name -match '^\d+$' | ForEach-Object Value)
$permitidos = @((Get-ItemProperty "$r\AllowDeviceInstanceIDs" -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object Name -match '^\d+$' | ForEach-Object Value)
if ((Val $r 'DenyDeviceClasses') -eq 1 -and ($clases -contains '{4d36e967-e325-11ce-bfc1-08002be10318}')) {
  Ok "Instalacion de discos nuevos (clase DiskDrive) denegada."
  if ($clases -contains '{eec5ad98-8080-425f-922a-dabf3de3f69a}') { Ok "Telefonos MTP (clase WPD) denegados." }
  else { Aviso "La clase WPD (telefonos MTP) no esta denegada." }
  if ((Val $r 'AllowDeviceInstanceIDs') -eq 1 -and $permitidos.Count -ge 1) {
    Ok "Lista de permitidos con $($permitidos.Count) dispositivo(s)."
    if ((Val $r 'AllowDenyLayered') -eq 1) { Ok "Evaluacion por capas: el ID permitido gana a la clase denegada." }
    else { No "Falta AllowDenyLayered=1: sin el, la clase denegada bloquea tambien el pendrive aprobado." }
    $malos = $permitidos | Where-Object { $_ -notlike 'USBSTOR\*' -and $_ -notlike 'USB\*' }
    if ($malos) { Aviso "IDs permitidos que no parecen USB: $($malos -join ', ')" }
  } else { No "No hay ningun pendrive aprobado en AllowDeviceInstanceIDs." }
} elseif ($usbstor -eq 4) {
  Ok "Plan B: controlador USBSTOR deshabilitado (Start=4); sin lista de permitidos."
} else {
  No "Ni lista de hardware (DenyDeviceClasses) ni USBSTOR deshabilitado."
}

# 4. Auditoria (auditpol /r devuelve CSV; el texto de la columna 5 sale en el idioma del sistema)
function Auditoria($guid) {
  $csv = auditpol /get /subcategory:"$guid" /r 2>$null
  if (-not $csv) { return "" }
  $fila = $csv | Select-Object -Skip 1 | Where-Object { $_.Trim() } | Select-Object -First 1
  if (-not $fila) { return "" }
  return ($fila -split ',')[4]
}
$pnp = Auditoria '{0CCE9248-69AE-11D9-BED3-505054503030}'
$rs  = Auditoria '{0CCE9245-69AE-11D9-BED3-505054503030}'
if ($pnp -match 'Success|Correcto|xito') { Ok "Auditoria Plug and Play activa (evento 6416). [$pnp]" }
else { No "Auditoria Plug and Play sin aciertos (no habra 6416). [$pnp]" }
if ($rs -match 'Success|Correcto|xito') { Ok "Auditoria de almacenamiento extraible activa (evento 4663). [$rs]" }
else { No "Auditoria de almacenamiento extraible sin aciertos (no habra 4663). [$rs]" }
if ($rs -notmatch 'Failure|Error') { Aviso "Almacenamiento extraible: activa tambien los errores (accesos denegados)." }

$ev = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=6416} -MaxEvents 1 -ErrorAction SilentlyContinue
if ($ev) { Ok "Hay eventos 6416 en el registro de seguridad (ultimo: $($ev.TimeCreated))." }
else { Aviso "Aun no hay eventos 6416: conecta un USB para generar uno." }

# 5. Entregable forense
$inf = Join-Path $env:USERPROFILE 'tclab-139\informe.txt'
if (Test-Path $inf) {
  $txt = Get-Content $inf -Raw
  $serie = if ($txt -match '(?m)^serie=(\S+)') { $Matches[1] } else { '' }
  $vistos = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR -ErrorAction SilentlyContinue |
            ForEach-Object { Get-ChildItem $_.PSPath } | ForEach-Object { $_.PSChildName }
  if ($serie -and ($vistos | Where-Object { $_ -like "$serie*" })) { Ok "La serie $serie del informe aparece en USBSTOR." }
  elseif ($serie) { No "La serie $serie no aparece en HKLM\...\Enum\USBSTOR." }
  else { No "informe.txt no tiene la linea serie=..." }
  if ($txt -match '(?m)^primera_conexion=\d{4}[/-]\d{2}[/-]\d{2}') { Ok "Fecha de primera conexion anotada." }
  else { No "informe.txt no tiene primera_conexion=AAAA/MM/DD ..." }
} else { Aviso "Aun no existe $inf (entregable forense)." }

Write-Host "---------------------------------------"
Write-Host "Resultado: $pass correctos, $fail pendientes, $warn avisos."
if ($fail -eq 0) { Write-Host "Politica de dispositivos USB endurecida."; exit 0 } else { exit 1 }
