# Copyright 2018 The OPA Authors. All rights reserved.
# Use of this source code is governed by an Apache2
# license that can be found in the LICENSE file.

ARG GOOS=TARGETOS
ARG GOARCH=TARGETARCH

FROM gcr.io/distroless/base

WORKDIR /app

COPY opa_envoy_${GOOS}_${GOARCH} /app

ENTRYPOINT ["./opa_envoy_${GOOS}_${GOARCH}"]

CMD ["run"]
