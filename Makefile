.PHONY: check plan
check:
	python3 scripts/check.py
plan:
	python3 build/pipeline.py pi4-arm64 --plan
