#!/bin/bash

set -Eeuo pipefail

echo "Preparing Oracle APEX and ORDS..."
/opt/scripts/setup-apex-admin.sh
exec /opt/scripts/start-ords.sh