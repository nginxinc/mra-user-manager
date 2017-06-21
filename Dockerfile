FROM python:3.5.1

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
	--no-install-recommends && rm -r /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install vault client
RUN wget -q https://releases.hashicorp.com/vault/0.6.0/vault_0.6.0_linux_amd64.zip && \
	  unzip -d /usr/local/bin vault_0.6.0_linux_amd64.zip
COPY ./requirements.txt /usr/src/app/
RUN pip install -r requirements.txt

# Download certificate and key from the the vault and copy to the build context
ENV VAULT_TOKEN=4b9f8249-538a-d75a-e6d3-69f5355c1751 \
    VAULT_ADDR=http://vault.mra.nginxps.com:8200

RUN mkdir -p /etc/ssl/nginx && \
    vault token-renew && \
    vault read -field=value secret/nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt && \
    vault read -field=value secret/nginx-repo.key > /etc/ssl/nginx/nginx-repo.key && \
    vault read -field=value secret/ssl/csr.pem > /etc/ssl/nginx/csr.pem && \
    vault read -field=value secret/ssl/certificate.pem > /etc/ssl/nginx/certificate.pem && \
    vault read -field=value secret/ssl/key.pem > /etc/ssl/nginx/key.pem && \
    vault read -field=value secret/ssl/dhparam.pem > /etc/ssl/nginx/dhparam.pem

RUN wget -q -O /etc/ssl/nginx/CA.crt https://cs.nginx.com/static/files/CA.crt && \
    wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add - && \
    wget -q -O /etc/apt/apt.conf.d/90nginx https://cs.nginx.com/static/files/90nginx && \
    printf "deb https://plus-pkgs.nginx.com/debian `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-plus.list

#Install NGINX Plus
RUN apt-get update && apt-get install -y apt-transport-https nginx-plus

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

COPY nginx /etc/nginx/

COPY ./status.html /usr/share/nginx/html/status.html

COPY requirements.txt /usr/src/app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /usr/src/app

# Install Amplify
RUN curl -sS -L -O  https://github.com/nginxinc/nginx-amplify-agent/raw/master/packages/install.sh && \
	API_KEY='0202c79a3d8411fcf82b35bc3d458f7e' AMPLIFY_HOSTNAME='mesos-user-manager' sh ./install.sh

# Install and run NGINX config generator
RUN wget -q https://s3-us-west-1.amazonaws.com/fabric-model/config-generator/generate_config
RUN chmod +x generate_config && \
   ./generate_config -p /etc/nginx/fabric_config.yaml > /etc/nginx/nginx-fabric.conf

CMD ["./start.sh"]

EXPOSE 80 443
