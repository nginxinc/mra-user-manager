FROM python:3.5.1

ENV USE_NGINX_PLUS=false \
    VAULT_TOKEN=4b9f8249-538a-d75a-e6d3-69f5355c1751 \
    VAULT_ADDR=http://vault.mra.nginxps.com:8200

# Set the debconf front end to Noninteractive
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# persistent / runtime deps
RUN apt-get update && apt-get install -y \
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
	--no-install-recommends && rm -r /var/lib/apt/lists/* && \
	mkdir -p /usr/src/app && \
# Install vault client
    wget -q https://releases.hashicorp.com/vault/0.6.0/vault_0.6.0_linux_amd64.zip && \
    unzip -d /usr/local/bin vault_0.6.0_linux_amd64.zip && \
    mkdir -p /etc/ssl/nginx

WORKDIR /usr/src/app
COPY ./requirements.txt /usr/src/app/
RUN pip install --no-cache-dir -r requirements.txt

# Install nginx
COPY nginx /etc/nginx/
ADD install-nginx.sh /usr/local/bin/
RUN /usr/local/bin/install-nginx.sh && \
# forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

COPY ./status.html /usr/share/nginx/html/status.html
COPY . /usr/src/app

CMD ["./start.sh"]

EXPOSE 80 443
