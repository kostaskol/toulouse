# syntax=docker/dockerfile:1
# check=error=true

# Multi-stage build with two entry points:
#
#   development  -> used by compose.yaml, includes the development/test gem
#                   groups and runs Puma directly on port 3000
#   production   -> the default target, runs Thruster in front of Puma on
#                   port 80 as a non-root user
#
#   docker build --target development -t toulouse-dev .
#   docker build -t toulouse .
#
# Keep RUBY_VERSION in sync with .ruby-version.
ARG RUBY_VERSION=3.3.4


# ---------------------------------------------------------------------------
# base: runtime packages shared by every stage
# ---------------------------------------------------------------------------
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# pg_dump refuses to dump a newer server, and Debian ships an older client than
# the Postgres 18 we run, so the client comes from the PGDG repository.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates curl && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -fsSo /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 libvips postgresql-client-18 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# jemalloc meaningfully reduces Ruby's memory footprint and tail latency.
ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"


# ---------------------------------------------------------------------------
# gem-builder: toolchain needed to compile native extensions (pg, nokogiri...)
# ---------------------------------------------------------------------------
FROM base AS gem-builder

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# ---------------------------------------------------------------------------
# development: the image compose builds
# ---------------------------------------------------------------------------
FROM gem-builder AS development

ENV RAILS_ENV="development"

# Gems are baked into the image rather than a mounted volume, so adding a gem
# means `docker compose build`. Predictable, at the cost of a rebuild.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Deliberately root: the source tree is bind-mounted from the host, and a
# non-root uid inside the container will not reliably be able to write to
# tmp/ and log/ across host platforms. The production stage is not root.
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]


# ---------------------------------------------------------------------------
# build: throw-away stage that produces the production artifacts
# ---------------------------------------------------------------------------
FROM gem-builder AS build

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disables parallel compilation to avoid a QEMU bug:
    # https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/


# ---------------------------------------------------------------------------
# production: the default target
# ---------------------------------------------------------------------------
FROM base AS production

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster terminates TLS and handles HTTP/2, compression and X-Sendfile,
# then proxies to Puma. Override CMD at runtime to run jobs or a console.
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
