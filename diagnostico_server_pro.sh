#!/bin/bash

# ==============================================================================
# 0. VALIDACIÓN DE PERMISOS (ROOT)
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
   echo "====================================================================="
   echo " [ERROR CRÍTICO] Permisos insuficientes."
   echo " Este script requiere privilegios de root para instalar paquetes"
   echo " y acceder a logs del sistema."
   echo " Por favor, ejecute: sudo $0"
   echo "====================================================================="
   exit 1
fi

# ==============================================================================
# CONFIGURACIÓN INICIAL Y DETECCIÓN DE GESTOR DE PAQUETES
# ==============================================================================
FECHA=$(date +"%Y%m%d_%H%M%S")
HOSTNAME=$(hostname)
DIRECTORIO_BASE="./diagnostico_${HOSTNAME}_${FECHA}"
mkdir -p "$DIRECTORIO_BASE"

echo "Iniciando diagnóstico en: $DIRECTORIO_BASE"

# Detectar gestor de paquetes (YUM/DNF para RHEL/CentOS, APT para Debian/Ubuntu)
if command -v dnf &> /dev/null; then
    INSTALL_CMD="dnf install -y"
    CHECK_PKG_CMD="rpm -q"
elif command -v yum &> /dev/null; then
    INSTALL_CMD="yum install -y"
    CHECK_PKG_CMD="rpm -q"
elif command -v apt-get &> /dev/null; then
    # Actualizamos índices minimamente para asegurar que encuentre paquetes
    apt-get update -quiet
    INSTALL_CMD="apt-get install -y"
    CHECK_PKG_CMD="dpkg -s"
else
    echo "[ADVERTENCIA] No se detectó gestor de paquetes estándar. La instalación automática podría fallar."
    INSTALL_CMD="false"
fi

# ==============================================================================
# FUNCIÓN MAESTRA: VALIDAR, INSTALAR Y EJECUTAR
# ==============================================================================
gestionar_y_ejecutar() {
    BINARIO_REQ="$1"      # El comando base (ej: mpstat)
    PAQUETE_REQ="$2"      # El nombre del paquete a instalar (ej: sysstat)
    DESCRIPCION="$3"      # Título para el reporte
    COMANDO_FULL="$4"     # El comando completo con argumentos
    ARCHIVO_SALIDA="${DIRECTORIO_BASE}/$5"

    echo "Procesando: $DESCRIPCION..."

    # Encabezado del archivo
    echo "=== $DESCRIPCION ===" > "$ARCHIVO_SALIDA"
    echo "Fecha: $(date)" >> "$ARCHIVO_SALIDA"

    # 1. Verificar existencia del binario
    if ! command -v "$BINARIO_REQ" &> /dev/null; then
        echo "   -> Binario '$BINARIO_REQ' no encontrado. Intentando instalar paquete '$PAQUETE_REQ'..."
        
        # Log del intento de instalación
        echo "[INFO] Binario $BINARIO_REQ no encontrado. Intentando instalar $PAQUETE_REQ..." >> "$ARCHIVO_SALIDA"
        
        # Ejecutar instalación
        $INSTALL_CMD "$PAQUETE_REQ" >> "$ARCHIVO_SALIDA" 2>&1
        
        # 2. Validar si la instalación fue exitosa
        if ! command -v "$BINARIO_REQ" &> /dev/null; then
            echo "   [ERROR] No se pudo instalar $PAQUETE_REQ. Saltando ejecución."
            echo "" >> "$ARCHIVO_SALIDA"
            echo "*** ERROR FATAL: EL COMANDO NO EXISTE Y LA INSTALACIÓN FALLÓ ***" >> "$ARCHIVO_SALIDA"
            echo "Revise la conexión a internet o los repositorios configurados." >> "$ARCHIVO_SALIDA"
            return 1 # Salimos de la función con error
        else
            echo "   [INFO] Instalación de $PAQUETE_REQ exitosa."
            echo "[OK] Instalación completada exitosamente." >> "$ARCHIVO_SALIDA"
        fi
    fi

    echo "   -> Ejecutando comando..."
    echo "Comando ejecutado: $COMANDO_FULL" >> "$ARCHIVO_SALIDA"
    echo "---------------------------------" >> "$ARCHIVO_SALIDA"

    # 3. Ejecución del comando real
    eval "$COMANDO_FULL" >> "$ARCHIVO_SALIDA" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "   [OK] Resultado guardado en $5"
    else
        echo "   [ERROR] El comando falló durante la ejecución."
        echo "*** ERROR EN EJECUCIÓN ***" >> "$ARCHIVO_SALIDA"
    fi
}

# ==============================================================================
# 1. HARDWARE: CPU Y RAM
# ==============================================================================
# lscpu viene en 'util-linux' (casi siempre instalado, pero validamos)
gestionar_y_ejecutar "lscpu" "util-linux" "Info CPU Arquitectura" "lscpu" "01_cpu_info.txt"

# mpstat viene en 'sysstat' (Muy comunmente ausente en instalaciones minimas)
gestionar_y_ejecutar "mpstat" "sysstat" "Uso CPU por Núcleo" "mpstat -P ALL 1 1" "01_cpu_usage.txt"

# free viene en 'procps-ng'
gestionar_y_ejecutar "free" "procps-ng" "Memoria RAM Resumen" "free -h" "02_ram_summary.txt"

# vmstat también en 'procps-ng' o 'procps'
gestionar_y_ejecutar "vmstat" "procps-ng" "Detalle Paginación Memoria" "vmstat -s" "02_ram_detail.txt"

# ==============================================================================
# 2. ALMACENAMIENTO
# ==============================================================================
gestionar_y_ejecutar "df" "coreutils" "Espacio en Filesystems" "df -hT" "03_disk_usage.txt"

gestionar_y_ejecutar "lsblk" "util-linux" "Estructura de Bloques" "lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,TYPE" "03_disk_structure.txt"

# iostat es parte de sysstat
gestionar_y_ejecutar "iostat" "sysstat" "Estadísticas I/O Disco" "iostat -x 1 1" "03_disk_io.txt"

# ==============================================================================
# 3. RED
# ==============================================================================
# ip viene en iproute
gestionar_y_ejecutar "ip" "iproute" "Configuración IP" "ip addr show" "04_network_config.txt"

# ss viene en iproute (reemplaza a netstat)
gestionar_y_ejecutar "ss" "iproute" "Puertos Escuchando" "ss -tulnp" "04_network_ports.txt"

# ==============================================================================
# 4. INFRAESTRUCTURA E IBM PROCESSES
# ==============================================================================
gestionar_y_ejecutar "uptime" "procps-ng" "Carga del Sistema" "uptime" "05_system_load.txt"

# ulimit es un built-in de bash, pero lo envolvemos en bash -c para consistencia
gestionar_y_ejecutar "bash" "bash" "Limites de Usuario (Ulimits)" "ulimit -a" "05_system_ulimits.txt"

gestionar_y_ejecutar "ps" "procps-ng" "Procesos Java (ODM/BAW)" "ps -eo pid,user,pcpu,pmem,args --sort=-pcpu | grep [j]ava" "06_java_processes.txt"

gestionar_y_ejecutar "dmesg" "util-linux" "Logs Kernel (Errores)" "dmesg | grep -i 'error\|fail\|warn\|killed' | tail -n 50" "05_kernel_errors.txt"

# ==============================================================================
# 5. TRANSACCIONES (Estimación Logs)
# ==============================================================================
# find y grep suelen venir por defecto (findutils, grep)
RUTA_LOGS_BUSQUEDA="/opt/ibm /var/log/ibm /home/was"

gestionar_y_ejecutar "find" "findutils" "Búsqueda Logs Actividad" \
    "find $RUTA_LOGS_BUSQUEDA -name 'SystemOut.log' -o -name 'messages.log' 2>/dev/null | xargs tail -n 1000 | grep -i 'J2CA\|PMRM\|WTRN' || echo 'No logs found'" \
    "07_transactions_estimate.txt"

# ==============================================================================
# CIERRE
# ==============================================================================
echo "----------------------------------------------------"
echo "Diagnóstico finalizado."

# Comprimir
if command -v tar &> /dev/null; then
    tar -czf "${DIRECTORIO_BASE}.tar.gz" "$DIRECTORIO_BASE"
    echo "Resultados comprimidos en: ${DIRECTORIO_BASE}.tar.gz"
else
    echo "Comando 'tar' no encontrado. Los resultados están en la carpeta: $DIRECTORIO_BASE"
fi
