FROM ghcr.io/gleam-lang/gleam:v1.4.1-erlang-alpine

# c compiler needed for sqlite
Run apk add build-base

# Add project code
COPY . /build/

# Compile the project
RUN cd /build \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build

# Run the server
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
