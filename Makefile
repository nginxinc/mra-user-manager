tag = ngrefarch/user-manager
volumes = -v $(CURDIR):/usr/src/app
ports = -p 80:8080
env = --env-file=.env

build:
	docker build -t $(tag) .

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