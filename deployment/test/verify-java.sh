#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export MONGODB_URI='mongodb://localhost:25417/technotes_notes_test?directConnection=true'
export OAUTH_ISSUER_URI='http://localhost:29000'
export OAUTH_JWK_SET_URI='http://localhost:29000/oauth2/jwks'
export EUREKA_CLIENT_ENABLED=false
export EUREKA_REGISTER_WITH_EUREKA=false
export EUREKA_FETCH_REGISTRY=false
for component in oauth notes gateway; do
  (cd "sources/$component" && sh ./mvnw --batch-mode --no-transfer-progress clean verify)
done
