ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache \
    nodejs \
    npm \
    git

# Bake TypeSpec compiler and ebus-typespec emitter into the image
# so they don't need to be downloaded on every run
RUN npm install -g \
    @typespec/compiler \
    @ebusd/ebus-typespec

COPY rootfs /
RUN chmod a+x /etc/s6-overlay/s6-rc.d/ebusd-typespec-compiler/run
