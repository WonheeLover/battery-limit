.PHONY: install uninstall test lint

install:
	sudo ./install.sh

uninstall:
	sudo ./uninstall.sh

test:
	bash tests/run-tests.sh

lint:
	shellcheck bin/battery-limit install.sh uninstall.sh tests/run-tests.sh
