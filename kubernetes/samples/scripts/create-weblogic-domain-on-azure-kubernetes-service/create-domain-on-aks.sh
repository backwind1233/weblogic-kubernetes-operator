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

#
# Function to setup the environment to run the create Azure resource and domain job
#
initialize() {

  source ./create-domain-on-aks-inputs.sh
  source ~/.bashrc
  
  # Generate Azure resource name

  export BRANCH_NAME="v4.1.0"
  export base_dir="/tmp/tmp${azureResourceUID}"
  export acr_account_name=${namePrefix}acr${azureResourceUID}
  export docker_secret_name="${namePrefix}regcred"

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

  # Create WebLogic Server Domain
  echo Creating WebLogic Server domain ${domainUID}

  buildandrunimage  

}

buildandrunimage(){

az extension add --name resource-graph

mkdir ${base_dir}

## Build and push Image
az acr create --resource-group $azureResourceGroupName \
  --name ${acr_account_name} \
  --sku Standard

az acr update -n ${acr_account_name} --admin-enabled true

export LOGIN_SERVER=$(az acr show -n $acr_account_name --query 'loginServer' -o tsv)
echo $LOGIN_SERVER
export USER_NAME=$(az acr credential show -n $acr_account_name --query 'username' -o tsv)
echo $USER_NAME
export PASSWORD=$(az acr credential show -n $acr_account_name --query 'passwords[0].value' -o tsv)
echo $PASSWORD
sudo docker login $LOGIN_SERVER -u $USER_NAME -p $PASSWORD

# public access
az acr update --name $acr_account_name --anonymous-pull-enabled

## need az acr login in order to push
az acr login --name $acr_account_name

cd ${base_dir}
git clone --branch ${BRANCH_NAME} https://github.com/oracle/weblogic-kubernetes-operator.git
mkdir -p ${base_dir}/sample
cp -r ${base_dir}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-on-pv/* ${base_dir}/sample

mkdir -p ${base_dir}/sample/wdt-artifacts

cp -r ${base_dir}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/wdt-artifacts/* ${base_dir}/sample/wdt-artifacts

cd ${base_dir}/sample/wdt-artifacts

curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip \
  -o ${base_dir}/sample/wdt-artifacts/weblogic-deploy.zip

curl -m 120 -fL https://github.com/oracle/weblogic-image-tool/releases/latest/download/imagetool.zip \
  -o ${base_dir}/sample/wdt-artifacts/imagetool.zip

cd ${base_dir}/sample/wdt-artifacts

unzip imagetool.zip

./imagetool/bin/imagetool.sh cache deleteEntry --key wdt_latest

./imagetool/bin/imagetool.sh cache addInstaller \
  --type wdt \
  --version latest \
  --path ${base_dir}/sample/wdt-artifacts/weblogic-deploy.zip

unzip ${base_dir}/sample/wdt-artifacts/weblogic-deploy.zip

rm -f ${base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip

cd ${base_dir}/sample/wdt-artifacts/archives/archive-v1

${base_dir}/sample/wdt-artifacts/weblogic-deploy/bin/archiveHelper.sh add application -archive_file=${base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1/archive.zip -source=wlsdeploy/applications/myapp-v1

cd ${base_dir}/sample/wdt-artifacts/wdt-model-files/WLS-v1

# --tag wlsgzhcontainer.azurecr.io/wdt-domain-image:WLS-v1 \
${base_dir}/sample/wdt-artifacts/imagetool/bin/imagetool.sh createAuxImage \
  --tag ${acr_account_name}.azurecr.io/wdt-domain-image:WLS-v1 \
  --wdtModel ./model.10.yaml \
  --wdtVariables ./model.10.properties \
  --wdtArchive ./archive.zip

docker push ${acr_account_name}.azurecr.io/wdt-domain-image:WLS-v1

# generate yaml
source ./create-domain-on-aks-generate-yaml.sh

# Mount the file share as a volume
echo Mounting file share as a volume.
kubectl apply -f ./azure-csi-nfs.yaml
kubectl apply -f ./pvc.yaml


## build images
cd ${base_dir}
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
./create-weblogic-credentials.sh -u ${weblogicUserName} -p ${weblogicAccountPassword} -d domain1

cd ${base_dir}
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-kubernetes-secrets

./create-docker-credentials-secret.sh -s ${docker_secret_name} -e ${dockerEmail} -p ${dockerPassword} -u ${dockerUserName}


echo "sleep 30s"
sleep 30s
kubectl apply -f domain-resource.yaml
kubectl apply -f admin-lb.yaml
kubectl apply -f cluster-lb.yaml

}


waitForJobComplete() {
sleep 30s
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

    adminLbIP=$(${KUBERNETES_CLI:-kubectl} get svc domain1-admin-server-external-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Administration console access is available at http://${adminLbIP}:7001/console"
    

    echo ""
    clusterLbIP=$(${KUBERNETES_CLI:-kubectl} get svc domain1-cluster-1-lb --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Cluster external ip is ${clusterLbIP}, you can access http://${clusterLbIP}:8001/myapp_war/index.jsp"
    
  fi
  
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

executeIt=true

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
  # todo
  waitForJobComplete
fi

# Print summary
printSummary
