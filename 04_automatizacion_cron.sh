#!/bin/bash
# ==============================================================================
# Curso       : 5C003-ACSV - Shell Scripting (IDAT)
# Docente     : Prof. Rommel Andrés Gonzales Guevara
# Integrantes : Edder Manuel Zavala Amezquita & Edrian Eter Tapullima Sinarahua
# Script 04   : 04_automatizacion_cron.sh (Módulo 4: Automatización con Cron)
# Descripción : Permite a cualquier administrador o usuario final gestionar tareas
#               programadas en Cron sin necesidad de memorizar los 5 asteriscos:
#               1) Traduce minuto, hora, día del mes, mes y día de la semana en una
#                  regla válida de Crontab y la instala automáticamente.
#               2) Permite listar las tareas programadas activas (crontab -l).
#               3) Permite eliminar una tarea programada específica.
#               4) Incluye modo rápido (--auto) para dejar programada la ejecución
#                  diaria del reporte de entorno y análisis.
# Uso         : ./04_automatizacion_cron.sh [--auto]
# ==============================================================================

BASE_DIR="$HOME/proyecto_parcial_ti"
REPORT_DIR="$BASE_DIR/reportes"
LOG_DIR="$BASE_DIR/logs"
CRON_FILE="$REPORT_DIR/crontab_configurado.txt"
REPORTE_CRON="$REPORT_DIR/reporte_automatizacion_cron.txt"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

# Asegurar que los scripts estén disponibles en BASE_DIR para ejecución desde Cron
for s in 01_entorno_sistema.sh 02_gestor_archivos.sh 03_analisis_disco_awk_sed.sh 04_automatizacion_cron.sh; do
    if [ -f "./$s" ]; then
        cp -f "./$s" "$BASE_DIR/$s" 2>/dev/null || true
        chmod +x "$BASE_DIR/$s" 2>/dev/null || true
    fi
done

instalar_linea_cron() {
    local expresion_cron="$1"
    local comentario="$2"

    echo "$comentario" >> "$CRON_FILE"
    echo "$expresion_cron" >> "$CRON_FILE"

    if command -v crontab >/dev/null 2>&1; then
        (crontab -l 2>/dev/null | grep -vF "$expresion_cron"; echo "$comentario"; echo "$expresion_cron") | crontab - 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# OPCIÓN 1: Asistente interactivo para programar una tarea en Cron paso a paso
# ------------------------------------------------------------------------------
programar_tarea_interactiva() {
    echo "----------------------------------------------------------------------"
    echo " ASISTENTE DE PROGRAMACIÓN DE TAREAS EN CRON (TRADUCTOR AMIGABLE)"
    echo "----------------------------------------------------------------------"
    echo " Seleccione el script que desea programar automáticamente:"
    echo "  1) 01_entorno_sistema.sh (Reporte de Entorno, RAM, CPU y Disco)"
    echo "  2) 02_gestor_archivos.sh --auto 5 (Respaldo y Limpieza de Temporales)"
    echo "  3) 03_analisis_disco_awk_sed.sh 70 (Análisis AWK y Reemplazo SED)"
    read -p " Elija el script [1-3]: " sel_script

    local comando_ejecutar=""
    case "$sel_script" in
        1) comando_ejecutar="$BASE_DIR/01_entorno_sistema.sh 80 >> $LOG_DIR/cron_entorno.log 2>&1" ;;
        2) comando_ejecutar="$BASE_DIR/02_gestor_archivos.sh --auto 5 >> $LOG_DIR/cron_gestor.log 2>&1" ;;
        3) comando_ejecutar="$BASE_DIR/03_analisis_disco_awk_sed.sh 70 >> $LOG_DIR/cron_analisis.log 2>&1" ;;
        *) echo " [ERROR] Selección de script inválida."; return 1 ;;
    esac

    read -p " Ingrese el MINUTO de ejecución (0-59, o * para cada minuto) [ej. 0]: " c_min
    c_min="${c_min:-0}"
    if [[ ! "$c_min" =~ ^(\*|[0-9]|[1-5][0-9])$ ]]; then
        echo " [ERROR DE VALIDACIÓN] Minuto '$c_min' inválido (debe ser 0-59 o *)."
        return 2
    fi

    read -p " Ingrese la HORA de ejecución en formato 24h (0-23, o * para toda hora) [ej. 8]: " c_hora
    c_hora="${c_hora:-8}"
    if [[ ! "$c_hora" =~ ^(\*|[0-9]|1[0-9]|2[0-3])$ ]]; then
        echo " [ERROR DE VALIDACIÓN] Hora '$c_hora' inválida (debe ser 0-23 o *)."
        return 2
    fi

    read -p " Ingrese el DÍA DEL MES (1-31, o * para todos los días) [ej. *]: " c_diames
    c_diames="${c_diames:-*}"

    read -p " Ingrese el MES (1-12, o * para todos los meses) [ej. *]: " c_mes
    c_mes="${c_mes:-*}"

    read -p " Ingrese el DÍA DE LA SEMANA (0=Dom, 1=Lun ... 6=Sáb, 1-5=Lun a Vie, o *) [ej. 1-5]: " c_diasem
    c_diasem="${c_diasem:-1-5}"

    local nueva_linea="$c_min $c_hora $c_diames $c_mes $c_diasem $comando_ejecutar"
    local desc="# Tarea creada por $(whoami) el $(date '+%Y-%m-%d %H:%M:%S')"

    instalar_linea_cron "$nueva_linea" "$desc"

    {
        echo "======================================================================"
        echo " [OK] TAREA PROGRAMADA EXITOSAMENTE EN CRON"
        echo "  -> Horario traducido : Minuto=[$c_min] Hora=[$c_hora] DíaMes=[$c_diames] Mes=[$c_mes] DíaSem=[$c_diasem]"
        echo "  -> Expresión Crontab : $nueva_linea"
        echo "  -> Archivo de registro: $CRON_FILE"
        echo "======================================================================"
    } | tee -a "$REPORTE_CRON"
}

# ------------------------------------------------------------------------------
# OPCIÓN 2: Listar tareas programadas actualmente
# ------------------------------------------------------------------------------
listar_tareas_cron() {
    echo "----------------------------------------------------------------------"
    echo " TAREAS PROGRAMADAS ACTUALMENTE EN EL SERVIDOR (CRONTAB -L)"
    echo "----------------------------------------------------------------------"
    if command -v crontab >/dev/null 2>&1 && crontab -l >/dev/null 2>&1; then
        crontab -l | sed 's/^/  /'
    elif [ -f "$CRON_FILE" ]; then
        cat "$CRON_FILE" | sed 's/^/  /'
    else
        echo "  [INFO] No hay tareas programadas registradas."
    fi
    echo "----------------------------------------------------------------------"
}

# ------------------------------------------------------------------------------
# OPCIÓN 3: Eliminar una tarea programada (Observación Clase 4)
# ------------------------------------------------------------------------------
eliminar_tarea_cron() {
    listar_tareas_cron
    read -p "Ingrese una palabra clave del script que desea eliminar de Cron (ej. 01_entorno o TODAS): " palabra
    if [ -z "$palabra" ]; then
        echo " [AVISO] Operación cancelada."
        return 0
    fi

    if [ "$palabra" = "TODAS" ]; then
        crontab -r 2>/dev/null || true
        : > "$CRON_FILE"
        echo " [OK] Se eliminaron todas las tareas programadas de Cron." | tee -a "$REPORTE_CRON"
    else
        if command -v crontab >/dev/null 2>&1; then
            crontab -l 2>/dev/null | grep -v "$palabra" | crontab - 2>/dev/null || true
        fi
        if [ -f "$CRON_FILE" ]; then
            grep -v "$palabra" "$CRON_FILE" > "${CRON_FILE}.tmp" && mv "${CRON_FILE}.tmp" "$CRON_FILE"
        fi
        echo " [OK] Se eliminaron de Cron las tareas que contenían '$palabra'." | tee -a "$REPORTE_CRON"
    fi
}

# Modo automático (--auto) para pruebas rápidas
if [ "$1" = "--auto" ]; then
    : > "$CRON_FILE"
    : > "$REPORTE_CRON"
    linea_1="0 8 * * 1-5 $BASE_DIR/01_entorno_sistema.sh 80 >> $LOG_DIR/cron_entorno.log 2>&1"
    linea_2="30 23 * * * $BASE_DIR/03_analisis_disco_awk_sed.sh 70 >> $LOG_DIR/cron_analisis.log 2>&1"
    instalar_linea_cron "$linea_1" "# Reporte diario de entorno (Lunes a Viernes 08:00 AM)"
    instalar_linea_cron "$linea_2" "# Auditoría nocturna de uso de disco con AWK y SED (Todos los días 23:30 PM)"
    {
        echo "======================================================================"
        echo "     MÓDULO 4: AUTOMATIZACIÓN Y PROGRAMACIÓN DE TAREAS EN CRON        "
        echo "======================================================================"
        echo " [OK] Se configuraron automáticamente 2 tareas en Crontab:"
        cat "$CRON_FILE" | sed 's/^/   /'
        echo "======================================================================"
        echo " Reporte de automatización guardado en: $REPORTE_CRON"
    } | tee -a "$REPORTE_CRON"
    exit 0
fi

# Menú interactivo de Cron
while true; do
    echo "======================================================================"
    echo "      GESTOR DE TAREAS PROGRAMADAS CON CRON (MÓDULO 4 - TI)           "
    echo "======================================================================"
    echo " 1) Programar una nueva tarea en Cron (Asistente paso a paso)"
    echo " 2) Listar tareas programadas activas (crontab -l)"
    echo " 3) Eliminar una tarea programada de Cron"
    echo " 4) Cargar programación empresarial predeterminada (--auto)"
    echo " 5) Salir"
    read -p "Seleccione una opción [1-5]: " op_cron

    case "$op_cron" in
        1) programar_tarea_interactiva ;;
        2) listar_tareas_cron ;;
        3) eliminar_tarea_cron ;;
        4) "$0" --auto ;;
        5) echo "Saliendo del gestor de Cron..."; exit 0 ;;
        *) echo "[OPCIÓN INCORRECTA] Ingrese una opción del 1 al 5." ;;
    esac
done
