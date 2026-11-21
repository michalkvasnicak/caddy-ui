APP := .build/CaddyUI.app
CONFIGURATION ?= debug

.PHONY: app run
app:
	swift build -c $(CONFIGURATION)
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/"
	cp "$$(swift build -c $(CONFIGURATION) --show-bin-path)/CaddyUI" "$(APP)/Contents/MacOS/CaddyUI"
	codesign --force --sign - "$(APP)"

run: app
	open "$(APP)"
