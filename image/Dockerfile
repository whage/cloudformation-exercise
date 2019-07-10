from python:alpine3.9

RUN mkdir webapp && \
    cd webapp && \
    python3 -m venv env && \
    source env/bin/activate && \
    pip install Flask

COPY main.py /webapp/
COPY start_server.sh /webapp/start_server.sh

ENTRYPOINT ["/webapp/start_server.sh"]
