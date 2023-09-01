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

# Define display end-------------
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

# Function: Print colored message
print_message() {
    local contenxt="$1"
    local color="$2"

    echo -e "${color} ${contenxt}${RESET}"
}

print_blue() {
    local contenxt="$1"
    echo -e "${BLUE} ${contenxt}${RESET}"
}

print_red() {
    local contenxt="$1"
    echo -e "${RED} ${contenxt}${RESET}"
}

#
# Function to validate the host environment meets the prerequisites.
# $1 - text of message
envValidate() {
  # Check if the user is logged in to Azure CLI
  if az account show >/dev/null 2>&1; then
    print_blue "Logged in to Azure CLI"
  else
    print_red "[ERROR]Not logged in to Azure CLI. Please log in."
    exit 1
  fi

  # Check if Java JDK is installed
  java_version=$(java -version 2>&1)

  # Check if the output contains "java version"
  if echo "$java_version" | grep -q "java version"; then
    print_blue "Java JDK is installed. Version:"
    java -version
  else
    print_red "[ERROR]Java JDK is not installed. Please install Java JDK."
    exit 1
  fi

  # Check if Docker is installed
  if command -v docker &> /dev/null; then
      echo "Docker is installed."
  else
      print_red "[ERROR]Docker is not installed. Please install Docker."
      exit 1
  fi

  # Check if Helm is installed
  if command -v helm &> /dev/null; then
      print_blue "Helm is installed."
  else
      print_red "[ERROR]Helm is not installed. Please install Helm."
      exit 1
  fi

  # Check if kubectl is installed
  if command -v kubectl &> /dev/null; then
      print_blue "kubectl is installed."
  else
      print_red "[ERROR]kubectl is not installed. Please install kubectl."
      exit 1
  fi

}

parametersValidate() {
  # Get the values of environment variables
  email="$dockerEmail"
  password="$dockerPassword"

  # Check for default values and prompt for setting
  if [ "$email" = "docker-email" ]; then
    echo -n "Please enter a value for 'dockerEmail'(Oracle Single Sign-On (SSO) account email): "
    read input_email
    if [ -z "$input_email" ]; then
      echo "No value provided for 'dockerEmail'. Please set the value and rerun the script."
      exit 1
    fi
    email="$input_email"
  fi

  if [ "$password" = "docker-password" ]; then
    echo -n "Please enter a value for 'dockerPassword'(Oracle Single Sign-On (SSO) account password): "
    read -s input_password
    echo
    if [ -z "$input_password" ]; then
      echo "No value provided for 'dockerPassword'. Please set the value and rerun the script."
      exit 1
    fi
    password="$input_password"
  fi

  # Export the updated values of environment variables
  export dockerEmail="$email"
  export dockerPassword="$password"

}


#
# Function to setup the environment to run the create Azure resource and domain job
#
initialize() {

  source ./create-domain-on-aks-inputs.sh
  source ~/.bashrc
  
  # Generate Azure resource name

  export image_build_branch_name="v4.1.0"
  export image_build_base_dir="/tmp/tmp${azureResourceUID}"

  export acr_account_name=${namePrefix}acr${azureResourceUID}
  export docker_secret_name="${namePrefix}regcred"

  export azureResourceGroupName="${namePrefix}resourcegroup${azureResourceUID}"
  export aksClusterName="${namePrefix}akscluster${azureResourceUID}"
  export storageAccountName="${namePrefix}storage${azureResourceUID}"

  export azureFileShareSecretName="${namePrefix}${azureFileShareSecretNameSuffix}"
  export azureKubernetesNodepoolName="${azureKubernetesNodepoolNamePrefix}${namePrefix}"
  export azureStorageShareName="${namePrefix}-${azureStorageShareNameSuffix}-${azureResourceUID}"
  
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

  # Create WebLogic Server Domain
  echo Creating WebLogic Server domain ${domainUID}

  buildDomainOnPvImage  

  # create credentials
  cd ${image_build_base_dir}
  cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
  ./create-weblogic-credentials.sh -u ${weblogicUserName} -p ${weblogicAccountPassword} -d domain1

  cd ${image_build_base_dir}
  cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-kubernetes-secrets

  ./create-docker-credentials-secret.sh -s ${docker_secret_name} -e ${dockerEmail} -p ${dockerPassword} -u ${dockerEmail}

  # generate yaml
  generateYamls

  # Mount the file share as a volume
  echo Mounting file share as a volume.
  ${KUBERNETES_CLI:-kubectl} apply -f ./azure-csi-nfs.yaml
  ${KUBERNETES_CLI:-kubectl} apply -f ./pvc.yaml

  ${KUBERNETES_CLI:-kubectl} apply -f domain-resource.yaml
  ${KUBERNETES_CLI:-kubectl} apply -f admin-lb.yaml
  ${KUBERNETES_CLI:-kubectl} apply -f cluster-lb.yaml

}

generateYamls() {
cat >azure-csi-nfs.yaml <<EOF
# Copyright (c) 2018, 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
parameters:
  protocol: nfs
  resourceGroup: ${azureResourceGroupName}
  storageAccount: ${storageAccountName}
  shareName: ${azureFileShareSecretName}
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true

EOF

cat >pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wls-azurefile-${azureResourceUID}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile-csi-nfs
  resources:
    requests:
      storage: 5Gi

EOF


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
    - name: ${namePrefix}regcred

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
        - image: "${acr_account_name}.azurecr.io/wdt-domain-image:WLS-v1"
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
        claimName: wls-azurefile-${azureResourceUID}
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

cat >admin-lb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: domain1-admin-server-external-lb
  namespace: default
spec:
  ports:
  - name: default
    port: 7001
    protocol: TCP
    targetPort: 7001
  selector:
    weblogic.domainUID: domain1
    weblogic.serverName: admin-server
  sessionAffinity: None
  type: LoadBalancer

EOF

cat >cluster-lb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: domain1-cluster-1-lb
  namespace: default
spec:
  ports:
  - name: default
    port: 8001
    protocol: TCP
    targetPort: 8001
  selector:
    weblogic.domainUID: domain1
    weblogic.clusterName: cluster-1
  sessionAffinity: None
  type: LoadBalancer

EOF

}

buildDomainOnPvImage(){

az extension add --name resource-graph
mkdir ${image_build_base_dir}

## Build Azure ACR
az acr create --resource-group $azureResourceGroupName \
  --name ${acr_account_name} \
  --sku Standard

az acr update -n ${acr_account_name} --admin-enabled true

export LOGIN_SERVER=$(az acr show -n $acr_account_name --query 'loginServer' -o tsv)
export USER_NAME=$(az acr credential show -n $acr_account_name --query 'username' -o tsv)
export PASSWORD=$(az acr credential show -n $acr_account_name --query 'passwords[0].value' -o tsv)

sudo docker login $LOGIN_SERVER -u $USER_NAME -p $PASSWORD

# make public access
az acr update --name $acr_account_name --anonymous-pull-enabled

## need az acr login in order to push
az acr login --name $acr_account_name

## Build image
cd ${image_build_base_dir}
git clone --branch ${image_build_branch_name} https://github.com/oracle/weblogic-kubernetes-operator.git
mkdir -p ${image_build_base_dir}/sample
cp -r ${image_build_base_dir}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-on-pv/* ${image_build_base_dir}/sample

mkdir -p ${image_build_base_dir}/sample/wdt-artifacts
cp -r ${image_build_base_dir}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/wdt-artifacts/* ${image_build_base_dir}/sample/wdt-artifacts

cd ${image_build_base_dir}/sample/wdt-artifacts

curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip \
  -o ${image_build_base_dir}/sample/wdt-artifacts/weblogic-deploy.zip

curl -m 120 -fL https://github.com/oracle/weblogic-image-tool/releases/latest/download/imagetool.zip \
  -o ${image_build_base_dir}/sample/wdt-artifacts/imagetool.zip

cd ${image_build_base_dir}/sample/wdt-artifacts
unzip imagetool.zip

./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest
./imagetool/bin/imagetool.sh cache addInstaller \
  --type wdt \
  --version latest \
  --path ${image_build_base_dir}/sample/wdt-artifacts/weblogic-deploy.zip

unzip ${image_build_base_dir}/sample/wdt-artifacts/weblogic-deploy.zip
rm -f ${image_build_base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip
cd ${image_build_base_dir}/sample/wdt-artifacts/archives/archive-v1

${image_build_base_dir}/sample/wdt-artifacts/weblogic-deploy/bin/archiveHelper.sh \ 
  add application \
  -archive_file=${image_build_base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip -source=wlsdeploy/applications/myapp-v1

cd ${image_build_base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1

# --tag wlsgzhcontainer.azurecr.io/wdt-domain-image:WLS-v1 \
${image_build_base_dir}/sample/wdt-artifacts/imagetool/bin/imagetool.sh createAuxImage \
  --tag ${acr_account_name}.azurecr.io/wdt-domain-image:WLS-v1 \
  --wdtModel ./model.10.yaml \
  --wdtVariables ./model.10.properties \
  --wdtArchive ./archive.zip

## Push image
docker push ${acr_account_name}.azurecr.io/wdt-domain-image:WLS-v1

}


waitForJobComplete() {

waiting_time=0
max_wait_time=600
interval=30

echo "Wait Job to be completed.Waiting for $interval seconds..."
sleep $interval

while [ $waiting_time -lt $max_wait_time ]; do
    status=$(kubectl get pod/domain1-admin-server -o=jsonpath='{.status.phase}')

    if [ "$status" == "Running" ]; then
        echo "Pod is running. Exiting..."
        break
    fi
    
    echo "Pod is not running yet. Waiting for $interval seconds..."
    sleep $interval
    waiting_time=$((waiting_time + interval))
done

}

printSummary() {

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

  adminLbIP=$(${KUBERNETES_CLI:-kubectl} get svc domain1-admin-server-external-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "Administration console access is available at http://${adminLbIP}:7001/console"
  
  echo ""
  clusterLbIP=$(${KUBERNETES_CLI:-kubectl} get svc domain1-cluster-1-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "Cluster external ip is ${clusterLbIP}, you can access http://${clusterLbIP}:8001/myapp_war/index.jsp"
  
  echo "Completed"
}

cd ${scriptDir}

#
# Do these steps to create Azure resources and a WebLogic Server domain.
#

# Setup the environment for running this script and perform initial validation checks
initialize

# Validate the host environment meets the prerequisites.
envValidate

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

# Wait for all the domain creation completed
waitForJobComplete

# Print summary
printSummary
