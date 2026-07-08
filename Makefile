LABEL   := com.eim.pomodoro-bar
APP     := $(HOME)/Applications/PomodoroBar.app
BINARY  := $(APP)/Contents/MacOS/PomodoroBar
PLIST   := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG     := $(HOME)/Library/Logs/pomodoro-bar.log
UID     := $(shell id -u)

.PHONY: build test install uninstall restart logs dist

build:
	swift build -c release

test: build
	.build/release/PomodoroBar --selftest

install: build
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/PomodoroBar $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	sed -e 's|__PROGRAM__|$(BINARY)|' -e 's|__LOG__|$(LOG)|' \
		Resources/$(LABEL).plist > $(PLIST)
	launchctl bootout gui/$(UID)/$(LABEL) 2>/dev/null || true
	launchctl bootstrap gui/$(UID) $(PLIST)

uninstall:
	launchctl bootout gui/$(UID)/$(LABEL) 2>/dev/null || true
	rm -f $(PLIST)
	rm -rf $(APP)

restart: install

logs:
	tail -f $(LOG)

dist: build
	rm -rf dist
	mkdir -p dist/PomodoroBar.app/Contents/MacOS
	cp .build/release/PomodoroBar dist/PomodoroBar.app/Contents/MacOS/
	cp Resources/Info.plist dist/PomodoroBar.app/Contents/
	cd dist && zip -qry PomodoroBar.app.zip PomodoroBar.app
