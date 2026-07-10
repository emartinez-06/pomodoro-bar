APP     := $(HOME)/Applications/PomodoroBar.app

BORDERS_SRC := third_party/janky-borders
BORDERS_BIN := .build/borders/borders
BORDERS_FILES := $(BORDERS_SRC)/src/main.c $(BORDERS_SRC)/src/parse.c $(BORDERS_SRC)/src/mach.c \
	$(BORDERS_SRC)/src/hashtable.c $(BORDERS_SRC)/src/events.c $(BORDERS_SRC)/src/windows.c \
	$(BORDERS_SRC)/src/border.c $(BORDERS_SRC)/src/animation.c
BORDERS_LIBS := -framework AppKit -framework CoreVideo -F/System/Library/PrivateFrameworks/ -framework SkyLight

.PHONY: build test install uninstall restart logs dist borders

build:
	swift build -c release

borders: $(BORDERS_BIN)

$(BORDERS_BIN): $(BORDERS_FILES)
	mkdir -p $(dir $(BORDERS_BIN))
	clang -std=c99 -O3 $(BORDERS_FILES) -o $(BORDERS_BIN) $(BORDERS_LIBS)

test: build
	.build/release/PomodoroBar --selftest

# Installs the app bundle and (re)launches it. Launch-at-login is handled
# entirely by the in-app Settings toggle (ServiceManagement/SMAppService),
# not by this target - PomodoroBar isn't a LaunchAgent.
install: build borders
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/PomodoroBar $(APP)/Contents/MacOS/
	cp $(BORDERS_BIN) $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	cp $(BORDERS_SRC)/LICENSE $(APP)/Contents/Resources/JankyBorders-LICENSE
	cp $(BORDERS_SRC)/NOTICE.md $(APP)/Contents/Resources/JankyBorders-NOTICE.md
	pkill -x PomodoroBar 2>/dev/null || true
	sleep 0.5
	open $(APP)

uninstall:
	pkill -x PomodoroBar 2>/dev/null || true
	rm -rf $(APP)

restart: install

logs:
	log stream --predicate 'process == "PomodoroBar"' --style compact

dist: build borders
	rm -rf dist
	mkdir -p dist/PomodoroBar.app/Contents/MacOS dist/PomodoroBar.app/Contents/Resources
	cp .build/release/PomodoroBar dist/PomodoroBar.app/Contents/MacOS/
	cp $(BORDERS_BIN) dist/PomodoroBar.app/Contents/MacOS/
	cp Resources/Info.plist dist/PomodoroBar.app/Contents/
	cp $(BORDERS_SRC)/LICENSE dist/PomodoroBar.app/Contents/Resources/JankyBorders-LICENSE
	cp $(BORDERS_SRC)/NOTICE.md dist/PomodoroBar.app/Contents/Resources/JankyBorders-NOTICE.md
	cd dist && zip -qry PomodoroBar.app.zip PomodoroBar.app
	mkdir -p dist/dmg-root
	cp -R dist/PomodoroBar.app dist/dmg-root/
	ln -s /Applications dist/dmg-root/Applications
	hdiutil create -volname PomodoroBar -srcfolder dist/dmg-root -ov -format UDZO dist/PomodoroBar.dmg
	rm -rf dist/dmg-root
