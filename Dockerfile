FROM ngrefarch/python_base:3.5

ARG CONTAINER_ENGINE_ARG
ENV USE_NGINX_PLUS=true \
    USE_VAULT=false \
# CONTAINER_ENGINE_ARG specifies the container engine to which the
# containers will be deployed. Valid values are:
# - kubernetes
# - mesos
# - local
    CONTAINER_ENGINE=${CONTAINER_ENGINE_ARG:-kubernetes}

COPY nginx/ssl /etc/ssl/nginx/

COPY ./app /usr/src/app
COPY nginx /etc/nginx/
ADD install-nginx.sh /usr/local/bin/
WORKDIR /usr/src/app
# Install NGINX and the application
RUN pip install --no-cache-dir -r requirements.txt && \
    /usr/local/bin/install-nginx.sh && \
# forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access_log && \
	ln -sf /dev/stderr /var/log/nginx/error_log && \
	python -m unittest

VOLUME ["/var/cache/nginx"]

COPY ./app/status.html /usr/share/nginx/html/status.html

EXPOSE 80 443

CMD ["./start.sh"]
