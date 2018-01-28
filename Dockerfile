FROM ngrefarch/python_base:3.5

COPY ./app /usr/src/app
WORKDIR /usr/src/app

# Install and test the application
RUN pip install --no-cache-dir -r requirements.txt && \
	python -m unittest

EXPOSE 80 443

CMD ["/usr/src/app/start.sh"]
