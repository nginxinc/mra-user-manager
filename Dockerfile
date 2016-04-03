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
	--no-install-recommends && rm -r /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY ./requirements.txt /usr/src/app/
RUN pip install -r requirements.txt

COPY . /usr/src/app

# Download certificate and key from the the vault and copy to the build context
ARG VAULT_TOKEN
RUN mkdir -p /etc/ssl/nginx
RUN wget -q -O - --header="X-Vault-Token: $VAULT_TOKEN" http://vault.ngra.ps.nginxlab.com:8200/v1/secret/nginx-repo.crt | jq -r .data.value > /etc/ssl/nginx/nginx-repo.crt
RUN wget -q -O - --header="X-Vault-Token: $VAULT_TOKEN" http://vault.ngra.ps.nginxlab.com:8200/v1/secret/nginx-repo.key | jq -r .data.value > /etc/ssl/nginx/nginx-repo.key

# Get other files required for installation
COPY ./certificate.pem /etc/ssl/nginx/
COPY ./key.pem /etc/ssl/nginx/
COPY ./dhparam.pem /etc/ssl/nginx/
# COPY ./letsencrypt.etc /etc/letsencrypt
# COPY /letsencrypt /usr/local/letsencrypt

RUN wget -q -O /etc/ssl/nginx/CA.crt https://cs.nginx.com/static/files/CA.crt && \
	wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add - && \
	wget -q -O /etc/apt/apt.conf.d/90nginx https://cs.nginx.com/static/files/90nginx && \
	printf "deb https://plus-pkgs.nginx.com/debian `lsb_release -cs` nginx-plus\n" >/etc/apt/sources.list.d/nginx-plus.list

#Install NGINX Plus
RUN apt-get update && apt-get install -y apt-transport-https nginx-plus-extras

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
	ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]

COPY nginx.conf /etc/nginx/nginx.conf
COPY ./nginx-gz.conf /etc/nginx/
COPY ./nginx-ssl.conf /etc/nginx/

RUN API_KEY='0202c79a3d8411fcf82b35bc3d458f7e' HOSTNAME='mesos-user-manager' sh ./amplify_install.sh

CMD ["./start.sh"]

EXPOSE 80 443