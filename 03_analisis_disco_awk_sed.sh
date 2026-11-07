#!/bin/bash
# ==============================================================================
# Curso       : 5C003-ACSV - Shell Scripting (IDAT)
# Docente     : Prof. Rommel Andrés Gonzales Guevara
# Integrantes : Edder Manuel Zavala Amezquita & Edrian Eter Tapullima Sinarahua
# Script 03   : 03_analisis_disco_awk_sed.sh (Módulo 3: Análisis con AWK y SED)
# Descripción : Implementa exactamente el caso práctico demostrado por el docente:
#               1) Analiza un archivo de recolección de uso de disco de varios
#                  servidores (SERVIDOR, IP, USO_DISCO, ESTADO).
#               2) Identifica con AWK los servidores que superan el umbral del 70%
#                  y guarda la lista en reportes/servidores_mas_70.txt.
#               3) Reemplaza con SED los estados en una copia del archivo
#                  ("normal" -> "revisado" y "critico" -> "alerta") agregando
#                  estampa de tiempo en reportes/uso_disco_modificado.txt.
# Uso         : ./03_analisis_disco_awk_sed.sh [umbral_porcentaje]
# ==============================================================================

BASE_DIR="$HOME/proyecto_parcial_ti"
DATOS_DIR="$BASE_DIR/datos"
REPORT_DIR="$BASE_DIR/reportes"
ARCHIVO_ORIGEN="$DATOS_DIR/alerta_disco.txt"
REPORTE_MAS_70="$REPORT_DIR/servidores_mas_70.txt"
ARCHIVO_MODIFICADO_SED="$REPORT_DIR/uso_disco_modificado.txt"

UMBRAL="${1:-70}"

# Validar que el umbral sea numérico entero entre 1 y 100
if [[ ! "$UMBRAL" =~ ^[0-9]+$ ]] || [ "$UMBRAL" -lt 1 ] || [ "$UMBRAL" -gt 100 ]; then
    echo "[ERROR DE VALIDACIÓN] El umbral ('$UMBRAL') debe ser un número entero entre 1 y 100." >&2
    exit 2
fi

mkdir -p "$DATOS_DIR" "$REPORT_DIR"

# 1. Crear archivo de datos de servidores si no existe (formato exacto de Clase 4)
if [ ! -f "$ARCHIVO_ORIGEN" ]; then
    cat << 'DATA' > "$ARCHIVO_ORIGEN"
SERVIDOR IP USO_DISCO ESTADO
srv-app01 192.168.0.10 55% normal
srv-web01 192.168.0.11 40% normal
srv-db01 192.168.0.12 90% critico
srv-files01 192.168.0.13 68% normal
srv-pacs01 192.168.0.14 95% critico
srv-backup01 192.168.0.15 78% critico
DATA
fi

# Validar que el archivo de entrada existe antes de procesar
if [ ! -f "$ARCHIVO_ORIGEN" ]; then
    echo "[ERROR] No existe el archivo de origen: $ARCHIVO_ORIGEN" >&2
    exit 1
fi

echo "======================================================================"
echo "     MÓDULO 3: ANÁLISIS DE USO DE DISCO DE SERVIDORES (AWK Y SED)     "
echo "======================================================================"
echo " [1] Archivo de origen analizado: $ARCHIVO_ORIGEN"
cat "$ARCHIVO_ORIGEN" | sed 's/^/     /'
echo ""

# 2. Filtrar con AWK los servidores cuyo uso de disco supera el umbral (> 70%)
echo " [2] Filtrando con AWK servidores que superan el ${UMBRAL}% de uso de disco..."
{
    echo "# REPORTE DE SERVIDORES CON USO DE DISCO SUPERIOR AL ${UMBRAL}% ($(date '+%Y-%m-%d %H:%M:%S'))"
    awk -v limite="$UMBRAL" '
    NR == 1 {
        printf "%-15s %-16s %-12s %-12s\n", $1, $2, $3, $4
        printf "%-15s %-16s %-12s %-12s\n", "---------------", "----------------", "------------", "------------"
        next
    }
    {
        uso = $3
        gsub("%", "", uso)
        if ((uso + 0) > limite) {
            printf "%-15s %-16s %-12s %-12s\n", $1, $2, $3, $4
            alertados++
        }
    }
    END {
        printf "\nTotal de servidores que superan el %d%% de uso de disco: %d\n", limite, alertados
    }' "$ARCHIVO_ORIGEN"
} | tee "$REPORTE_MAS_70"

echo ""
echo " [OK] Reporte de alertas guardado en: $REPORTE_MAS_70"
echo ""

# 3. Reemplazar estados en una copia del archivo usando SED ("normal" -> "revisado", "critico" -> "alerta")
echo " [3] Reemplazando estados con SED en copia del archivo ('normal' -> 'revisado', 'critico' -> 'alerta')..."
{
    echo "# BITÁCORA DE USO DE DISCO MODIFICADA CON SED — Fecha de auditoría: $(date '+%Y-%m-%d %H:%M:%S')"
    sed -e 's/\bnormal\b/revisado/g' -e 's/\bcritico\b/alerta/g' "$ARCHIVO_ORIGEN"
} > "$ARCHIVO_MODIFICADO_SED"

cat "$ARCHIVO_MODIFICADO_SED" | sed 's/^/     /'
echo ""
echo " [OK] Copia con estados actualizados guardada en: $ARCHIVO_MODIFICADO_SED"
echo "======================================================================"
exit 0
