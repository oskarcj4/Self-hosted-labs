# Resolución guiada · Lab 139

:::piensa Antes de tocar nada
Esto corre en tu Windows real y bajo tu propio riesgo. Primero la evidencia
(lo que ya pasó), después el hardening (que no vuelva a pasar). Si
endureces primero, puedes pisar rastros: por ejemplo, reconectar el
pendrive cambia su "última conexión".
:::

## Paso 1 · ¿Qué pendrive se conectó y cuándo?

**Pregúntate:** ¿dónde guarda Windows la lista de discos USB que vio alguna vez?

:::pista Cómo comprobarlo
- Registro: `HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR\<Disk&Ven&Prod&Rev>\<serie>&0`.
- Fechas: `Get-PnpDeviceProperty` con `DEVPKEY_Device_FirstInstallDate` y `DEVPKEY_Device_LastArrivalDate`.
- Confirmación independiente: `C:\Windows\INF\setupapi.dev.log`, bloque
  `Device Install (Hardware initiated) - USBSTOR\...` y su `Section start`.

Dos fuentes que coinciden valen más que una.
:::

## Paso 2 · AutoRun

:::pista Cómo hacerlo
`NoDriveTypeAutoRun=0xFF` (todas las unidades) y `NoAutorun=1` en
`HKLM\...\Policies\Explorer`. Windows moderno ya no ejecuta `autorun.inf`
de un USB, pero la directiva lo garantiza y también cubre CD/DVD.
:::

## Paso 3 · Almacenamiento extraíble

**Pregúntate:** ¿bloqueas todo, o sólo ejecutar y escribir?

:::pista Cómo hacerlo
`Deny_Execute=1` frena malware lanzado desde el USB; `Deny_Write=1` frena
sacar datos. Leer queda permitido para no romper el trabajo diario. La
clave lleva el GUID de la clase de discos extraíbles
`{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}`.
:::

## Paso 4 · Lista de hardware permitido

**Pregúntate:** si niegas la clase DiskDrive, ¿cómo pasa el pendrive aprobado?

:::pista Cómo hacerlo
Con `AllowDeviceInstanceIDs` (su `USBSTOR\...\SERIE&0`) **y**
`AllowDenyLayered=1`. Sin la evaluación por capas, una clase denegada gana
a cualquier permiso. `DenyDeviceClassesRetroactive=0` deja en paz los discos
ya instalados.

Si no necesitas excepciones (kiosco): `USBSTOR\Start=4` y listo.
:::

## Paso 5 · Auditoría

:::pista Cómo hacerlo
`auditpol` con los GUID de las subcategorías:
- `{0CCE9248-...}` Eventos Plug and Play: **6416** al reconocer un dispositivo externo.
- `{0CCE9245-...}` Almacenamiento extraíble: **4663** al acceder a un fichero del USB.

`Get-WinEvent -FilterHashtable @{LogName='Security'; Id=6416}`.
:::

## Cómo actuar en una situación así

- El pendrive encontrado va a seguridad, en bolsa, sin conectarlo más.
- Documenta serie, primera y última conexión, y usuario con sesión abierta.
- En empresa, aplica esto por GPO o Intune a todo el parque, no equipo a equipo,
  y reenvía 6416/4663 a tu SIEM.

## Si te atascas

- "Acceso denegado" al leer `Enum\USBSTOR\...\Properties`: usa `Get-PnpDeviceProperty`, no el registro.
- `auditpol` da `0x00000522`: no abriste PowerShell como administrador.
- El pendrive aprobado tampoco instala: falta `AllowDenyLayered=1` o el ID no coincide (copia el `InstanceId` completo).
