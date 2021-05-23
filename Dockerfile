#  --- Build ---
FROM bitwalker/alpine-elixir-phoenix:1.10.3 AS builder
WORKDIR /app
COPY . .
ENV MIX_ENV=prod
RUN cd catena_api && mix do deps.get --only prod, deps.compile
RUN cd catena_api && mix do phx.digest, release --overwrite

#  --- Run ---
FROM alpine:latest AS runner
RUN apk update && apk --no-cache --update add bash openssl
WORKDIR /app
COPY --from=builder /app/catena_api/_build/prod/rel/catena_api .

ENTRYPOINT ["bin/catena_api"]
CMD ["start"]