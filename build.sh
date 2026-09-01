#!/usr/bin/env bash
set -o errexit

if [ -d "backend" ]; then
  cd backend
fi

./build.sh
