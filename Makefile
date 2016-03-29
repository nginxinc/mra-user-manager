tag = ngrefarch/user-manager
volumes = -v $(CURDIR):/usr/src/app -v $(CURDIR)/nginx.conf:/etc/nginx/nginx.conf
ports = -p 80:80
env = --env-file=.env

build:
	docker build --build-arg VAULT_TOKEN=$(VAULT_TOKEN) -t $(tag) .

build-clean:
	docker build --no-cache --build-arg VAULT_TOKEN=$(VAULT_TOKEN) -t $(tag) .

run:
	docker run -it ${env} $(ports) $(tag)

run-v:
	docker run -it ${env} $(ports) $(volumes) $(tag)

shell:
	docker run -it ${env} $(ports) $(volumes) $(tag) bash

push:
	docker push $(tag)

test:
	# Tests not yet implemented
	
check-env:
ifndef VAULT_TOKEN
    $(error VAULT_TOKEN is undefined)
endif