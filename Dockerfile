FROM ruby:2.6.1-stretch as base

# WORKDIR needs to be the same as in the final base image or compiled gems will point to an invalid directory
RUN mkdir -p /home/rails/app
WORKDIR /home/rails/app

# Install gems that need compiling first b/c they can take a long time to compile
RUN gem install \
    bundler:2.0.1 \
    nokogiri:1.10.2 \
    ffi:1.10.0 \
    mini_portile2:2.3.0 \
    msgpack:1.2.6 \
    pg:1.1.4 \
    nio4r:2.3.1 \
    puma:3.12.0 \
    eventmachine:1.2.7

ARG project=user
COPY ${project}/Gemfile* ./
COPY ${project}/ros-${project}.gemspec ./
# NOTE: Dependent gems need to be copied in so that their dependencies are also installed
COPY core/. ../core/
COPY sdk/. ../sdk/

# Remove reference to gems loaded from a path so bundle doesn't blow up
# RUN sed -i '/path/d' Gemfile

# # Don't use the --deployment flag since this is a container. See: http://bundler.io/man/bundle-install.1.html#DEPLOYMENT-MODE
ARG bundle_string='--without development test'
RUN bundle install ${bundle_string} \
 && find /usr/local/bundle -iname '*.o' -exec rm -rf {} \; \
 && find /usr/local/bundle -iname '*.a' -exec rm -rf {} \;

# Runtime container
FROM ruby:2.6.1-slim-stretch

# Install OS packages and create a non-root user to run the application
# To compile pg gem: libpq-dev
# To install pg client to run via bash: postgresql-client
ARG os_packages='libpq5 git less'

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends ${os_packages} \
 && apt-get clean

ARG PUID=1000
ARG PGID=1000

RUN addgroup --gid ${PGID} rails \
 && useradd -ms /bin/bash -d /home/rails --uid ${PUID} --gid ${PGID} rails \
 && mkdir -p /home/rails/app \
 && echo 'set editing-mode vi' > /home/rails/.inputrc \
 && echo "alias rspec='spring rspec $@'\nalias ss='spring stop'\nalias rs='spring rails server -b 0.0.0.0'\nalias rc='spring rails console'\nalias rk='spring rake'" > /home/rails/.bash_aliases \
 && chown rails:rails /home/rails -R \
 && echo 'rails ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

COPY --chown=rails:rails --from=base /usr/local/bundle /usr/local/bundle

# Rails operations
WORKDIR /home/rails/app

ARG project=user
COPY --chown=rails:rails ${project}/. ./
COPY --chown=rails:rails core/. ../core/
COPY --chown=rails:rails sdk/. ../sdk/

# workaround for buildkit not setting correct permissions
RUN chown rails: /home/rails/core && chown rails: /home/rails/sdk

ARG rails_env=production
ENV RAILS_ENV=${rails_env} EDITOR=vim TERM=xterm RAILS_LOG_TO_STDOUT=yes
EXPOSE 3000

USER ${PUID}:${PGID}

# Boot the application; Override this from the command line in order to run other tools
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
