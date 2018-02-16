FROM ngrefarch/python_base:3.5

ARG CONTAINER_ENGINE_ARG
ARG USE_NGINX_PLUS_ARG
ARG USE_VAULT_ARG

# CONTAINER_ENGINE_ARG specifies the container engine to which the
# containers will be deployed. Valid values are:
# - kubernetes (default)
# - mesos
# - local
ENV USE_NGINX_PLUS=${USE_NGINX_PLUS_ARG:-true} \
    USE_VAULT=${USE_VAULT_ARG:-false} \
    CONTAINER_ENGINE=${CONTAINER_ENGINE_ARG:-kubernetes}

COPY nginx/ssl /etc/ssl/nginx/

COPY ./app /usr/src/app
COPY nginx /etc/nginx/
ADD install-nginx.sh /usr/local/bin/
WORKDIR /usr/src/app

# Install NGINX, the application, and forward request and error logs to docker log collector
RUN pip install --no-cache-dir -r requirements.txt && \
    /usr/local/bin/install-nginx.sh && \
    ln -sf /dev/stdout /var/log/nginx/access_log && \
	ln -sf /dev/stderr /var/log/nginx/error_log && \
	python -m unittest

VOLUME ["/var/cache/nginx"]



EXPOSE 80 443

CMD ["/usr/src/app/start.sh"]
