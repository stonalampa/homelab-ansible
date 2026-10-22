.PHONY: check cleanup integration lint syntax test update

check:
	./bin/update-check

cleanup:
	./bin/docker-cleanup

lint:
	yamllint .
	ansible-lint playbooks roles

syntax:
	ANSIBLE_LOCAL_TEMP=.ansible/tmp ANSIBLE_ROLES_PATH=roles ansible-playbook -i inventory/inventory.example.yml playbooks/update-check.yml --syntax-check

test:
	./tests/offline-check.sh

integration:
	./tests/integration-test.sh

update:
	./bin/update-all