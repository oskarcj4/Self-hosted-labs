# Auditoría con auditd: quién tocó shadow y sudoers

> Defensa del host · auditd · ausearch · aureport · forense

## Escenario

El monitor de integridad avisa de que `/etc/shadow` y `/etc/sudoers` cambiaron
hoy en `srv-rrhh-02` y nadie abrió un cambio (`~/ticket/INC-112.txt`). Por
suerte, el admin anterior dejó reglas de auditd cargadas **a mano** con
`auditctl` (`/root/reglas-a-mano.txt`): el rastro está en
`/var/log/audit/audit.log`. Pero esas reglas no sobreviven a un reinicio.

## Objetivos

1. Reconstruye **quién** (la cuenta con la que se entró, el `auid`, no el
   `uid`), **desde dónde** (IP del login), **cuándo** y **qué comando**
   modificó cada fichero. Escríbelo en `~/hallazgos.txt`.
2. No todo cambio en `/etc/shadow` es malicioso: en `hallazgos.txt` explica
   qué hizo la cuenta `operador` y por qué es legítimo.
3. Deshaz lo que hizo el intruso (sudoers válido con `visudo -c`, y la cuenta
   tocada de vuelta a su estado de cuenta de sistema).
4. Haz la vigilancia **persistente**: reglas en `/etc/audit/rules.d/` para
   `/etc/shadow` (key `claves`), `/etc/sudoers` y `/etc/sudoers.d/`, y
   cárgalas.

**Extra (no se valida):** manda los eventos de audit a otro servidor
(`audisp-remote` o rsyslog). Un atacante con root puede borrar el log local.

## Comandos que te pueden servir

```bash
sudo ausearch -k claves -i
sudo ausearch -m USER_LOGIN -i
sudo ausearch -k sudoers -i
sudo aureport --summary ; sudo aureport -f -i
sudo visudo -c
sudo augenrules --load ; sudo augenrules --check
sudo auditctl -l      # en un servidor real
```

> Nota: auditd usa el subsistema audit del **kernel**. Docker Desktop no deja
> usarlo desde un contenedor (`auditctl` responde `Operation not permitted`),
> así que `audit.log` es la captura que dejó auditd en el servidor real, con
> el formato exacto del kernel. Por eso `augenrules --load` genera
> `/etc/audit/audit.rules` pero no puede cargarlo: el validador comprueba el
> fichero generado. Para ver eventos en vivo, practica en una VM.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
