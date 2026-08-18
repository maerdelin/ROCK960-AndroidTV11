SHELL := /bin/bash

.PHONY: doctor network sync port audit preflight build pack verify one-shot test clean-generated

doctor:
	./scripts/doctor.sh
network:
	./scripts/network-preflight.sh
sync:
	./scripts/sync.sh
port:
	./scripts/apply-port.sh
audit:
	./scripts/audit-source.sh
preflight:
	./scripts/preflight-build.sh
build:
	./scripts/build.sh
pack:
	./scripts/pack.sh
verify:
	./scripts/verify-artifacts.sh
one-shot:
	./scripts/one-shot.sh
test:
	./tests/run.sh
clean-generated:
	./scripts/clean-generated.sh
