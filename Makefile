THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform

apply: init 
	$(TF) apply -auto-approve
	$(TF) output

init: create-keypair
	## skips init if .terraform directory already exists
	[ -d .$(TF) ] || $(TF) init

## public/private keypair for ssh login to vms
create-keypair:
	[ -f azure_rsa ] || ssh-keygen -t rsa -b 4096 -f azure_rsa -C $(PROJECT) -N "" -q

destroy:
	$(TF) destroy -auto-approve
	##rm terraform.tfstate*

refresh:
	$(TF) refresh

output:
	$(TF) output

