# Suite de Automatización y Administración de Servidores Linux (5C003-ACSV)

Repositorio oficial de la **Evaluación Parcial Definitiva (EPD)** de la unidad didáctica **Shell Scripting (`5C003-ACSV`)** — Escuela de Tecnología **IDAT**.

## Integrantes y Datos Académicos

| Campo | Detalle |
| :--- | :--- |
| **Unidad Didáctica** | `5C003-ACSV` — Shell Scripting (Ciclo V) |
| **Docente** | Prof. Rommel Andrés Gonzales Guevara |
| **Integrantes** | 1. Edder Manuel Zavala Amezquita<br>2. Edrian Eter Tapullima Sinarahua |
| **Entorno de Ejecución** | `Ubuntu_Live_Server` sobre **Microsoft Hyper-V** (Host `EDDER`) — Bash 5.x |

## Descripción del Problema y Solución

El área de TI de una empresa mediana realizaba manualmente la revisión de espacio en disco, memoria RAM y CPU, la organización y respaldo de archivos, la gestión de permisos y propietarios, la depuración de archivos temporales y el análisis de alertas de almacenamiento en sus servidores Linux.

Esta suite en **Bash** automatiza íntegramente el flujo mediante **4 scripts modulares**, aplicando validaciones de entrada con expresiones regulares, estructuras de control (`if/elif/else`, `case`, `for`, `while`), funciones con variables `local`, redirección (`tee -a`, `>>`, `2>&1`) y herramientas externas (`find`, `stat`, `sed`, `awk`, `cron`).

## Arquitectura de los 4 Módulos

| Módulo / Script | Propósito y Funcionalidades Clave |
| :--- | :--- |
| **Módulo 1:** `01_entorno_sistema.sh` | Muestra y guarda en reporte la fecha/hora sincronizada, usuario ejecutor (`whoami`), distribución del SO (`PRETTY_NAME`), memoria RAM del SO (sin swap), uso de CPU (%), espacio en disco de la partición raíz (`/`) con todas sus columnas, **Leyenda de Umbrales** (`Normal <80%`, `Alerta 80-94%`, `Criticidad >=95%`) y validación de permisos de archivos en `/etc`. |
| **Módulo 2:** `02_gestor_archivos.sh` | Menú interactivo (`while` + `case`) y modo `--auto` que ejecuta: 1) creación de directorios (`mkdir -p`) y archivos con fechas escalonadas, 2) listado previo y copia de seguridad hacia `.bak`, 3) cambio de permisos (`chmod`) y propietario/grupo (`chown`) auditados con `stat`, y 4) eliminación de temporales (`*.tmp`) según antigüedad en días (`find -mtime +N -delete`) con control de 3 intentos. |
| **Módulo 3:** `03_analisis_disco_awk_sed.sh` | Analiza la bitácora de almacenamiento de servidores (`SERVIDOR IP USO_DISCO ESTADO`), filtra con `awk` los servidores que superan el **70%** de uso de disco guardándolos en `reportes/servidores_mas_70.txt`, y reemplaza con `sed` los estados en una copia del archivo (`normal` → `revisado` y `critico` → `alerta`) en `reportes/uso_disco_modificado.txt`. |
| **Módulo 4:** `04_automatizacion_cron.sh` | Traductor interactivo de **Cron** que solicita minuto, hora, día del mes, mes y día de la semana para programar cualquiera de los scripts en `crontab`, además de listar (`crontab -l`) y eliminar tareas programadas. |

## Instalación y Uso Rápido

```bash
# 1. Clonar el repositorio y entrar a la carpeta
git clone https://github.com/edder-zavala/shell-scripting-parcial-idat.git
cd shell-scripting-parcial-idat

# 2. Asignar permisos de ejecución
chmod +x *.sh

# 3. Ejecutar cada módulo
./01_entorno_sistema.sh 80
./02_gestor_archivos.sh --auto 5      # O ./02_gestor_archivos.sh para menú interactivo
./03_analisis_disco_awk_sed.sh 70
./04_automatizacion_cron.sh --auto    # O ./04_automatizacion_cron.sh para asistente Cron
```
