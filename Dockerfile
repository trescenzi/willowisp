FROM ghcr.io/gleam-lang/gleam:v1.4.1-erlang-alpine

# c compiler needed for sqlite
Run apk add build-base
# for litefs
RUN apk add ca-certificates fuse3 sqlite
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs

# Add project code
COPY . /build/

# Compile the project
RUN cd /build \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build

COPY litefs.yml /etc/litefs.yml

# Run the server
WORKDIR /app
#ENTRYPOINT ["/app/entrypoint.sh"]
#CMD ["run"]
ENTRYPOINT litefs mount
