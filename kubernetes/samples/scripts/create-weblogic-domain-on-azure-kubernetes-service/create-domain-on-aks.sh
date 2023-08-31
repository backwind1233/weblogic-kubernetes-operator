#!/usr/bin/env bash
# Copyright (c) 2018, 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# Description
#  This sample script creates a WebLogic Server domain home on the Azure Kubernetes Service (AKS).
#  It creates a new Azure resource group, with a new Azure Storage Account and Azure File Share to allow WebLogic
#  to persist its configuration and data separately from the Kubernetes pods that run WebLogic workloads.
#  Besides, it also generates the domain resource yaml files, which can be used to restart the Kubernetes
#  artifacts of the corresponding domain.
#
#  The Azure resource deployment is customized by editing
#  create-domain-on-aks-inputs.yaml. If you also want to customize
#  WebLogic Server domain configuration, please edit
#  kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv/create-domain-inputs.yaml.  Or you can create a copy of this file and edit it and refer to the copy using "-d <your-domain-inputs.yaml>".
#
#  The following pre-requisites must be handled prior to running this script:
#    * Environment has set up, with git, azure cli, kubectl and helm installed.
#    * The user must have accepted the license terms for the WebLogic Server docker
#      images in Oracle Container Registry.
#      See https://oracle.github.io/weblogic-kubernetes-operator/quickstart/get-images/
#    * The Azure Service Principal must have been created, with permission to
#      create AKS.

# Initialize
script="${BASH_SOURCE[0]}"
scriptDir="$(cd "$(dirname "${script}")" && pwd)"

#
# Parse the command line options
#
executeIt=false
while getopts "ehi:o:u:d:" opt; do
  case $opt in
  i)
    valuesInputFile="${OPTARG}"
    ;;
  o)
    outputDir="${OPTARG}"
    ;;
  u)
    azureResourceUID="${OPTARG}"
    ;;
  e)
    executeIt=true
    ;;
  d)
    domainInputFile="${OPTARG}"
    ;;
  h)
    usage 0
    ;;
  *)
    usage 1
    ;;
  esac
done

if [ -z ${valuesInputFile} ]; then
  echo "${script}: -i must be specified."
  missingRequiredOption="true"
fi

if [ -z ${outputDir} ]; then
  echo "${script}: -o must be specified."
  missingRequiredOption="true"
fi

if [ "${missingRequiredOption}" == "true" ]; then
  usage 1
fi

if [ -z "${azureResourceUID}" ]; then
  azureResourceUID=$(date +%s)
fi

#
# Function to exit and print an error message
# $1 - text of message
fail() {
  echo [ERROR] $*
  exit 1
}

#
# Function to initialize and validate the output directory
# for the generated yaml files for this domain.
#
initOutputDir() {
  aksOutputDir="$outputDir/weblogic-on-aks"

  scOutput="${aksOutputDir}/azure-csi-nfs.yaml"
  pvcOutput="${aksOutputDir}/pvc.yaml"
  adminLbOutput="${aksOutputDir}/admin-lb.yaml"
  clusterLbOutput="${aksOutputDir}/cluster-lb.yaml"
  domain1Output="${aksOutputDir}/domain1.yaml"

  removeFileIfExists ${scOutput}
  removeFileIfExists ${pvcOutput}
  removeFileIfExists ${adminLbOutput}
  removeFileIfExists ${clusterLbOutput}
  removeFileIfExists ${domain1Output}
  removeFileIfExists ${aksOutputDir}/create-domain-on-aks-inputs.yaml
}

#
# Function to setup the environment to run the create Azure resource and domain job
#
initialize() {

  source ./create-domain-on-aks-input.sh
  
  # Generate Azure resource name
  export azureResourceGroupName="${namePrefix}resourcegroup${azureResourceUID}"
  export aksClusterName="${namePrefix}akscluster${azureResourceUID}"
  export storageAccountName="${namePrefix}storage${azureResourceUID}"

  export azureFileShareSecretName="${namePrefix}${azureFileShareSecretNameSuffix}"
  export azureKubernetesNodepoolName="${azureKubernetesNodepoolNamePrefix}${namePrefix}"
  export azureStorageShareName="${namePrefix}-${azureStorageShareNameSuffix}-${azureResourceUID}"
  export imagePullSecretName="${namePrefix}${imagePullSecretNameSuffix}"
  export persistentVolumeClaimName="${namePrefix}-${persistentVolumeClaimNameSuffix}-${azureResourceUID}"
  export persistentVolumeId="${namePrefix}-${persistentVolumeClaimNameSuffix}-${azureResourceUID}"
}


createResourceGroup() {
  az extension add --name resource-graph

  # Create a resource group
  echo Check if ${azureResourceGroupName} exists
  ret=$(az group exists --name ${azureResourceGroupName})
  if [ $ret != false ]; then
    fail "${azureResourceGroupName} exists, please change value of namePrefix to generate a new resource group name."
  fi

  echo Creating Resource Group ${azureResourceGroupName}
  az group create --name $azureResourceGroupName --location $azureLocation
}

createAndConnectToAKSCluster() {
  # Create aks cluster
  echo Check if ${aksClusterName} exists
  ret=$(az aks list -g ${azureResourceGroupName} | grep "${aksClusterName}")
  if [ -n "$ret" ]; then
    fail "AKS instance with name ${aksClusterName} exists."
  fi

  echo Creating Azure Kubernetes Service ${aksClusterName}
  az aks create --resource-group $azureResourceGroupName \
  --name $aksClusterName \
  --vm-set-type VirtualMachineScaleSets \
  --node-count ${azureKubernetesNodeCount} \
  --generate-ssh-keys \
  --nodepool-name ${azureKubernetesNodepoolName} \
  --node-vm-size ${azureKubernetesNodeVMSize} \
  --location $azureLocation \
  --enable-managed-identity

  # Connect to AKS cluster
  echo Connencting to Azure Kubernetes Service.
  az aks get-credentials --resource-group $azureResourceGroupName --name $aksClusterName
}

createFileShare() {
  # Create a storage account
  echo Check if the storage account ${storageAccountName} exists.
  ret=$(az storage account check-name --name ${storageAccountName})
  nameAvailable=$(echo "$ret" | grep "nameAvailable" | grep "false")
  if [ -n "$nameAvailable" ]; then
    echo $ret
    fail "Storage account ${storageAccountName} is unavailable."
  fi

  echo Creating Azure Storage Account ${storageAccountName}.
  az storage account create \
  -n $storageAccountName \
  -g $azureResourceGroupName \
  -l $azureLocation \
  --sku Premium_LRS \
  --kind FileStorage \
  --https-only false \
  --default-action Deny

  echo Creating Azure NFS file share.
  az storage share-rm create \
  --resource-group $azureResourceGroupName \
  --storage-account $storageAccountName \
  --name ${azureStorageShareName} \
  --enabled-protocol NFS \
  --root-squash NoRootSquash \
  --quota 100

  configureStorageAccountNetwork

  # Echo storage account name and key
  echo Storage account name: $storageAccountName
  echo NFS file share name: ${azureStorageShareName}

  # Mount the file share as a volume
  echo Mounting file share as a volume.
  ${KUBERNETES_CLI:-kubectl} apply -f ${scOutput}
  ${KUBERNETES_CLI:-kubectl} get storageclass ${azureFileCsiNfsClassName} -o yaml
  ${KUBERNETES_CLI:-kubectl} apply -f ${pvcOutput}
  ${KUBERNETES_CLI:-kubectl} get pvc ${persistentVolumeClaimName} -o yaml

  checkPvcState ${persistentVolumeClaimName} "Bound"
}

configureStorageAccountNetwork() {
  local aksObjectId=$(az aks show --name ${aksClusterName} --resource-group ${azureResourceGroupName} --query "identity.principalId" -o tsv)
  local storageAccountId=$(az storage account show --name ${storageAccountName} --resource-group ${azureResourceGroupName} --query "id" -o tsv)

  az role assignment create \
      --assignee-object-id "${aksObjectId}" \
      --assignee-principal-type "ServicePrincipal" \
      --role "Contributor" \
      --scope "${storageAccountId}"

  if [ $? != 0 ]; then
    fail "Failed to grant the AKS cluster with Contibutor role to access the storage account."
  fi

  # get the resource group name of the AKS managed resources
  local aksMCRGName=$(az aks show --name $aksClusterName --resource-group $azureResourceGroupName -o tsv --query "nodeResourceGroup")
  echo ${aksMCRGName}

  # get network name of AKS cluster
  local aksNetworkName=$(az graph query -q "Resources \
    | where type =~ 'Microsoft.Network/virtualNetworks' \
    | where resourceGroup  =~ '${aksMCRGName}' \
    | project name = name" --query "data[0].name"  -o tsv)

  echo ${aksNetworkName}

  # get subnet name of AKS agent pool
  local aksSubnetName=$(az network vnet subnet list --resource-group ${aksMCRGName} --vnet-name ${aksNetworkName} -o tsv --query "[*].name")
  echo ${aksSubnetName}

  local aksSubnetId=$(az network vnet subnet list --resource-group ${aksMCRGName} --vnet-name ${aksNetworkName} -o tsv --query "[*].id")
  echo ${aksSubnetId}

  az network vnet subnet update \
    --resource-group $aksMCRGName \
    --name ${aksSubnetName} \
    --vnet-name ${aksNetworkName} \
    --service-endpoints Microsoft.Storage

  az storage account network-rule add \
    --resource-group $azureResourceGroupName \
    --account-name $storageAccountName \
    --subnet ${aksSubnetId}

  if [ $? != 0 ]; then
    fail "Fail to configure network for storage account ${storageAccountName}. Network name: ${aksNetworkName}. Subnet name: ${aksSubnetName}."
  fi
}

installWebLogicOperator() {
  echo $(helm version)
  helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts --force-update
  helm install weblogic-operator weblogic-operator/weblogic-operator
}

createWebLogicDomain() {
  # Enable the operator to monitor the namespace
  ${KUBERNETES_CLI:-kubectl} label namespace default weblogic-operator=enabled

  # Create WebLogic Server Domain Credentials.
  echo Creating WebLogic Server Domain credentials, with user ${weblogicUserName}, domainUID ${domainUID}
  bash ${dirCreateDomainCredentials}/create-weblogic-credentials.sh -u ${weblogicUserName} \
  -p ${weblogicAccountPassword} -d ${domainUID}

  # Create Container Registry Credentials.
  bash $dirKubernetesSecrets/create-docker-credentials-secret.sh \
  -e ${docker-email} \
  -p ${dockerPassword} \
  -u ${dockerUserName} \
  -s ${imagePullSecretName} \
  -d container-registry.oracle.com

  # Create WebLogic Server Domain
  echo Creating WebLogic Server domain ${domainUID}

  buildandrunimage  

  ${KUBERNETES_CLI:-kubectl} apply -f ${adminLbOutput}
  ${KUBERNETES_CLI:-kubectl} apply -f ${clusterLbOutput}
}

buildandrunimage(){
export ORACLE_USERNAME=oracle.ufgc5@aleeas.com
export ORACLE_PASSWORD=

export TIMESTAMP=$(date +%s)
export NAME_PREFIX=wls
export ACR_NAME=domainonpvaks${TIMESTAMP}
export BASE_DIR="/tmp/tmp${TIMESTAMP}"
export BRANCH_NAME="v4.1.0"

export SECRET_NAME_DOCKER="${NAME_PREFIX}regcred"
export WEBLOGIC_USERNAME="weblogic"
export WEBLOGIC_PASSWORD="Secret123456"

az extension add --name resource-graph

mkdir ${BASE_DIR}

## Build and push Image
az acr create --resource-group $azureResourceGroupName \
  --name ${ACR_NAME} \
  --sku Standard

az acr update -n ${ACR_NAME} --admin-enabled true

export LOGIN_SERVER=$(az acr show -n $ACR_NAME --query 'loginServer' -o tsv)
echo $LOGIN_SERVER
export USER_NAME=$(az acr credential show -n $ACR_NAME --query 'username' -o tsv)
echo $USER_NAME
export PASSWORD=$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)
echo $PASSWORD
sudo docker login $LOGIN_SERVER -u $USER_NAME -p $PASSWORD

# public access
az acr update --name $ACR_NAME --anonymous-pull-enabled

## need az acr login in order to push
az acr login --name $ACR_NAME

cd ${BASE_DIR}
git clone --branch ${BRANCH_NAME} https://github.com/oracle/weblogic-kubernetes-operator.git
mkdir -p ${BASE_DIR}/sample
cp -r ${BASE_DIR}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-on-pv/* ${BASE_DIR}/sample

mkdir -p ${BASE_DIR}/sample/wdt-artifacts

cp -r ${BASE_DIR}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/wdt-artifacts/* ${BASE_DIR}/sample/wdt-artifacts

cd ${BASE_DIR}/sample/wdt-artifacts

curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip \
  -o ${BASE_DIR}/sample/wdt-artifacts/weblogic-deploy.zip

curl -m 120 -fL https://github.com/oracle/weblogic-image-tool/releases/latest/download/imagetool.zip \
  -o ${BASE_DIR}/sample/wdt-artifacts/imagetool.zip

cd ${BASE_DIR}/sample/wdt-artifacts

unzip imagetool.zip

./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest

./imagetool/bin/imagetool.sh cache addInstaller \
  --type wdt \
  --version latest \
  --path ${BASE_DIR}/sample/wdt-artifacts/weblogic-deploy.zip

unzip ${BASE_DIR}/sample/wdt-artifacts/weblogic-deploy.zip

rm -f ${BASE_DIR}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip

cd ${BASE_DIR}/sample/wdt-artifacts/archives/archive-v1

${BASE_DIR}/sample/wdt-artifacts/weblogic-deploy/bin/archiveHelper.sh add application -archive_file=${BASE_DIR}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip -source=wlsdeploy/applications/myapp-v1

cd ${BASE_DIR}/sample/wdt-artifacts/wdt-model-files/WLS-v1

# --tag wlsgzhcontainer.azurecr.io/wdt-domain-image:WLS-v1 \
${BASE_DIR}/sample/wdt-artifacts/imagetool/bin/imagetool.sh createAuxImage \
  --tag ${ACR_NAME}.azurecr.io/wdt-domain-image:WLS-v1 \
  --wdtModel ./model.10.yaml \
  --wdtVariables ./model.10.properties \
  --wdtArchive ./archive.zip

docker push ${ACR_NAME}.azurecr.io/wdt-domain-image:WLS-v1



## 构建
cd ${BASE_DIR}
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
./create-weblogic-credentials.sh -u ${WEBLOGIC_USERNAME} -p ${WEBLOGIC_PASSWORD} -d domain1

cd ${BASE_DIR}
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-kubernetes-secrets
./create-docker-credentials-secret.sh -s ${SECRET_NAME_DOCKER} -e ${ORACLE_USERNAME} -p ${ORACLE_PASSWORD} -u ${ORACLE_USERNAME}


cat >domain-resource.yaml <<EOF
# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
# This is an example of how to define a Domain resource.
#
apiVersion: "weblogic.oracle/v9"
kind: Domain
metadata:
  name: domain1
  namespace: default
  labels:
    weblogic.domainUID: domain1

spec:
  # Set to 'PersistentVolume' to indicate 'Domain on PV'.
  domainHomeSourceType: PersistentVolume

  # The WebLogic Domain Home, this must be a location within
  # the persistent volume for 'Domain on PV' domains.
  domainHome: /shared/domains/domain1

  # The WebLogic Server image that the Operator uses to start the domain
  # **NOTE**:
  # This sample uses General Availability (GA) images. GA images are suitable for demonstration and
  # development purposes only where the environments are not available from the public Internet;
  # they are not acceptable for production use. In production, you should always use CPU (patched)
  # images from OCR or create your images using the WebLogic Image Tool.
  # Please refer to the "OCR" and "WebLogic Images" pages in the WebLogic Kubernetes Operator
  # documentation for details.
  image: "container-registry.oracle.com/middleware/weblogic:12.2.1.4"

  # Defaults to "Always" if image tag (version) is ':latest'
  imagePullPolicy: IfNotPresent

  # Identify which Secret contains the credentials for pulling an image
  imagePullSecrets:
    - name: wlsregcred
  #- name: regsecret2

  # Identify which Secret contains the WebLogic Admin credentials,
  # the secret must contain 'username' and 'password' fields.
  webLogicCredentialsSecret:
    name: domain1-weblogic-credentials

  # Whether to include the WebLogic Server stdout in the pod's stdout, default is true
  includeServerOutInPodLog: true

  # Whether to enable overriding your log file location, defaults to 'True'. See also 'logHome'.
  #logHomeEnabled: false

  # The location for domain log, server logs, server out, introspector out, and Node Manager log files
  # see also 'logHomeEnabled', 'volumes', and 'volumeMounts'.
  #logHome: /shared/logs/sample-domain1
  #
  # Set which WebLogic Servers the Operator will start
  # - "Never" will not start any server in the domain
  # - "AdminOnly" will start up only the administration server (no managed servers will be started)
  # - "IfNeeded" will start all non-clustered servers, including the administration server, and clustered servers up to their replica count.
  serverStartPolicy: IfNeeded

  configuration:
    # Settings for initializing the domain home on 'PersistentVolume'
    initializeDomainOnPV:

      # Settings for domain home on PV.
      domain:
         # Valid model domain types are 'WLS', and 'JRF', default is 'JRF'
         domainType: WLS

         # Domain creation image(s) containing WDT model, archives, and install.
         #   "image"                - Image location
         #   "imagePullPolicy"      - Pull policy, default "IfNotPresent"
         #   "sourceModelHome"      - Model file directory in image, default "/auxiliary/models".
         #   "sourceWDTInstallHome" - WDT install directory in image, default "/auxiliary/weblogic-deploy".
         domainCreationImages:
         - image: "${ACR_NAME}.azurecr.io/wdt-domain-image:WLS-v1"
           imagePullPolicy: IfNotPresent
           #sourceWDTInstallHome: /auxiliary/weblogic-deploy
           #sourceModelHome: /auxiliary/models

         # Optional configmap for additional models and variable files
         #domainCreationConfigMap: sample-domain1-wdt-config-map

    # Secrets that are referenced by model yaml macros
    # (the model yaml in the optional configMap or in the image)
    #secrets:
    #- sample-domain1-datasource-secret

  # Settings for all server pods in the domain including the introspector job pod
  serverPod:
    # Optional new or overridden environment variables for the domain's pods
    # - This sample uses CUSTOM_DOMAIN_NAME in its image model file
    #   to set the WebLogic domain name
    env:
    - name: CUSTOM_DOMAIN_NAME
      value: "domain1"
    - name: JAVA_OPTIONS
      value: "-Dweblogic.StdoutDebugEnabled=false"
    - name: USER_MEM_ARGS
      value: "-Djava.security.egd=file:/dev/./urandom -Xms256m -Xmx512m "
    resources:
      requests:
        cpu: "250m"
        memory: "768Mi"

    # Volumes and mounts for hosting the domain home on PV and domain's logs. See also 'logHome'.
    volumes:
    - name: weblogic-domain-storage-volume
      persistentVolumeClaim:
        claimName: wls-azurefile-${TIMESTAMP}
    volumeMounts:
    - mountPath: /shared
      name: weblogic-domain-storage-volume

  # The desired behavior for starting the domain's administration server.
  # adminServer:
    # Setup a Kubernetes node port for the administration server default channel
    #adminService:
    #  channels:
    #  - channelName: default
    #    nodePort: 30701

  # The number of managed servers to start for unlisted clusters
  replicas: 3

  # The name of each Cluster resource
  clusters:
  - name: sample-domain1-cluster-1

  # Change the restartVersion to force the introspector job to rerun
  # to force a roll of your domain's WebLogic Server pods.
  restartVersion: '1'

  # Changes to this field cause the operator to repeat its introspection of the
  #  WebLogic domain configuration.
  introspectVersion: '1'

---

apiVersion: "weblogic.oracle/v1"
kind: Cluster
metadata:
  name: sample-domain1-cluster-1
  # Update this with the namespace your domain will run in:
  namespace: default
  labels:
    # Update this with the "domainUID" of your domain:
    weblogic.domainUID: domain1
spec:
  # This must match a cluster name that is  specified in the WebLogic configuration
  clusterName: cluster-1
  # The number of managed servers to start for this cluster
  replicas: 3


EOF

echo "sleep 30s"
sleep 30s
kubectl apply -f domain-resource.yaml

}

waitForJobComplete() {
  local attempts=0
  local svcState="running"
  while [ ! "$svcState" == "completed" ] && [ ! $attempts -eq 30 ]; do
    svcState="completed"
    attempts=$((attempts + 1))
    echo Waiting for job completed...${attempts}
    sleep 120

    # If the job is completed, there should have the following services created,
    #    ${domainUID}-${adminServerName}, e.g. domain1-admin-server
    #    ${domainUID}-${adminServerName}-ext, e.g. domain1-admin-server-ext
    #    ${domainUID}-${adminServerName}-external-lb, e.g domain1-admin-server-external-lb
    local adminServiceCount=$(${KUBERNETES_CLI:-kubectl} get svc | grep -c "${domainUID}-${adminServerName}")
    if [ ${adminServiceCount} -lt 3 ]; then svcState="running"; fi

    # If the job is completed, there should have the following services created, .assuming initialManagedServerReplicas=2
    #    ${domainUID}-${managedServerNameBase}1, e.g. domain1-managed-server1
    #    ${domainUID}-${managedServerNameBase}2, e.g. domain1-managed-server2
    local managedServiceCount=$(${KUBERNETES_CLI:-kubectl} get svc | grep -c "${domainUID}-${managedServerNameBase}")
    if [ ${managedServiceCount} -lt ${initialManagedServerReplicas} ]; then svcState="running"; fi

    # If the job is completed, there should have no service in pending status.
    local pendingCount=$(${KUBERNETES_CLI:-kubectl} get svc | grep -c "pending")
    if [ ${pendingCount} -ne 0 ]; then svcState="running"; fi

    # If the job is completed, there should have the following pods running
    #    ${domainUID}-${adminServerName}, e.g. domain1-admin-server
    #    ${domainUID}-${managedServerNameBase}1, e.g. domain1-managed-server1
    #    to
    #    ${domainUID}-${managedServerNameBase}n, e.g. domain1-managed-servern, n = initialManagedServerReplicas
    local runningPodCount=$(${KUBERNETES_CLI:-kubectl} get pods | grep "${domainUID}" | grep -c "Running")
    if [[ $runningPodCount -le ${initialManagedServerReplicas} ]]; then svcState="running"; fi

    echo ==============================Current Status==========================================
    ${KUBERNETES_CLI:-kubectl} get svc
    echo ""
    ${KUBERNETES_CLI:-kubectl} get pods
    echo ======================================================================================
  done

  # If all the services are completed, print service details
  # Otherwise, ask the user to refer to document for troubleshooting
  if [ "$svcState" == "completed" ]; then
    ${KUBERNETES_CLI:-kubectl} get pods
    ${KUBERNETES_CLI:-kubectl} get svc
  else
    echo It takes a little long to create domain, please refer to http://oracle.github.io/weblogic-kubernetes-operator/samples/azure-kubernetes-service/#troubleshooting
  fi
}

printSummary() {
  if [ "${executeIt}" = true ]; then
    regionJsonExcerpt=$(az group list --query "[?name=='${azureResourceGroupName}']" | grep location)
    tokens=($(
      IFS='"'
      for word in $regionJsonExcerpt; do echo "$word"; done
    ))
    region=${tokens[2]}
    echo ""
    echo ""
    echo "The following Azure Resouces have been created: "
    echo "  Resource groups: ${azureResourceGroupName}, MC_${azureResourceGroupName}_${aksClusterName}_${region}"
    echo "  Kubernetes service cluster name: ${aksClusterName}"
    echo "  Storage account: ${storageAccountName}"
    echo ""
    echo "Domain ${domainName} was created and was started by the WebLogic Kubernetes Operator"
    echo ""
    echo "Connect your ${KUBERNETES_CLI:-kubectl} to this cluster with this command:"
    echo "  az aks get-credentials --resource-group ${azureResourceGroupName} --name ${aksClusterName}"
    echo ""

    if [ "${exposeAdminNodePort}" = true ]; then
      adminLbIP=$(${KUBERNETES_CLI:-kubectl} get svc ${domainUID}-${adminServerName}-external-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
      echo "Administration console access is available at http://${adminLbIP}:${adminPort}/console"
    fi

    echo ""
    clusterLbIP=$(${KUBERNETES_CLI:-kubectl} get svc ${domainUID}-${clusterName}-external-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Cluster external ip is ${clusterLbIP}, after you deploy application to WebLogic Server cluster, you can access it at http://${clusterLbIP}:${managedServerPort}/<your-app-path>"
  fi
  echo ""
  echo "The following files were generated:"
  echo "  ${scOutput}"
  echo "  ${pvcOutput}"
  echo "  ${adminLbOutput}"
  echo "  ${clusterLbOutput}"
  echo "  ${domain1Output}"
  echo ""

  echo "Completed"
}

cd ${scriptDir}

cd ..
export dirSampleScripts=$(pwd)
export dirCreateDomain="${dirSampleScripts}/create-weblogic-domain/domain-home-on-pv"
export dirCreateDomainCredentials="${dirSampleScripts}/create-weblogic-domain-credentials"
export dirKubernetesSecrets="${dirSampleScripts}/create-kubernetes-secrets"
export selectorAdminServerName="serverName"
export selectorClusterServerName="clusterName"

cd ${scriptDir}

#
# Do these steps to create Azure resources and a WebLogic Server domain.
#

# Setup the environment for running this script and perform initial validation checks
initialize


# All done if the execute option is true
if [ "${executeIt}" = true ]; then

  # Create resource group
  createResourceGroup

  # Create Azure Kubernetes Service and connect to AKS cluster
  createAndConnectToAKSCluster

  # Create File Share
  createFileShare

  # Install WebLogic Operator to AKS Cluster
  installWebLogicOperator

  # Create WebLogic Server Domain
  createWebLogicDomain

  # Wait for all the jobs completed
  waitForJobComplete
fi

# Print summary
printSummary
