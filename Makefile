.PHONY: bootstrap init plan apply configure deploy verify test simulate destroy clean

bootstrap:
	bash scripts/bootstrap-control-node.sh

init:
	terraform -chdir=terraform init

plan:
	terraform -chdir=terraform plan

apply:
	terraform -chdir=terraform apply -auto-approve

configure:
	ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/site.yml

deploy:
	bash scripts/deploy.sh

verify:
	bash scripts/verify.sh

test:
	bash scripts/test_infrastructure.sh $$(terraform -chdir=terraform output -raw lb_public_ip) $$(terraform -chdir=terraform output -raw nagios_public_ip) $$(ls .ssh/*-key.pem 2>/dev/null | head -n 1)

destroy:
	bash scripts/destroy.sh

clean:
	rm -f .ssh/*.pem ansible/inventory/hosts.ini ansible/group_vars/all/generated.yml
