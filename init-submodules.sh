#!/bin/bash

git submodule update --init --recursive || exit 1

echo '-- Submodules sucessfully updated'

