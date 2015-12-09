tag = ngrefarch/user-manager
volumes = -v $(CURDIR):/usr/src/app
ports = -p 80:8080

build:
	docker build -t $(tag) .

run:
	docker run -it $(ports) $(tag)

run-v:
	docker run -it $(ports) $(volumes) $(tag)

shell:
	docker run -it $(ports) $(volumes) $(tag) bash

push:
	docker push $(tag)