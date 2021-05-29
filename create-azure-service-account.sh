#!/bin/bash
#
# Uses the azure cli to create a service account
# Populates terrform.tfvars
#

path_to_az=$(which az)
if [ ! -x "$path_to_az" ]; then
  echo "ERROR could not find azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt"
  exit 1
fi

# check for login
az account list > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR, run 'az login' first"
  exit 2
fi

# if logged in, we can get subscription and tenant id
me=$(az account show --query user.name -o tsv)
echo "logged in: $me"
subscriptionId=$(az account show --query id -o tsv)
tenantId=$(az account show --query tenantId -o tsv)
echo "subscription/tenant = $subscriptionId/$tenantId"

# if sp app exists, we can get app id, uri, and name
appId=$(az ad app list --query [].appId -o tsv)
if [ -z "$appId" ]; then
    echo "sp app does not exist, need to create"
    thepassword=$(az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscriptionId" --out tsv --query password)
else
    echo "sp app already exists, recreating with new password"
    thepassword=$(az ad sp credential reset --name $appId --out tsv --query password)
fi

appId=$(az ad app list --query [].appId -o tsv)
displayName=$(az ad app list --query [].displayName -o tsv)
appUri=$(az ad app list --query [].identifierUris[0] -o tsv)
echo "app id/name: $appId/$displayName"
echo "app uri: $appUri"
# to show: az ad sp show --id $appUri
# to delete: az ad sp delete --id $appUri

# insert variables into template, prepared as terraform values
sedcmd=''
for var in subscriptionId appId thepassword tenantId ;do
  printf -v sc 's/$%s/%s/;' $var "${!var//\//\\/}"
  sedcmd+="$sc"
done
sed -e "$sedcmd" <terraform.tfvars.template > terraform.tfvars
echo -e "\nWRITTEN: terraform.tfvars"

