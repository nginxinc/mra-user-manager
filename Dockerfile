FROM python:3.5.1

ARG CONTAINER_ENGINE
ENV USE_NGINX_PLUS=true \
    USE_VAULT=false \
# CONTAINER_ENGINE specifies the container engine to which the
# containers will be deployed. Valid values are:
# - kubernetes
# - mesos
# - local
    CONTAINER_ENGINE=${CONTAINER_ENGINE:-kubernetes}

COPY nginx/ssl /etc/ssl/nginx/
# Set the debconf front end to Noninteractive
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
# persistent / runtime deps
    apt-get update && apt-get install -y \
	jq \
	libffi-dev \
	libssl-dev \
	make \
	wget \
	apt-transport-https \
	ca-certificates \
	curl \
	librecode0 \
	libsqlite3-0 \
	libxml2 \
	lsb-release \
	unzip \
	--no-install-recommends && rm -r /var/lib/apt/lists/*
#	mkdir -p /usr/src/app

COPY ./app /usr/src/app
COPY nginx /etc/nginx/
ADD install-nginx.sh /usr/local/bin/
WORKDIR /usr/src/app
# Install NGINX and the application
RUN pip install --no-cache-dir -r requirements.txt && \
    /usr/local/bin/install-nginx.sh && \
# forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access_log && \
	ln -sf /dev/stderr /var/log/nginx/error_log

VOLUME ["/var/cache/nginx"]

COPY ./app/status.html /usr/share/nginx/html/status.html

EXPOSE 80 443

CMD ["./start.sh"]
