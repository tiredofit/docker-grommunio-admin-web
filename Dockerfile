ARG DISTRO="alpine"
ARG PHP_BASE=8.0

FROM docker.io/tiredofit/nginx-php-fpm:${DISTRO}-${PHP_BASE} as grommunio-admin-web-builder
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG GROMMUNIO_ADMIN_WEB_VERSION

ENV GROMMUNIO_ADMIN_WEB_VERSION=${GROMMUNIO_ADMIN_WEB_VERSION:-"2.5.0"} \
    GROMMUNIO_ADMIN_WEB_REPO_URL=${GROMMUNIO_ADMIN_WEB_REPO_URL:-"https://github.com/grommunio/grommunio-admin-web.git"}

ADD build-assets/ /build-assets

RUN source /assets/functions/00-container && \
    set -ex && \
    apk update && \
    apk upgrade && \
    apk add -t .grommunio-admin-web-build-deps \
               git \
               make \
               nodejs \
               tar \
               yarn \
               && \
    \
    ### Fetch Source
    clone_git_repo ${GROMMUNIO_ADMIN_WEB_REPO_URL} ${GROMMUNIO_ADMIN_WEB_VERSION} && \
    \
    set +e && \
    if [ -d "/build-assets/src" ] ; then cp -Rp /build-assets/src/* /usr/src/grommunio-web ; fi; \
    if [ -d "/build-assets/scripts" ] ; then for script in /build-assets/scripts/*.sh; do echo "** Applying $script"; bash $script; done && \ ; fi ; \
    set -e && \
    \
    make && \
    make dist && \
    \
    ### Setup RootFS
    mkdir -p /rootfs/assets/.changelogs && \
    mkdir -p /rootfs/www/grommunio-admin && \
    mkdir -p /rootfs/etc/grommunio-admin/common && \
    mkdir -p /rootfs/assets/grommunio/config/admin-web && \
    \
    ### Move files to RootFS
    cp -Rp dist/* /rootfs/www/grommunio-admin/ && \
    chown -R ${NGINX_USER}:${NGINX_GROUP} /rootfs/www/grommunio-admin && \
    \
    ### Cleanup and Compress Package
    echo "Gromunio Admin Web ${GROMMUNIO_ADMIN_WEB_VERSION} built from ${GROMMUNIO_ADMIN_WEB_REPO_URL} on $(date +'%Y-%m-%d %H:%M:%S')" > /rootfs/assets/.changelogs/grommunio-admin-web.version && \
    echo "Commit: $(cd /usr/src/grommunio-dav ; echo $(git rev-parse HEAD))" >> /rootfs/assets/.changelogs/grommunio-admin-web.version && \
    env | grep GROMMUNIO | sort >> /rootfs/assets/.changelogs/grommunio-admin-web.version && \
    cd /rootfs/ && \
    find . -name .git -type d -print0|xargs -0 rm -rf -- && \
    mkdir -p /grommunio-admin-web/ && \
    tar cavf /grommunio-admin-web/grommunio-admin-web.tar.zst . &&\
    \
    ### Cleanup
    apk del .grommunio-admin-web-build-deps && \
    rm -rf /usr/src/* /var/cache/apk/*

FROM scratch
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

COPY --from=grommunio-admin-web-builder /grommunio-admin-web/* /grommunio-admin-web/
COPY CHANGELOG.md /tiredofit_docker-grommunio-admin-web.md
