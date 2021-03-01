all: install

generate-docs: install
	@terraform-docs markdown . > README.md

install:
	@true

pr:
	@hub pull-request -b $(b)

.PHONY: all \
		generate-docs \
		install \
		pr
