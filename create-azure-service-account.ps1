#
# Uses the azure cli to create a service account
# Populates terrform.tfvars
#
$loginlist=az account list --query [].user
if ($loginlist.Length -lt 6) {
    write-host "run 'az login' first"
    exit 1
}

# if logged in, we can get subscription and tenant id
$me=az account show --query user.name -o tsv
write-host "logged in: $me"
$subscriptionId=az account show --query id -o tsv
$tenantId=az account show --query tenantId -o tsv
write-host "subscription/tenant = $subscriptionId/$tenantId"

# if sp app exists, we can get app id, uri, and name
$appId=az ad app list --query [].appId -o tsv
if (! $appId ) {
    write-host "sp app does not exist, need to create"
    $thepassword=az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscriptionId" --out tsv --query password
}else {
    write-host "sp app already exists, recreating with new password"
    $thepassword=az ad sp credential reset --name $appId --out tsv --query password
}

$appId=az ad app list --query [].appId -o tsv
$displayName=az ad app list --query [].displayName -o tsv
$appUri=az ad app list --query [].identifierUris[0] -o tsv
write-host "app id/name: $appId/$displayName"
write-host "app uri: $appUri"

# insert variables into template, prepared as terraform values
$template = Get-Content "terraform.tfvars.template" -Raw
$expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
write-host $expanded | Set-Content -Path terraform.tfvars -Encoding UTF8
write-host "`nWRITTEN: terraform.tfvars"

