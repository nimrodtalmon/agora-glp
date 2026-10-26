# AGORA live server: Ehud Shapiro's GLP repository at a pinned commit, with
# this repository's files (overlay/) on top, the server compiled ahead of time.
FROM dart:stable
ARG GLP_COMMIT=71b98414ec91ad669a790284373c068086754e8d
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git init /glp && cd /glp \
 && git remote add origin https://github.com/EShapiro2/GLP.git \
 && git fetch --depth 1 origin $GLP_COMMIT && git checkout FETCH_HEAD
COPY overlay/ /glp/
COPY tools/ /tools/
RUN bash /tools/add_to_cascade.sh /glp
WORKDIR /glp/agora_server
RUN dart pub get && dart compile exe bin/server.dart -o /glp/agora_server/server
ENV GLP_ROOT=/glp PORT=10000
EXPOSE 10000
CMD ["/glp/agora_server/server"]
