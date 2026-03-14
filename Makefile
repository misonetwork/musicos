.PHONY: test build

test:
	sui move test -i 100000000000

build:
	sui move build
