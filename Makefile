# pxt-nezbot — Makefile
#
# Thin wrapper over the npm scripts in package.json, which in turn call
# the shell scripts in scripts/. `make X` and `npm run X` do the same thing;
# scripts/ holds the single implementation of each.
#
# Everything runs inside the repo — no global state touched.

SHELL := /bin/bash

# Overridable: make deploy MICROBIT=/Volumes/OTHER, make code PORT=8080
# MICROBIT has no default here: unset, scripts/deploy.sh finds the drive by its
# label, which is what makes `make deploy` work on Linux as well as macOS.
PORT     ?= 3232

export PORT

.PHONY: setup build build-cloud deploy deploy-cloud flash code update clean docker-pull help

## setup — install Node deps, pxt-microbit target, and extension deps
setup:
	npm run setup

## docker-pull — pre-pull the yotta-compiler image for local builds
docker-pull:
	npm run docker:pull
	@echo "Image cached as pext/yotta:latest — local builds will use it"

## build — compile locally (uses yotta-compiler Docker image)
build:
	npm run build

## build-cloud — compile via MakeCode cloud service (no Docker needed)
build-cloud:
	npm run build:cloud

## deploy — build locally, then flash to micro:bit
deploy:
	npm run deploy

## deploy-cloud — cloud build, then flash to micro:bit
deploy-cloud:
	npm run deploy:cloud

## flash — copy a previously-built hex to micro:bit
flash:
	npm run flash

## code — start local MakeCode editor (http://localhost:3232)
code:
	npm run code

## update — pin nezha-diffdrive to the latest GitHub release, reinstall, rebuild
update:
	npm run update

## clean — remove build artifacts
clean:
	npm run clean

## help — show this help
help:
	@grep -E '^## ' Makefile | sed 's/## //'
