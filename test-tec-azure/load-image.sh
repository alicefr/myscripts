#!/bin/bash

set -e

resource_group=afrosi_group
storage_account=afrosi
storage_container=afrosi-con
compute_gallery=afrosi_gallery
image_version=0.1.0
image="$1"
image_definition=$(basename "$image" .vhd)

az login
AZURE_SUBSCRIPTION_ID=$(az account show --query id --output tsv)

if ! az group show --name $resource_group &>/dev/null; then
  echo "Creating resource group $resource_group..."
  az group create --name $resource_group --location eastus
fi

actual_storage_rg=$resource_group
if ! az storage account show --name $storage_account --resource-group $resource_group &>/dev/null; then
  existing_rg=$(az storage account list --query "[?name=='$storage_account'].resourceGroup" -o tsv 2>/dev/null)
  if [ -n "$existing_rg" ]; then
    echo "Storage account '$storage_account' already exists in resource group '$existing_rg', skipping creation..."
    actual_storage_rg=$existing_rg
  else
    echo "Creating storage account $storage_account..."
    az storage account create --name $storage_account --resource-group $resource_group --location eastus --sku Standard_LRS
  fi
fi

cs=$(az storage account show-connection-string -g $actual_storage_rg -n $storage_account | jq -r .connectionString)
if ! az storage container exists --name $storage_container --connection-string "$cs" | jq -r .exists | grep -q true; then
  echo "Creating storage container $storage_container..."
  az storage container create --name $storage_container --connection-string "$cs"
fi

if ! az sig show --gallery-name $compute_gallery --resource-group $resource_group &>/dev/null; then
  echo "Creating compute gallery $compute_gallery..."
  az sig create --gallery-name $compute_gallery --resource-group $resource_group --location eastus
fi

echo "Uploading blob $image to container $storage_container..."
az storage blob upload --connection-string $cs -c $storage_container -f $image -n $image --overwrite

# Create a managed image from the VHD blob
managed_image_name="${image_definition}-managed"
blob_uri="https://$storage_account.blob.core.windows.net/$storage_container/$image"
if ! az image show -g $resource_group -n $managed_image_name &>/dev/null; then
  echo "Creating managed image $managed_image_name from VHD..."
  az image create -g $resource_group -n $managed_image_name \
    --source $blob_uri \
    --os-type Linux \
    --hyper-v-generation V2
fi

# Create image definition
if ! az sig image-definition show -g $resource_group -r $compute_gallery -i $image_definition &>/dev/null; then
  echo "Creating image definition $image_definition..."
  az sig image-definition create -g $resource_group -r $compute_gallery -i $image_definition \
    --publisher example --offer example --sku standard \
    --features SecurityType=ConfidentialVmSupported --os-type Linux --hyper-v-generation V2
fi

# Create image version from the managed image
echo "Creating image version $image_version..."
az sig image-version create -g $resource_group -r $compute_gallery -i $image_definition -e $image_version \
  --managed-image /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group/providers/Microsoft.Compute/images/$managed_image_name \
  --replica-count 1 \
  --target-regions eastus

# Set $TEST_IMAGE for the test
export TEST_IMAGE=/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group/providers/Microsoft.Compute/galleries/$compute_gallery/images/$image_definition/versions/$image_version
