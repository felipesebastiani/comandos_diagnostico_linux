#!/bin/bash

# ****************************************************************************************** # 
# * - DESCRIPCION: Shell para validación & generación de CLUSTER HEALTH REPORT (OPENSHIFT) *
# * - EJECUCION:   SHELL                                                                   *
# * - AUTOR:       Guerra Arnaiz, Cesar Ricardo       (Health)                             *
# * - COAUTOR:     Sebastiani Sobenes, Felipe Roberto (Health, Stability, Productivity)    *
# * - FECHA:       04/12/2025                                                              *
# * - VERSION:     2.0 (Enhanced with IBM Matrix)                                          *
# * - ALCANCE:     Kubernetes Base + IBM Cloud Paks                                        *
# ****************************************************************************************** 

clear

vCURRENT_DATE=`date +%Y%m%d%H%M%S`
vTRANSACTION="$vCURRENT_DATE - [INFO]": 
vWAIT_TIME=4
vDATE_LOG=`date +%Y%m%d`

# NOTA: Se recomienda usar variables de entorno o un ServiceAccount para no exponer credenciales en texto plano
USERNAME="admin"
PASSWORD="xxx"
TOKEN_NAME="sha256~8u_hOjnLFLTr6aA2Wpq6puwErKKb5Qc9DyN0qaaPfY4"
API_SERVER="https://c100-e.us-south.containers.cloud.ibm.com:30807"
REPORT_LOG_NAME="cluster-health-report-v2.log"

echo ""
echo "${vTRANSACTION} *********************** [PROCESO 'CLUSTER HEALTH REPORT': 'STARTING'] ***********************"
echo "${vTRANSACTION}> EJECUTANDO SCRIPT..."
echo ""

echo "${vTRANSACTION}> 0. Eliminando REPORTE anterior..."  
rm -f ${REPORT_LOG_NAME}

exec &> >(tee -a "${REPORT_LOG_NAME}")
echo ""
echo ""

# Validacion de dependencia JQ
if ! command -v jq &> /dev/null; then
    echo "${vTRANSACTION} [WARNING] 'jq' no está instalado. Algunas validaciones avanzadas de JSON no se mostrarán correctamente."
fi

echo "${vTRANSACTION}> 1. Autenticando en OPENSHIFT..." 
echo ""
# Nota: Si ya estas logueado, puedes comentar estas lineas
# echo "${vTRANSACTION}> [oc login --server=${API_SERVER} --username=${USERNAME} --password=${PASSWORD}]"
# oc login --server=${API_SERVER} --username=${USERNAME} --password=${PASSWORD} --insecure-skip-tls-verify
# echo ""
# echo "${vTRANSACTION}> [oc login --token=${TOKEN_NAME} --server=${API_SERVER}]"
# oc login --token=${TOKEN_NAME} --server=${API_SERVER} --insecure-skip-tls-verify
 
 
echo ""
echo "" 
echo "${vTRANSACTION}> 2. Validando información del CLÚSTER, la VERSIÓN (ACTUAL) & las VERSIONES (DISPONIBLEs) en el CLUSTER..."
echo ""
echo "${vTRANSACTION}> [oc version]"
oc version
echo ""
echo "${vTRANSACTION}> [oc cluster-info]"
oc cluster-info
echo ""
echo "${vTRANSACTION}> [oc get clusterversion]" 
oc get clusterversion
echo ""
echo "${vTRANSACTION}> [oc adm upgrade]" 
oc adm upgrade 

 
echo ""
echo ""
echo "${vTRANSACTION}> 3. Validando NODOS (MASTER/WORKER)..."
echo ""
echo "${vTRANSACTION}> [oc get nodes -o wide]"
oc get nodes -o wide
echo ""
echo "${vTRANSACTION}> [oc get nodes -l node-role.kubernetes.io/master]"
oc get nodes -l node-role.kubernetes.io/master
echo ""
echo "${vTRANSACTION}> [oc get nodes -l node-role.kubernetes.io/worker]"
oc get nodes -l node-role.kubernetes.io/worker
 
 
echo ""
echo ""
echo "${vTRANSACTION}> 4. Validando USUARIOS & GRUPOS...."
echo ""
echo "${vTRANSACTION}> [oc get users]"
oc get users
echo ""
echo "${vTRANSACTION}> [oc get groups]" 
oc get groups


echo ""
echo ""
echo "${vTRANSACTION}> 5. Validando PERSISTENT-VOLUME, PERSISTENT-VOLUME-CLAIM & STORAGE-CLASSES..."
echo ""
echo "${vTRANSACTION}> [oc get pv --all-namespaces]" 
oc get pv --all-namespaces
echo ""
echo "${vTRANSACTION}> [oc get pvc --all-namespaces]" 
oc get pvc --all-namespaces
echo ""
echo "${vTRANSACTION}> [oc get storageclass --all-namespaces]" 
oc get storageclass --all-namespaces


echo ""
echo ""
echo "${vTRANSACTION}> 6. Validando PERSISTENT-VOLUME (STORAGE) utilizados por PODs..."
echo ""
echo "${vTRANSACTION}> [Obteniendo STORAGE utilizados por PODs]" 
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
echo "${vTRANSACTION}> 7. Validando OPERATORs (HEALTHCHECK MATRIZ: CSV STATUS)..."
echo "INFO: Buscando operadores que NO estén en estado 'Succeeded'..."
echo ""
echo "${vTRANSACTION}> [oc get csv -A | grep -v Succeeded]" 
oc get csv -A | grep -v Succeeded
echo ""
echo "${vTRANSACTION}> [oc get clusteroperators]" 
oc get clusteroperators


echo ""
echo ""
echo "${vTRANSACTION}> 8. Validando PODs..."
echo ""
echo "${vTRANSACTION}> [oc get pods --all-namespaces]"
oc get pods --all-namespaces


echo ""
echo ""
echo "${vTRANSACTION}> 9. Validando ESTABILIDAD DE PODs (RESTARTS & ERRORS)..."
echo "INFO: Validando criterio de Salud '0 Restarts reciente' y estados anómalos."
echo ""
echo "${vTRANSACTION}> [Pods con REINICIOS > 0 (Inestabilidad Potencial)]"
oc get pods -A --sort-by='.status.containerStatuses[0].restartCount' | grep -v "0         0"
echo ""
echo "${vTRANSACTION}> [Pods en estado NO RUNNING/COMPLETED]" 
oc get pods --all-namespaces -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.phase)"'


echo ""
echo ""
echo "${vTRANSACTION}> 10. Validando DEPLOYMENTs & DEPLOYMENTCONFIGs..."
echo ""
echo "${vTRANSACTION}> [oc get deployments --all-namespaces]"
oc get deployments --all-namespaces
echo ""
echo "${vTRANSACTION}> [oc get deploymentconfigs --all-namespaces]"
oc get deploymentconfigs --all-namespaces


echo ""
echo "" 
echo "${vTRANSACTION}> 11. Validando SERVICEs & ROUTEs..."
echo ""
echo "${vTRANSACTION}> [oc get services --all-namespaces]"
oc get services --all-namespaces
echo ""
echo "${vTRANSACTION}> [oc get routes  --all-namespaces]"
oc get routes  --all-namespaces


echo ""
echo ""
echo "${vTRANSACTION}> 12. Validando IMAGESTREAMs..."
echo ""
echo "${vTRANSACTION}> [oc get imagestreams --all-namespaces]"
oc get imagestreams --all-namespaces


echo ""
echo "" 
echo "${vTRANSACTION}> 13. Validando NETWORKPOLICIEs..."
echo ""
echo "${vTRANSACTION}> [oc get networkpolicies --all-namespaces]"
oc get networkpolicies --all-namespaces


echo ""
echo "" 
echo "${vTRANSACTION}> 14. Validando CAPACIDAD & CONSUMO de RECURSOS [CPU/RAM] (MATRIZ: LICENCIAS vs USO)..."
echo "INFO: Comparar Requested vs Limits para validar QoS Class (Guaranteed para DBs/Core)"
echo ""
echo "${vTRANSACTION}> [oc adm top nodes]"
oc adm top nodes
echo ""
echo "${vTRANSACTION}> [oc adm top pods -A --containers (Top Consumers)]"
# Muestra solo los pods que usan más recursos, util para detectar desviaciones de licencias
oc adm top pods -A --containers | sort -rn -k3 | head -n 20
echo ""
echo "${vTRANSACTION}> [Allocated Resources per Node]"
oc get nodes -o=custom-columns=NODE:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory --no-headers | awk '{printf "%s\t%s\t%.2fMi\n", $1, $2, $3/1024/1024}'
 

echo ""
echo "" 
echo "${vTRANSACTION}> 15. Validando CERTIFICADOS (MATRIZ: EXPIRACION)..."
echo "INFO: Revisar fechas < 30 días para evitar caídas de comunicación interna."
echo ""
echo -e "NAMESPACE\tNAME\tEXPIRY" && oc get secrets -A -o go-template='{{range .items}}{{if eq .type "kubernetes.io/tls"}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{" "}}{{index .data "tls.crt"}}{{"\n"}}{{end}}{{end}}' | while read namespace name cert; do echo -en "$namespace\t$name\t"; echo $cert | base64 -d | openssl x509 -noout -enddate; done | column -t


echo ""
echo "${vTRANSACTION}> 16. Validando existencia de MACHINES & MACHINECONFIGPOOL..."
echo ""
echo "${vTRANSACTION}> [oc get machineconfigpool]"
oc get machineconfigpool
echo ""
echo "${vTRANSACTION}> [oc get machines -n openshift-machine-api]"
oc get machines -n openshift-machine-api 
 

echo ""
echo "" 
echo "${vTRANSACTION}> 17. Validando CSR (Certificate Signing Requests)..."
echo ""
echo "${vTRANSACTION}> [oc get csr]"
oc get csr 

# ******************************************************************************************
# * NUEVAS SECCIONES BASADAS EN LA MATRIZ DE SALUD IBM (Health, Stability, Productivity)   *
# ******************************************************************************************

echo ""
echo ""
echo "${vTRANSACTION}> 21. [MATRIZ-HEALTHCHECK]: Validando Instancias IBM Cloud Pak & Foundation..."
echo "INFO: Verificando estado de CRs principales (CP4BA, MQ, Db2, Bedrock)"
echo ""
echo "${vTRANSACTION}> [IBM Common Services (Bedrock) Health]"
oc get pod -n ibm-common-services -o wide | grep -v Running
echo ""
echo "${vTRANSACTION}> [IBM Custom Resources Status]"
# Busca CRs comunes de IBM y muestra su estado. Ignora errores si no existen.
oc get icp4acluster,qmgr,db2u,wfs,odm -A --ignore-not-found -o custom-columns=KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VERSION:.spec.appVersion

echo ""
echo ""
echo "${vTRANSACTION}> 22. [MATRIZ-ESTABILIDAD]: Validando Eventos Críticos & OOM..."
echo "INFO: Buscando eventos de Error recientes y Pods eliminados por falta de memoria (OOMKilled)."
echo ""
echo "${vTRANSACTION}> [Eventos de Advertencia/Error (Últimos 20)]"
oc get events -A --sort-by='.lastTimestamp' | grep -E 'Warning|Failed|Error' | tail -n 30
echo ""
echo "${vTRANSACTION}> [Pods terminados por OOMKilled (Out of Memory)]"
oc get pods -A -o go-template='{{range .items}}{{$ns := .metadata.namespace}}{{$nm := .metadata.name}}{{range .status.containerStatuses}}{{if .lastState.terminated}}{{if eq .lastState.terminated.reason "OOMKilled"}}{{$ns}} {{$nm}} "OOMKilled"{{printf "\n"}}{{end}}{{end}}{{end}}{{end}}'

echo ""
echo ""
echo "${vTRANSACTION}> 23. [MATRIZ-PRODUCTIVIDAD]: Limpieza y Autoscaling..."
echo "INFO: Identificando basura (Evicted/Completed) y estado de HPA."
echo ""
echo "${vTRANSACTION}> [Horizontal Pod Autoscalers (HPA) Activos]"
oc get hpa -A
echo ""
echo "${vTRANSACTION}> [Pods 'Evicted' o 'Completed' que ensucian el cluster]"
oc get pods -A | grep -E 'Evicted|Completed' | head -n 30
echo "... (Lista truncada a 30 items. Si existen, considerar ejecutar limpieza)"


# ******************************************************************************************
# * FIN SECCIONES BASADAS EN LA MATRIZ DE SALUD IBM (Health, Stability, Productivity)   *
# ******************************************************************************************
  
echo ""
echo ""
echo "${vTRANSACTION}> 24. Validando DESPLIEGUE de APP (TEST DE CONECTIVIDAD)..."
echo ""
NAMESPACE_NAME="dummy-test-health-$$" # Usar PID para nombre unico
echo "${vTRANSACTION}> [oc create ns ${NAMESPACE_NAME}]"
oc create ns ${NAMESPACE_NAME}

echo ""
echo "${vTRANSACTION}> [Ejecutando YAML para el DEPLOYMENT del SERVICIO]"
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-micro-deploy
  namespace: ${NAMESPACE_NAME}
  labels:
    app: dummy-micro-service
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dummy-micro-service
      version: v1
  template:
    metadata:
      labels:
        app: dummy-micro-service
        version: v1
    spec:
      containers:
      - image: image-registry.openshift-image-registry.svc:5000/openshift/httpd:latest
        # Nota: Usamos httpd interno o una imagen segura. La original 'maktup/dummy' podría no existir.
        # Fallback a una imagen muy comun si no tienes acceso a internet:
        # image: k8s.gcr.io/echoserver:1.4
        name: dummy-micro-container
        resources:
          limits:
            cpu: 300m
          requests:
            cpu: 100m
        ports:
        - containerPort: 8080
EOF

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dummy-micro-service
  namespace: ${NAMESPACE_NAME}
  labels:
    app: dummy-micro-service
spec:
  type: ClusterIP
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: dummy-micro-service
EOF

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: dummy-micro-route
  namespace: ${NAMESPACE_NAME}
  labels:
    app: dummy-micro-service
spec:
  port:
    targetPort: 8080
  to:
    kind: Service
    name: dummy-micro-service
EOF


echo ""
echo "" 
echo "${vTRANSACTION}> 25. Validando TEST de SERVICIO..."
# Pequeña espera para que el pod arranque
sleep 20
ROUTE_URL=$(oc get route dummy-micro-route -n ${NAMESPACE_NAME} -o jsonpath='{.spec.host}')
echo "${vTRANSACTION}> URL Detectada: http://${ROUTE_URL}"
echo "${vTRANSACTION}> Esperando 30 seg para estabilizacion..."
sleep 30

if [[ -z "$ROUTE_URL" ]]; then
    echo "${vTRANSACTION}> [ERROR] No se pudo obtener la ROUTE. Test fallido."
else
    echo "${vTRANSACTION}> [curl -s --head http://${ROUTE_URL}]"
    curl -s --head http://${ROUTE_URL}
fi

echo ""
echo "" 
echo "${vTRANSACTION}> 26. Limpiando RECURSOS creados para el TEST..."
echo "" 
echo "${vTRANSACTION}> [oc delete ns ${NAMESPACE_NAME}]"
oc delete ns ${NAMESPACE_NAME} --wait=false


echo ""
echo ""
echo "${vTRANSACTION} *********************** [PROCESO 'CLUSTER HEALTH REPORT': 'TERMINADO'] ***********************"
echo "${vTRANSACTION}> Exportando REPORTE de LOG: [${REPORT_LOG_NAME}]..."
echo ""
