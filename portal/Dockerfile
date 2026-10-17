ARG FILEBROWSER_IMAGE=filebrowser/filebrowser:v2.30.0
FROM ${FILEBROWSER_IMAGE} AS upstream
FROM alpine:3.22
COPY --from=upstream /filebrowser /filebrowser
COPY entrypoint.sh /entrypoint.sh
RUN mkdir -p /data/respaldos /database && chmod 755 /entrypoint.sh
USER 1000:1000
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
