#!/bin/bash
# ==============================================================================
# Curso       : 5C003-ACSV - Shell Scripting (IDAT)
# Docente     : Prof. Rommel Andrés Gonzales Guevara
# Integrantes : Edder Manuel Zavala Amezquita & Edrian Eter Tapullima Sinarahua
# Script 02   : 02_gestor_archivos.sh (Módulo 2: Gestor de Archivos y Permisos)
# Descripción : Menú interactivo con bucle while + case y modo automático (--auto)
#               que ejecuta y valida:
#               1) Crear directorios (mkdir -p) y archivos de trabajo/temporales.
#               2) Listar y copiar archivos hacia el directorio de respaldos (cp -v).
#               3) Cambiar permisos (chmod octal personalizado o predefinido) y
#                  cambiar propietario/grupo (chown) auditando con stat.
#               4) Eliminar un archivo específico con confirmación o limpiar
#                  archivos temporales (*.tmp) por antigüedad en días (find -mtime).
# Uso         : ./02_gestor_archivos.sh [--auto [dias_antiguedad]]
# ==============================================================================

BASE_DIR="$HOME/proyecto_parcial_ti"
DIR_TRABAJO="$BASE_DIR/trabajo"
DIR_TEMPORALES="$BASE_DIR/temporales"
DIR_RESPALDOS="$BASE_DIR/respaldos"
DIR_REPORTES="$BASE_DIR/reportes"
REPORTE_GESTION="$DIR_REPORTES/reporte_gestor_archivos.txt"

mkdir -p "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDOS" "$DIR_REPORTES"

registrar_log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" | tee -a "$REPORTE_GESTION"
}

# ------------------------------------------------------------------------------
# OPCIÓN 1: Crear directorios y archivos de trabajo / temporales con fechas
# ------------------------------------------------------------------------------
crear_archivos() {
    registrar_log "=== [ACCIÓN 1] CREACIÓN DE DIRECTORIOS Y ARCHIVOS ==="
    mkdir -p "$DIR_TRABAJO" "$DIR_TEMPORALES" "$DIR_RESPALDOS"

    # Si es modo interactivo, preguntar si desea crear un archivo con nombre propio
    if [ "$MODO_AUTO" != "1" ]; then
        read -p "¿Desea crear un archivo personalizado en $DIR_TRABAJO? (s/n): " resp
        if [[ "$resp" =~ ^[sS]$ ]]; then
            read -p "Ingrese el nombre del archivo a crear (ej. nota.txt): " nuevo_arch
            if [ -n "$nuevo_arch" ]; then
                touch "$DIR_TRABAJO/$nuevo_arch"
                registrar_log "[OK] Archivo personalizado creado: $DIR_TRABAJO/$nuevo_arch"
            fi
        fi
    fi

    # Generar archivos base y temporales con antigüedad escalonada para pruebas
    echo "CONFIG_PROD=ACTIVO" > "$DIR_TRABAJO/config_servidor.conf"
    echo "#!/bin/bash" > "$DIR_TRABAJO/script_mantenimiento.sh"
    echo "echo 'Mantenimiento OK'" >> "$DIR_TRABAJO/script_mantenimiento.sh"
    echo "Bitacora de operaciones" > "$DIR_TRABAJO/operaciones.log"

    echo "Cache del día de hoy" > "$DIR_TEMPORALES/cache_hoy.tmp"
    echo "Sesión de hace 3 días" > "$DIR_TEMPORALES/sesion_3dias.tmp"
    touch -d "3 days ago" "$DIR_TEMPORALES/sesion_3dias.tmp" 2>/dev/null || true

    echo "Dump temporal de hace 10 días" > "$DIR_TEMPORALES/dump_10dias.tmp"
    touch -d "10 days ago" "$DIR_TEMPORALES/dump_10dias.tmp" 2>/dev/null || true

    echo "Traza obsoleta de hace 20 días" > "$DIR_TEMPORALES/traza_20dias.tmp"
    touch -d "20 days ago" "$DIR_TEMPORALES/traza_20dias.tmp" 2>/dev/null || true

    registrar_log "[OK] Archivos de trabajo creados en $DIR_TRABAJO y 4 temporales en $DIR_TEMPORALES:"
    ls -lh "$DIR_TEMPORALES" | tee -a "$REPORTE_GESTION"
    echo "" | tee -a "$REPORTE_GESTION"
}

# ------------------------------------------------------------------------------
# OPCIÓN 2: Listar archivos disponibles y copiar a respaldos (Observación Clase 4)
# ------------------------------------------------------------------------------
copiar_archivos() {
    registrar_log "=== [ACCIÓN 2] COPIA DE ARCHIVOS HACIA RESPALDOS ==="
    echo "Archivos disponibles actualmente en $DIR_TRABAJO:"
    ls -1 "$DIR_TRABAJO" | sed 's/^/  -> /'

    if [ "$MODO_AUTO" = "1" ]; then
        local contador=0
        for f in "$DIR_TRABAJO"/*; do
            if [ -f "$f" ]; then
                cp -v "$f" "$DIR_RESPALDOS/$(basename "$f").bak" | tee -a "$REPORTE_GESTION"
                contador=$((contador + 1))
            fi
        done
        registrar_log "[OK] Se copiaron $contador archivos hacia $DIR_RESPALDOS."
    else
        read -p "Ingrese el nombre del archivo a copiar (o ENTER para respaldar todos): " arch_copiar
        if [ -z "$arch_copiar" ]; then
            for f in "$DIR_TRABAJO"/*; do
                [ -f "$f" ] && cp -v "$f" "$DIR_RESPALDOS/$(basename "$f").bak" | tee -a "$REPORTE_GESTION"
            done
            registrar_log "[OK] Todos los archivos fueron respaldados en $DIR_RESPALDOS."
        elif [ -f "$DIR_TRABAJO/$arch_copiar" ]; then
            cp -v "$DIR_TRABAJO/$arch_copiar" "$DIR_RESPALDOS/${arch_copiar}.bak" | tee -a "$REPORTE_GESTION"
            registrar_log "[OK] Archivo $arch_copiar copiado exitosamente en $DIR_RESPALDOS/${arch_copiar}.bak"
        else
            registrar_log "[ERROR] El archivo '$arch_copiar' no existe en $DIR_TRABAJO."
        fi
    fi
    echo "" | tee -a "$REPORTE_GESTION"
}

# ------------------------------------------------------------------------------
# OPCIÓN 3: Cambiar permisos (chmod) y propietario/grupo (chown) (Observación Clase 4)
# ------------------------------------------------------------------------------
cambiar_permisos_y_owner() {
    registrar_log "=== [ACCIÓN 3] CAMBIO DE PERMISOS (CHMOD) Y PROPIETARIO (CHOWN) ==="
    if [ "$MODO_AUTO" = "1" ]; then
        chmod 750 "$DIR_TRABAJO/script_mantenimiento.sh"
        chmod 600 "$DIR_TRABAJO/config_servidor.conf"
        chown "$(whoami):$(whoami)" "$DIR_TRABAJO/script_mantenimiento.sh" "$DIR_TRABAJO/config_servidor.conf" 2>/dev/null || true
        registrar_log "[OK] Permisos aplicados: 750 a script_mantenimiento.sh y 600 a config_servidor.conf (Owner: $(whoami))."
        stat -c "  -> %n | Octal: %a (%A) | Owner: %U:%G | Modify: %y | Change: %z" \
            "$DIR_TRABAJO/script_mantenimiento.sh" "$DIR_TRABAJO/config_servidor.conf" | tee -a "$REPORTE_GESTION"
    else
        echo "Archivos en $DIR_TRABAJO:"
        ls -l "$DIR_TRABAJO"
        read -p "Ingrese el nombre del archivo en $DIR_TRABAJO: " arch_perm
        if [ ! -f "$DIR_TRABAJO/$arch_perm" ]; then
            registrar_log "[ERROR] El archivo '$arch_perm' no existe."
            return 1
        fi
        read -p "Ingrese el permiso octal (ej. 750, 644, 600) [por defecto 640]: " modo_octal
        modo_octal="${modo_octal:-640}"
        if [[ ! "$modo_octal" =~ ^[0-7]{3}$ ]]; then
            registrar_log "[ERROR DE VALIDACIÓN] '$modo_octal' no es un permiso octal válido de 3 dígitos (0-7)."
            return 2
        fi
        chmod "$modo_octal" "$DIR_TRABAJO/$arch_perm"
        registrar_log "[OK] Permiso $modo_octal aplicado a $arch_perm."

        read -p "Ingrese nuevo propietario[:grupo] para chown (ENTER para mantener $(whoami)): " nuevo_owner
        if [ -n "$nuevo_owner" ]; then
            sudo chown "$nuevo_owner" "$DIR_TRABAJO/$arch_perm" 2>/dev/null || chown "$nuevo_owner" "$DIR_TRABAJO/$arch_perm" 2>/dev/null || \
                registrar_log "[AVISO] Cambio de owner a '$nuevo_owner' requiere privilegios sudo."
        fi
        stat -c "  -> %n | Octal: %a (%A) | Owner: %U:%G" "$DIR_TRABAJO/$arch_perm" | tee -a "$REPORTE_GESTION"
    fi
    echo "" | tee -a "$REPORTE_GESTION"
}

# ------------------------------------------------------------------------------
# OPCIÓN 4: Eliminar archivos temporales según antigüedad (find -mtime) o nombre
# ------------------------------------------------------------------------------
eliminar_por_fecha() {
    local dias="$1"
    registrar_log "=== [ACCIÓN 4] LIMPIEZA DE ARCHIVOS TEMPORALES SEGÚN FECHA/ANTIGÜEDAD ==="

    if [ -z "$dias" ]; then
        local intentos=0
        local max_intentos=3
        while [ "$intentos" -lt "$max_intentos" ]; do
            read -p "Ingrese antigüedad mínima en días para eliminar temporales *.tmp (ej. 5): " dias
            if [[ "$dias" =~ ^[0-9]+$ ]]; then
                break
            else
                intentos=$((intentos + 1))
                echo " [ENTRADA INVÁLIDA] '$dias' no es un entero positivo. Intento $intentos de $max_intentos."
                dias=""
            fi
        done
        if [ -z "$dias" ]; then
            registrar_log "[ERROR] Se agotaron los $max_intentos intentos. Limpieza cancelada."
            return 2
        fi
    fi

    local candidatos
    candidatos=$(find "$DIR_TEMPORALES" -type f -iname "*.tmp" -mtime +"$dias")
    if [ -z "$candidatos" ]; then
        registrar_log "[INFO] Ningún archivo temporal supera los $dias días de antigüedad."
    else
        registrar_log "Archivos temporales que superan $dias días (serán eliminados):"
        echo "$candidatos" | sed 's/^/  -> /' | tee -a "$REPORTE_GESTION"
        find "$DIR_TEMPORALES" -type f -iname "*.tmp" -mtime +"$dias" -delete
        registrar_log "[OK] Archivos antiguos eliminados. Archivos restantes en $DIR_TEMPORALES:"
        ls -lh "$DIR_TEMPORALES" | tee -a "$REPORTE_GESTION"
    fi
    echo "" | tee -a "$REPORTE_GESTION"
}

# Modo automático para ejecución rápida o desde otros scripts
if [ "$1" = "--auto" ]; then
    MODO_AUTO="1"
    dias_auto="${2:-5}"
    : > "$REPORTE_GESTION"
    crear_archivos
    copiar_archivos
    cambiar_permisos_y_owner
    eliminar_por_fecha "$dias_auto"
    exit 0
fi

# Bucle interactivo while + case (como revisó el profesor en la Clase 4)
while true; do
    echo "======================================================================"
    echo "       MENÚ DE GESTIÓN DE ARCHIVOS Y PERMISOS (MÓDULO 2 - TI)         "
    echo "======================================================================"
    echo " 1) Crear estructura de directorios y archivos temporales"
    echo " 2) Listar y copiar archivos hacia directorio de respaldos (.bak)"
    echo " 3) Cambiar permisos (chmod) y propietario/grupo (chown)"
    echo " 4) Eliminar archivos temporales (*.tmp) según días de antigüedad"
    echo " 5) Ejecutar las 4 acciones completas automáticamente"
    echo " 6) Salir"
    read -p "Seleccione una opción [1-6]: " op

    case "$op" in
        1) crear_archivos ;;
        2) copiar_archivos ;;
        3) cambiar_permisos_y_owner ;;
        4) eliminar_por_fecha ;;
        5)
            MODO_AUTO="1"
            crear_archivos
            copiar_archivos
            cambiar_permisos_y_owner
            eliminar_por_fecha 5
            MODO_AUTO="0"
            ;;
        6) echo "Saliendo del Gestor de Archivos..."; exit 0 ;;
        *) echo "[OPCIÓN INCORRECTA] '$op' no es válido. Ingrese un número entre 1 y 6." ;;
    esac
done
