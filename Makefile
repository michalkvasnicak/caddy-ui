APP := .build/CaddyUI.app
CONFIGURATION ?= debug

.PHONY: app
app:
	swift build -c $(CONFIGURATION)
	mkdir -p "$(APP)/Contents/MacOS"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp "$$(swift build -c $(CONFIGURATION) --show-bin-path)/CaddyUI" "$(APP)/Contents/MacOS/CaddyUI"
	codesign --force --sign - "$(APP)"
