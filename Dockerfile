# Copyright 2018 The OPA Authors. All rights reserved.
# Use of this source code is governed by an Apache2
# license that can be found in the LICENSE file.
FROM gcr.io/distroless/base

ARG TARGETOS
ARG TARGETARCH
ARG GOOS=$TARGETOS
ARG GOARCH=$TARGETARCH
ARG RELEASE_DIR=.

#RUN echo "I'm building for $GOOS-$GOARCH"

WORKDIR /app

COPY ${RELEASE_DIR}/opa_envoy_${GOOS}_${GOARCH} /app

ENTRYPOINT ["./opa_envoy_${GOOS}_${GOARCH}"]

CMD ["run"]
