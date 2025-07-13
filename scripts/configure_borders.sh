#!/bin/bash

# Configure JankyBorders with default settings
# Run this after borders service is started

# Wait a moment for borders to fully start
sleep 1

# Configure borders with default settings
borders active_color=0xffffff00 \
        inactive_color=0x00000000 \
        width=0.5 \
        style=round \
        hidpi=on \
        