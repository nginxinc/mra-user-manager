tag = ngrefarch/user-manager
volumes = -v $(CURDIR):/usr/src/app
ports = -p 8080:8080
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