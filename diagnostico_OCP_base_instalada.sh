#!/bin/bash

# ***************************************************************************************************
# * - DESCRIPCION: Shell para obtener INSTALLED BASE REPORT (Incluye IBM CP4BA)                     *
# * - EJECUCION:   SHELL                                                                            *
# * - AUTOR:           Guerra Arnaiz, Cesar Ricardo                                                 *
# * - MODIFICADO POR:  Sebastiani Sobenes, Felipe Roberto                                           *
# * - FECHA:       04/12/2025                                                                       *
# * - VERSION:     2.1 (CP4BA Enhanced)                                                             *
# ***************************************************************************************************

clear

vCURRENT_DATE=`date +%Y%m%d%H%M%S`
vTRANSACTION="$vCURRENT_DATE - [INFO]": 
vWAIT_TIME=4
vDATE_LOG=`date +%Y%m%d`

# NOTA: Se recomienda usar 'oc login' antes de ejecutar el script en lugar de hardcodear tokens
USERNAME="admin"
PASSWORD="xxx"
TOKEN_NAME="sha256~8u_hOjnLFLTr6aA2Wpq6puwErKKb5Qc9DyN0qaaPfY4" 
API_SERVER="https://c100-e.us-south.containers.cloud.ibm.com:30807"
REPORT_LOG_NAME="installed_base_report.log"

echo ""
echo "${vTRANSACTION} *********************** [PROCESO 'INSTALLED BASE REPORT': 'STARTING'] ***********************"
echo "${vTRANSACTION}> EJECUTANDO SCRIPT..."
echo ""

# Validar dependencia jq
if ! command -v jq &> /dev/null; then
    echo "${vTRANSACTION} [ERROR] 'jq' no esta instalado. Es necesario para procesar los datos de CP4BA."
    exit 1
fi

echo "${vTRANSACTION}> [COMMAND #0]. Eliminando REPORTE anterior..."  
rm -f ${REPORT_LOG_NAME}

exec &> >(tee -a "${REPORT_LOG_NAME}")
echo ""
echo ""
 
echo "${vTRANSACTION}> [COMMAND #1]: ¿QUE 'PLATAFORMA / S.O / CLOUD' SE TIENE INSTALADA?" 
cat /etc/*release
echo ""
uname -r
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #2]: ¿QUE VERSIÓN DE 'OPENSHIFT / KUBERNETES' SE TIENE INSTALADA?"
oc version
echo ""
kubectl version
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #3]: ¿CUANTOS 'NODOS' TIENEN ACTIVOS?"
oc get nodes -o wide
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #4]: ¿CUANTA 'CPU/MEMORIA' SE TIENE ASIGNADO & EN USO POR CADA 'VIRTUAL MACHINE'?"
# Nota: kubectl top requiere metrics-server instalado
if oc get apiservice v1beta1.metrics.k8s.io &> /dev/null; then
    oc adm top node --use-protocol-buffers
else
    echo " [WARN] Metrics Server no detectado. Saltando 'oc adm top node'."
fi
echo ""
oc get nodes -o=custom-columns=NODE:.metadata.name,CPU_CAP:.status.capacity.cpu,MEM_CAP:.status.capacity.memory
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #5]: ¿CUANTO 'STORAGE' (PV) & QUE TIPO SE TIENE UTILIZANDO EN EL CLUSTER?"
oc get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,CLAIM:.spec.claimRef.name,STATUS:.status.phase,STORAGE_CLASS:.spec.storageClassName
echo ""  
echo ""

echo "${vTRANSACTION}> [COMMAND #6]: ¿CUANTAS CAPACIDADES DE 'CLOUD-PAK (GENERICO)' TIENE INSTALADO?"
oc get operators 
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #7]: ¿CUANTAS INSTANCIAS DE: 'MQ' SE TIENE INSTALADO?"
oc get QueueManagers --all-namespaces    
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #8]: ¿CUANTAS INSTANCIAS DE: 'IBM APP CONNECT' SE TIENE INSTALADO?"
oc get Dashboard --all-namespaces
echo ""
oc get IntegrationServer --all-namespaces
echo ""
oc get IntegrationRuntime --all-namespaces
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #9]: ¿CUANTAS INSTANCIAS DE: 'IBM API CONNECT' & COMPONENTES SE TIENE INSTALADO?"
oc get apic --all-namespaces
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #10]: ¿CUANTAS INSTANCIAS DE: 'EVENT-STREAMS' SE TIENE INSTALADO?"
oc get EventStreams --all-namespaces 
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #11]: ¿CUANTO STORAGE (PV) SE TIENE ASIGNADO POR CADA NODO INSTALADO?"
oc get pods --all-namespaces --no-headers -o custom-columns=NODE:.spec.nodeName,NAMESPACE:.metadata.namespace,POD:.metadata.name,PVC:.spec.volumes[*].persistentVolumeClaim.claimName | \
while IFS=' ' read -r vNODE vNAMESPACE vPOD vPVC ; do
    if [ "$vPVC" != "<none>" ]; then
        vPV=$(oc get pvc "$vPVC" -o=jsonpath='{.spec.volumeName}' -n "$vNAMESPACE" 2>/dev/null)
        if [ -n "$vPV" ]; then
            vPV_DETAILS=$(oc get pv "$vPV" -o jsonpath='{.spec}' 2>/dev/null)
            if [ -n "$vPV_DETAILS" ]; then
                vCAPACIDAD=$(echo "$vPV_DETAILS" | jq -r '.capacity.storage // "-"')
                echo -e "NODE: $vNODE \t CAPACITY: $vCAPACIDAD \t PVC: $vPVC" 
            fi 
        fi 
    fi 
done
echo ""
echo ""

# *********************************************************************************
# * SECCION: IBM CLOUD PAK FOR BUSINESS AUTOMATION (CP4BA)                  *
# *********************************************************************************

echo "${vTRANSACTION}> [COMMAND #12]: CP4BA - VALIDACION DE OPERADORES DE AUTOMATION"
echo "Buscando operadores relacionados con 'ibm-cp4a', 'filenet', 'odm', 'baw'..."
oc get csv -A | grep -E 'business-automation|filenet|odm|baw|cp4a'
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #13]: CP4BA - DESPLIEGUE PRINCIPAL (ICP4ACluster)"
echo "Verificando el Custom Resource principal de la instalacion CP4BA..."
# Busca el recurso principal que orquesta la instalacion
oc get icp4acluster -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VERSION:.spec.appVersion
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #14]: CP4BA - FILENET CONTENT MANAGER (FNCM)"
echo "Verificando componentes de Content (CPE, ICN, GraphQL, CSS)..."
# FNCM suele desplegarse via ContentCluster o componentes individuales
oc get contentcluster -A 2>/dev/null
echo "-- Content Initialization Status --"
oc get contentinitialization -A 2>/dev/null
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #15]: CP4BA - OPERATIONAL DECISION MANAGER (ODM)"
echo "Verificando instancias de Decision Center, Decision Server, Runner..."
oc get decisionservice -A 2>/dev/null
oc get decisioncenter -A 2>/dev/null
oc get decisionrunner -A 2>/dev/null
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #16]: CP4BA - BUSINESS AUTOMATION WORKFLOW (BAW)"
echo "Verificando servidores de Workflow (BAW Runtime / Authoring)..."
# En versiones modernas se usa IBM Business Automation Workflow Authoring o Server
oc get ibmcpcs -A 2>/dev/null
oc get wfs -A 2>/dev/null
echo ""
echo ""

echo "${vTRANSACTION}> [COMMAND #17]: CP4BA - DETALLE DE PODS, CORES (vCPU) Y MEMORIA"
echo "Listando pods especificos de CP4BA y sus recursos asignados (Requests/Limits)..."

# Iteramos sobre todos los pods que coincidan con patrones de nombres comunes de CP4BA
# Patrones: cpe (Content Engine), icn (Navigator), odm (Decision), baw/wfs (Workflow), rr (Resource Registry), ums
# Se excluyen pods de sistema o operadores genéricos para limpiar la vista, enfocandose en cargas de trabajo.

oc get pods -A --no-headers | grep -E 'cpe-|icn-|odm-|baw-|jms-|ier-|tm-|ads-|rr-' | awk '{print $1, $2}' | \
while read -r NS POD; do
    # Extraemos info cruda en JSON
    POD_DATA=$(oc get pod "$POD" -n "$NS" -o json)
    
    # Extraemos Request y Limits de CPU/Memoria sumando todos los contenedores del pod
    CPU_REQ=$(echo "$POD_DATA" | jq -r '[.spec.containers[].resources.requests.cpu // "0"] | map(select(. != "0")) | join("+")')
    CPU_LIM=$(echo "$POD_DATA" | jq -r '[.spec.containers[].resources.limits.cpu // "0"] | map(select(. != "0")) | join("+")')
    MEM_REQ=$(echo "$POD_DATA" | jq -r '[.spec.containers[].resources.requests.memory // "0"] | map(select(. != "0")) | join("+")')
    MEM_LIM=$(echo "$POD_DATA" | jq -r '[.spec.containers[].resources.limits.memory // "0"] | map(select(. != "0")) | join("+")')
    
    # Intentamos obtener uso actual si metrics server funciona
    USAGE_CPU="N/A"
    USAGE_MEM="N/A"
    if oc get apiservice v1beta1.metrics.k8s.io &> /dev/null; then
         USAGE_RAW=$(kubectl top pod "$POD" -n "$NS" --no-headers 2>/dev/null)
         if [ ! -z "$USAGE_RAW" ]; then
            USAGE_CPU=$(echo "$USAGE_RAW" | awk '{print $2}')
            USAGE_MEM=$(echo "$USAGE_RAW" | awk '{print $3}')
         fi
    fi

    echo "----------------------------------------------------------------"
    echo "NAMESPACE : $NS"
    echo "POD       : $POD"
    echo "CPU       : [Request: $CPU_REQ] [Limit: $CPU_LIM] [Uso Actual: $USAGE_CPU]"
    echo "MEMORY    : [Request: $MEM_REQ] [Limit: $MEM_LIM] [Uso Actual: $USAGE_MEM]"
done

echo ""
echo ""
echo "${vTRANSACTION} *********************** [PROCESO 'INSTALLED BASE REPORT': 'TERMINADO'] ***********************"
echo "${vTRANSACTION}> Exportando REPORTE de LOG: [${REPORT_LOG_NAME}]..."
echo ""
