ARG BUILD_FROM
FROM $BUILD_FROM

# Node.js >= 22 is required by current TypeSpec compilers (fs.promises.glob).
# The version constraint makes the build fail early if the base image
# would ship an incompatible Node.js.
RUN apk add --no-cache \
    "nodejs>=22" \
    npm \
    git

# Build-time guard: fail the image build with a clear message instead of
# crashing at runtime with a cryptic "fs/promises does not provide glob" error.
RUN node -e "if (parseInt(process.versions.node) < 22) { console.error('Node.js >= 22 required, got ' + process.version); process.exit(1); }"

COPY rootfs /
RUN chmod a+x /etc/s6-overlay/s6-rc.d/ebusd-typespec-compiler/run
