#!/bin/bash

# ==============================================================================
# METADATOS DEL SCRIPT
# ==============================================================================
SCRIPT_AUTOR="FELIPE SEBASTIANI - CUSTOMER SUCCESS MANAGER AT IBM"
SCRIPT_VERSION="1.2.3"
SCRIPT_FECHA_REV=$(date +"%Y-%m-%d_%I-%M-%S-%p")
SCRIPT_DESC1="Diagnóstico integral para servidores Linux con adicionales IBM ODM/BAW/FileNet"
SCRIPT_DESC2="Requiere permisos de root y tener desplegado utilitarios jq (https://jqlang.org/download/), sysstat (https://sysstat.github.io/), mpstat"
# ==============================================================================
# FUNCIÓN: IMPRIMIR ENCABEZADO
# ==============================================================================
imprimir_banner() {
    clear
    echo "=============================================================================="
    echo "   HERRAMIENTA DE DIAGNÓSTICO DE SERVIDORES (IBM MIDDLEWARE COMPATIBLE)"
    echo "=============================================================================="
    echo "  > Autor       : $SCRIPT_AUTOR"
    echo "  > Versión     : $SCRIPT_VERSION ($SCRIPT_FECHA_REV)"
    echo "  > Descripción : $SCRIPT_DESC1"
    echo "  > $SCRIPT_DESC2"
    echo "  > Ejecutado el: $(date)"
    echo "=============================================================================="
    echo ""
    sleep 2
}

# Ejecutamos el banner inmediatamente
imprimir_banner

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
# CONFIGURACIÓN INICIAL
# ==============================================================================
FECHA=$(date +"%Y%m%d_%H%M%S")
HOSTNAME=$(hostname)
DIRECTORIO_BASE="./diagnostico_${HOSTNAME}_${FECHA}"
mkdir -p "$DIRECTORIO_BASE"

# Definición GLOBAL de rutas de búsqueda para IBM (Corrige error de variables no definidas)
RUTAS_IBM="/opt/ibm /opt/IBM /opt/ibm/db2 /var/log/ibm /home/was /usr/local /opt/IBM/FileNet /opt/IBM/ODM /opt/IBM/BPM /usr/IBM"

echo "Iniciando diagnóstico en: $DIRECTORIO_BASE"

# Detectar gestor de paquetes
if command -v dnf &> /dev/null; then
    INSTALL_CMD="dnf install -y"
elif command -v yum &> /dev/null; then
    INSTALL_CMD="yum install -y"
elif command -v apt-get &> /dev/null; then
    apt-get update -quiet
    INSTALL_CMD="apt-get install -y"
else
    echo "[ADVERTENCIA] No se detectó gestor de paquetes estándar. La instalación automática podría fallar."
    INSTALL_CMD="false"
fi

# ==============================================================================
# FUNCIÓN MAESTRA: VALIDAR, INSTALAR Y EJECUTAR
# ==============================================================================
gestionar_y_ejecutar() {
    BINARIO_REQ="$1"      # Comando base
    PAQUETE_REQ="$2"      # Paquete a instalar
    DESCRIPCION="$3"      # Título reporte
    COMANDO_FULL="$4"     # Comando completo
    ARCHIVO_SALIDA="${DIRECTORIO_BASE}/$5"

    echo "Procesando: $DESCRIPCION..."

    # Encabezado del archivo
    echo "=== $DESCRIPCION ===" > "$ARCHIVO_SALIDA"
    echo "Fecha: $(date)" >> "$ARCHIVO_SALIDA"

    # 1. Verificar existencia del binario
    if ! command -v "$BINARIO_REQ" &> /dev/null; then
        echo "   -> Binario '$BINARIO_REQ' no encontrado. Intentando instalar paquete '$PAQUETE_REQ'..."
        echo "[INFO] Binario $BINARIO_REQ no encontrado. Intentando instalar $PAQUETE_REQ..." >> "$ARCHIVO_SALIDA"
        
        $INSTALL_CMD "$PAQUETE_REQ" >> "$ARCHIVO_SALIDA" 2>&1
        
        if ! command -v "$BINARIO_REQ" &> /dev/null; then
            echo "   [ERROR] No se pudo instalar $PAQUETE_REQ. Saltando ejecución."
            echo "*** ERROR FATAL: EL COMANDO NO EXISTE Y LA INSTALACIÓN FALLÓ ***" >> "$ARCHIVO_SALIDA"
            return 1
        else
            echo "   [INFO] Instalación de $PAQUETE_REQ exitosa."
            echo "[OK] Instalación completada exitosamente." >> "$ARCHIVO_SALIDA"
        fi
    fi

    # 2. Ejecución del comando real
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
gestionar_y_ejecutar "lscpu" "util-linux" "Info CPU Arquitectura" "lscpu" "01_cpu_info.txt"
gestionar_y_ejecutar "mpstat" "sysstat" "Uso CPU por Núcleo" "mpstat -P ALL 1 1" "01_cpu_usage.txt"
gestionar_y_ejecutar "free" "procps-ng" "Memoria RAM Resumen" "free -h" "02_ram_summary.txt"
gestionar_y_ejecutar "vmstat" "procps-ng" "Detalle Paginación Memoria" "vmstat -s" "02_ram_detail.txt"

# ==============================================================================
# 2. ALMACENAMIENTO
# ==============================================================================
gestionar_y_ejecutar "df" "coreutils" "Espacio en Filesystems" "df -hT" "03_disk_usage.txt"
gestionar_y_ejecutar "lsblk" "util-linux" "Estructura de Bloques" "lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,TYPE" "03_disk_structure.txt"
gestionar_y_ejecutar "iostat" "sysstat" "Estadísticas I/O Disco" "iostat -x 1 1" "03_disk_io.txt"

# ==============================================================================
# 3. RED
# ==============================================================================
gestionar_y_ejecutar "ip" "iproute" "Configuración IP" "ip addr show" "04_network_config.txt"
gestionar_y_ejecutar "ss" "iproute" "Puertos Escuchando" "ss -tulnp" "04_network_ports.txt"

# ==============================================================================
# 4. INFRAESTRUCTURA GENERAL
# ==============================================================================
gestionar_y_ejecutar "uptime" "procps-ng" "Carga del Sistema" "uptime" "05_system_load.txt"
gestionar_y_ejecutar "bash" "bash" "Limites de Usuario (Ulimits)" "ulimit -a" "05_system_ulimits.txt"
gestionar_y_ejecutar "dmesg" "util-linux" "Logs Kernel (Errores)" "dmesg | grep -i 'error\|fail\|warn\|killed' | tail -n 50" "05_kernel_errors.txt"

# ==============================================================================
# 5. WEBSPHERE & JAVA GENERAL
# ==============================================================================
# Procesos Java (Cubre ODM, BAW, WAS)
gestionar_y_ejecutar "ps" "procps-ng" "Procesos Java (IBM Middleware)" "ps -eo pid,user,pcpu,pmem,args --sort=-pcpu | grep [j]ava" "06_java_processes.txt"

# Estimación de transacciones (Busca en RUTAS_IBM definidas arriba)
gestionar_y_ejecutar "find" "findutils" "Logs Transacciones WAS" \
    "find $RUTAS_IBM -name 'SystemOut.log' -o -name 'messages.log' 2>/dev/null | xargs tail -n 1000 | grep -i 'J2CA\|PMRM\|WTRN' || echo 'No logs found'" \
    "07_transactions_estimate.txt"

# ==============================================================================
# 6. MÓDULO FILENET
# ==============================================================================
echo " .. [MÓDULO FILENET] Validando..."
gestionar_y_ejecutar "ps" "procps-ng" "Procesos FileNet" "ps -ef | grep -i 'FileNet\|ContentEngine' | grep -v grep" "08_filenet_processes.txt"
gestionar_y_ejecutar "ss" "iproute" "Puertos FileNet" "ss -tulnp | grep -E ':2809|:9100|:9300'" "08_filenet_ports.txt"

# ==============================================================================
# 7. MÓDULO IBM ODM
# ==============================================================================
echo " .. [MÓDULO IBM ODM] Validando..."

# A. Identificación
gestionar_y_ejecutar "find" "findutils" "Instalación ODM Detectada" \
    "find /opt /usr /home -type d \( -name 'executionserver' -o -name 'teamserver' \) 2>/dev/null || echo 'Directorios ODM no encontrados'" \
    "09_odm_install_path.txt"

# B. Procesos
gestionar_y_ejecutar "ps" "procps-ng" "Procesos ODM Activos" \
    "ps -ef | grep -E 'jrules|decisioncenter|teamserver|res-console' | grep -v grep" \
    "09_odm_processes.txt"

# C. Logs errores (Usa RUTAS_IBM)
gestionar_y_ejecutar "find" "findutils" "Logs Errores ODM (ILOG/GBR)" \
    "find $RUTAS_IBM -name 'SystemOut.log' -o -name 'messages.log' 2>/dev/null | xargs tail -n 500 | grep -E 'Ilr|GBR|XOM' || echo 'Sin errores recientes de ODM'" \
    "09_odm_rule_errors.txt"

# D. Base de Datos
gestionar_y_ejecutar "netstat" "net-tools" "Conexiones BD (RES Repository)" \
    "netstat -an | grep ESTABLISHED | grep -E ':1521|:50000|:1433|:5432' | wc -l && echo ' conexiones a BD detectadas'" \
    "09_odm_db_connectivity.txt"

# ==============================================================================
# 8. MÓDULO IBM BPM (Legacy)
# ==============================================================================
echo " .. [IBM BPM] Validando..."

gestionar_y_ejecutar "find" "findutils" "Configuración BPM (100Custom)" \
    "find $RUTAS_IBM -name '100Custom.xml' 2>/dev/null | head -n 5 || echo 'No encontrado'" \
    "10_bpm_config_files.txt"

gestionar_y_ejecutar "ss" "iproute" "Estado SIBus (Messaging)" \
    "ss -tulnp | grep -E ':7276|:7286|:5558' || echo 'SIBus no detectado'" \
    "10_bpm_sibus_ports.txt"

gestionar_y_ejecutar "find" "findutils" "Logs Errores BPM (WLE)" \
    "find $RUTAS_IBM -name 'SystemOut.log' 2>/dev/null | xargs tail -n 500 | grep -i 'WLE' || echo 'Sin errores recientes WLE'" \
    "10_bpm_wle_errors.txt"

# ==============================================================================
# 9. MÓDULO IBM BAW (Modern Workflow)
# ==============================================================================
echo " .. [IBM BAW] Validando..."

# A. Identidad
gestionar_y_ejecutar "find" "findutils" "Identidad BAW (SWID Tags)" \
    "find /opt /usr /var -name '*.swidtag' -print0 | xargs -0 grep -l 'Business Automation Workflow' || echo 'No se encontraron etiquetas de BAW'" \
    "11_baw_identity_swid.txt"

# B. Case Manager
gestionar_y_ejecutar "find" "findutils" "Ruta Case Management" \
    "find $RUTAS_IBM -type d -name 'CaseManagement' 2>/dev/null || echo 'Componente Case no encontrado'" \
    "12_baw_case_path.txt"

# C. Logs Case
gestionar_y_ejecutar "find" "findutils" "Logs Errores Case (ICM)" \
    "find $RUTAS_IBM -name 'SystemOut.log' 2>/dev/null | xargs tail -n 500 | grep -E 'ICM|CPEC|CaseClient' || echo 'Sin errores recientes de Case'" \
    "13_baw_case_errors.txt"

# D. Content Navigator
gestionar_y_ejecutar "ps" "procps-ng" "Procesos ICN (Navigator)" \
    "ps -ef | grep -i 'nexus' | grep -v grep || echo 'Proceso Navigator no evidente'" \
    "14_baw_navigator_proc.txt"



audit_java() {
    local OUTfile="${DIRECTORIO_BASE}/15_java_installed_details.txt"
    
    # Iniciar archivo (o limpiarlo si existe)
    echo "==========================================" > "$OUTfile"
    echo " REPORTE DE INSTALACIÓN JAVA" >> "$OUTfile"
    echo " Fecha: $(date +'%Y-%m-%d %H:%M:%S')" >> "$OUTfile"
    echo " Sistema: $(cat /etc/os-release | grep -w "NAME" | cut -d= -f2 | tr -d '\"')" >> "$OUTfile"
    echo "==========================================" >> "$OUTfile"

    # 1. VERIFICAR SI JAVA ES ACCESIBLE EN EL PATH (JAVA PRINCIPAL)
    if command -v java &> /dev/null; then
        echo -e "\n[+] JAVA PRINCIPAL (ACTIVO EN PATH):" >> "$OUTfile"
        
        # Obtener la ruta real resolviendo enlaces simbólicos
        local main_path=$(readlink -f $(command -v java))
        echo "    Ruta binario: $main_path" >> "$OUTfile"
        
        # Obtener versión (Java imprime la versión en stderr, por eso 2>&1)
        echo "    Versión detectada:" >> "$OUTfile"
        java -version 2>&1 | sed 's/^/        /' >> "$OUTfile"
    else
        echo -e "\n[!] JAVA NO DETECTADO EN EL PATH ACTUAL." >> "$OUTfile"
        echo "No se encontraron instalaciones adicionales." >> "$OUTfile"
        return
    fi

    # 2. BUSCAR OTRAS INSTALACIONES (USANDO ALTERNATIVES)
    echo -e "\n[+] OTRAS INSTALACIONES / LISTA COMPLETA:" >> "$OUTfile"
    echo "    (Rutas registradas en el sistema alternatives)" >> "$OUTfile"

    # Lógica híbrida para Debian/Ubuntu y RHEL
    if command -v update-alternatives &> /dev/null; then
        # Método Ubuntu/Debian (y algunos RHEL modernos)
        # Intentamos --list primero (común en Debian)
        if ! update-alternatives --list java 2>>"$OUTfile" >> "$OUTfile"; then
             # Si falla --list, intentamos parsing de --display (RHEL fallback)
             alternatives --display java | grep -E '^/' | awk '{print "    - " $1}' >> "$OUTfile"
        fi
    elif command -v alternatives &> /dev/null; then
        # Método RHEL Legacy / CentOS puro
        alternatives --display java | grep -E '^/' | awk '{print "    - " $1}' >> "$OUTfile"
    else
        echo "    No se pudo consultar el comando 'update-alternatives' o 'alternatives'." >> "$OUTfile"
    fi

    # Marcar cuál es la principal visualmente en la lista
    # (Buscamos la ruta principal dentro del archivo y le agregamos una marca si se desea, 
    # pero ya está explicito en la sección 1).

    echo -e "\nReporte generado exitosamente en: $OUTfile"
    cat "$OUTfile"
}

audit_java

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
