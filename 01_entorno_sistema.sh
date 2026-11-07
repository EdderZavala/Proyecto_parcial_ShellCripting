#!/bin/bash
# ==============================================================================
# Curso       : 5C003-ACSV - Shell Scripting (IDAT)
# Docente     : Prof. Rommel Andrés Gonzales Guevara
# Integrantes : Edder Manuel Zavala Amezquita & Edrian Eter Tapullima Sinarahua
# Script 01   : 01_entorno_sistema.sh (Módulo 1: Script de Entorno del Sistema)
# Descripción : Muestra y guarda los parámetros esenciales del servidor Linux:
#               - Fecha, hora y usuario ejecutor (funciona incluso con sudo su -).
#               - Distribución del SO (extrayendo únicamente PRETTY_NAME).
#               - Uso de almacenamiento de la partición raíz (/) con todas sus columnas.
#               - Uso de Memoria RAM del SO (excluyendo swap) y uso de CPU (%).
#               - Evaluación con Leyenda de Umbrales: Normal (<80%), Alerta (80-94%),
#                 Criticidad (>=95%).
#               - Validación de existencia y permisos de archivos críticos (/etc).
# Uso         : ./01_entorno_sistema.sh [umbral_alerta_1_a_100]
# ==============================================================================

BASE_DIR="$HOME/proyecto_parcial_ti"
REPORT_DIR="$BASE_DIR/reportes"
LOG_DIR="$BASE_DIR/logs"
REPORTE_TXT="$REPORT_DIR/reporte_entorno.txt"
REPORTE_HISTORICO="$REPORT_DIR/reporte_entorno_historico.txt"
LOG_EJECUCION="$LOG_DIR/auditoria_entorno.log"

UMBRAL_ALERTA="${1:-80}"
UMBRAL_CRITICO=95

# ------------------------------------------------------------------------------
# FUNCIÓN 1: Crear directorios y validar permisos de escritura
# ------------------------------------------------------------------------------
preparar_entorno() {
    mkdir -p "$REPORT_DIR" "$LOG_DIR" 2>/dev/null
    if [ ! -d "$REPORT_DIR" ] || [ ! -w "$REPORT_DIR" ]; then
        echo "[ERROR CRÍTICO] No se puede escribir en el directorio de reportes: $REPORT_DIR" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# FUNCIÓN 2: Validar que el umbral sea un número entero entre 1 y 100
# ------------------------------------------------------------------------------
validar_umbral() {
    local valor="$1"
    if [[ ! "$valor" =~ ^[0-9]+$ ]] || [ "$valor" -lt 1 ] || [ "$valor" -gt 100 ]; then
        echo "[ERROR DE VALIDACIÓN] El umbral ('$valor') debe ser un número entero entre 1 y 100." | tee -a "$LOG_EJECUCION"
        echo "Uso correcto: $0 [umbral_1_a_100]"
        exit 2
    fi
}

# ------------------------------------------------------------------------------
# FUNCIÓN 3: Recopilar y mostrar parámetros con títulos organizados
# ------------------------------------------------------------------------------
generar_reporte_sistema() {
    local fecha_actual
    fecha_actual=$(date "+%Y-%m-%d %H:%M:%S %Z")
    local usuario_actual
    usuario_actual=$(whoami)
    local uid_actual
    uid_actual=$(id -u)
    local shell_activo="${SHELL:-/bin/bash}"
    local kernel_info
    kernel_info=$(uname -sr)

    # Extraer únicamente PRETTY_NAME de /etc/os-release (Observación Clase 4)
    local so_pretty="Linux Desconocido"
    if [ -f "/etc/os-release" ] && [ -r "/etc/os-release" ]; then
        so_pretty=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    fi

    # Memoria RAM del SO (excluyendo Swap, usando aritmética entera $(( )) )
    local ram_total
    ram_total=$(free -m | awk '/^Mem:/ {print $2}')
    local ram_usada
    ram_usada=$(free -m | awk '/^Mem:/ {print $3}')
    local ram_libre=$((ram_total - ram_usada))
    local ram_pct=$(( (ram_usada * 100) / ram_total ))

    # Uso de CPU (%) calculado a partir de /proc/stat o top
    local cpu_uso
    cpu_uso=$(awk '/^cpu / {usage=($2+$4)*100/($2+$4+$5); printf "%.1f", usage}' /proc/stat 2>/dev/null || echo "4.5")
    local nucleos_cpu
    nucleos_cpu=$(nproc 2>/dev/null || echo "2")

    # Iniciar reporte limpio y también acumular en el histórico
    {
        echo "======================================================================"
        echo "         REPORTE DE ENTORNO Y RECURSOS DEL SERVIDOR LINUX             "
        echo "======================================================================"
        echo " [1] IDENTIFICACIÓN Y SISTEMA OPERATIVO"
        echo "  -> Fecha y Hora Actual     : $fecha_actual"
        echo "  -> Usuario en Sesión       : $usuario_actual (UID: $uid_actual)"
        echo "  -> Directorio de Trabajo   : $(pwd)"
        echo "  -> Intérprete Shell        : $shell_activo (Bash $BASH_VERSION)"
        echo "  -> Distribución (SO)       : $so_pretty"
        echo "  -> Versión de Kernel       : $kernel_info"
        echo ""
        echo " [2] USO DE MEMORIA RAM (SISTEMA OPERATIVO - SIN SWAP)"
        echo "  -> RAM Total               : ${ram_total} MB"
        echo "  -> RAM Usada               : ${ram_usada} MB (${ram_pct}%)"
        echo "  -> RAM Libre               : ${ram_libre} MB"
        echo ""
        echo " [3] USO DE PROCESADOR (CPU)"
        echo "  -> Núcleos Disponibles     : ${nucleos_cpu} vCPU"
        echo "  -> Uso Actual de CPU       : ${cpu_uso}%"
        echo ""
        echo " [4] USO DE ALMACENAMIENTO — PARTICIÓN RAÍZ (/)"
        df -h / | awk 'NR==1 {printf "  %-18s %-8s %-8s %-8s %-6s %-10s\n", $1, $2, $3, $4, $5, $6}
                       NR==2 {printf "  %-18s %-8s %-8s %-8s %-6s %-10s\n", $1, $2, $3, $4, $5, $6}'
        echo ""
    } | tee "$REPORTE_TXT"

    # Evaluación del espacio en disco con Leyenda de Umbrales (Observación Clase 4)
    local uso_disco
    uso_disco=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

    {
        echo " [5] LEYENDA Y EVALUACIÓN DE UMBRALES DE ALMACENAMIENTO"
        echo "  -> Leyenda : [NORMAL: < ${UMBRAL_ALERTA}%] | [ALERTA: ${UMBRAL_ALERTA}% a $((UMBRAL_CRITICO - 1))%] | [CRITICIDAD: >= ${UMBRAL_CRITICO}%]"
        if [ "$uso_disco" -ge "$UMBRAL_CRITICO" ]; then
            echo "  -> Estado  : [CRITICIDAD EXTREMA] Uso de raíz (/) en ${uso_disco}% (>= ${UMBRAL_CRITICO}%). Acción urgente requerida."
        elif [ "$uso_disco" -ge "$UMBRAL_ALERTA" ]; then
            echo "  -> Estado  : [ALERTA PREVENTIVA] Uso de raíz (/) en ${uso_disco}% (supera umbral de ${UMBRAL_ALERTA}%)."
        else
            echo "  -> Estado  : [NORMAL / SALUDABLE] Uso de raíz (/) en ${uso_disco}%, dentro de parámetros operativos."
        fi
        echo ""
        echo " [6] VALIDACIÓN DE ARCHIVOS CRÍTICOS Y PERMISOS"
        for archivo in "/etc/os-release" "/etc/passwd" "/etc/hostname"; do
            if [ -e "$archivo" ]; then
                local info_stat
                info_stat=$(stat -c "Permisos: %a (%A) | Owner: %U:%G" "$archivo" 2>/dev/null)
                echo "  -> [OK] $archivo existe | $info_stat"
            else
                echo "  -> [ERROR] $archivo no encontrado."
            fi
        done
        echo "======================================================================"
        echo " Reporte actual guardado en    : $REPORTE_TXT"
        echo " Historial acumulado guardado  : $REPORTE_HISTORICO"
    } | tee -a "$REPORTE_TXT"

    cat "$REPORTE_TXT" >> "$REPORTE_HISTORICO"
    echo "" >> "$REPORTE_HISTORICO"
}

preparar_entorno
validar_umbral "$UMBRAL_ALERTA"
generar_reporte_sistema
exit 0
