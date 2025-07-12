#!/bin/bash

# Script to focus window to the east - delegates to focus_direction.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
exec "$SCRIPT_DIR/focus_direction.sh" east