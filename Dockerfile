# Stage 1: Build JavaScript assets
FROM node:16 AS js-build
WORKDIR /gotty
COPY js /gotty/js
COPY Makefile /gotty/
RUN make bindata/static/js/gotty.js.map

# Stage 2: Build Go application
FROM golang:1.20 AS go-build
WORKDIR /gotty
COPY . /gotty
COPY --from=js-build /gotty/js/node_modules /gotty/js/node_modules
COPY --from=js-build /gotty/bindata/static/js /gotty/bindata/static/js
RUN CGO_ENABLED=0 make

# Stage 3: Download kubectl using curl image
FROM curlimages/curl:7.78.0 AS kubectl-build
WORKDIR /download
ARG KUBECTL_VERSION="v1.31.2"
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /download  && \
    chmod +x /download/kubectl

# Stage 4: Download k9s using curl image
FROM curlimages/curl:7.78.0 AS k9s-build
WORKDIR /download
ARG K9S_VERSION="v0.32.7"
# RUN curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o /download && \
#     tar -zxvf k9s_Linux_amd64.tar.gz && \
RUN curl -sS https://webi.sh/k9s -o /download/k9s_install
RUN chmod +x /download/k9s_install
RUN /download/k9s_install
RUN chmod +x $HOME/.local/bin/k9s && mv $HOME/.local/bin/k9s /download/k9s

# Stage 5: Final image
FROM alpine:latest
RUN apk --no-cache add ca-certificates bash
WORKDIR /root
COPY --from=go-build /gotty/gotty /usr/bin/
COPY --from=kubectl-build /download/kubectl /usr/local/bin/
COPY --from=k9s-build /download/k9s /usr/local/bin/
CMD ["gotty", "-w", "bash"]
