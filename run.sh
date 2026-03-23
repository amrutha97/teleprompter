#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ ! -d "Teleprompter.app" ]; then
    echo "Building Teleprompter.app..."
    ./build.sh
fi

open Teleprompter.app
