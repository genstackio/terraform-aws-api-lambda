all: install

format:
	@terraform fmt -recursive

install:
	@terraform get

pr:
	@hub pull-request -b $(b)

.PHONY: all install pr