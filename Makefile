THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
FQDN := azure_rsa
TF := terraform

apply: init 
	$(TF) apply -auto-approve
	$(TF) output

init: 
	## skips init if .terraform directory already exists
	[ -d .$(TF) ] || $(TF) init

## creates self-signed certificate and pfx used by azurerm provider
create-cert:
	[ -f $(FQDN).key ] || openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $(FQDN).key -out $(FQDN).crt -subj "/C=US/ST=CA/L=SFO/O=myorg/CN=$(FQDN)"
	[ -f $(FQDN).pem ] || cat $(FQDN).crt $(FQDN).key > $(FQDN).pem
	[ -f $(FQDN).pfx ] || openssl pkcs12 -export -out $(FQDN).pfx -inkey $(FQDN).key -in $(FQDN).pem -passout pass:

destroy:
	## vm extension created via file will not destroy, so remove it from state first
	$(TF) state rm azurerm_virtual_machine_extension.startup_script
	$(TF) destroy -auto-approve
	##rm terraform.tfstate*

refresh:
	$(TF) refresh

output:
	$(TF) output

