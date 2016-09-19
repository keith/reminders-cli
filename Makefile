RELEASE_BUILD=./.build/release
EXECUTABLE=reminders
PREFIX?=/usr/local/bin
ARCHIVE=$(EXECUTABLE).tar.gz

.PHONY: clean build release package install uninstall
SRC=$(wildcard Sources/*.swift)

clean:
	rm -f $(EXECUTABLE) $(ARCHIVE) _reminders
	swift build --clean

build: $(SRC)
	swift build

release: clean
	swift build \
		--configuration release \
		-Xswiftc -static-stdlib

package: release
	tar -pvczf $(ARCHIVE) -C zsh _reminders -C ../$(RELEASE_BUILD) $(EXECUTABLE)
	tar -zxvf $(ARCHIVE)
	@shasum -a 256 $(ARCHIVE)
	@shasum -a 256 $(EXECUTABLE)
	rm $(EXECUTABLE) _reminders

install: release
	install $(RELEASE_BUILD)/$(EXECUTABLE) $(PREFIX)

uninstall:
	rm "$(PREFIX)/$(EXECUTABLE)"
