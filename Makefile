APP_NAME = WinMan
APP_BUNDLE = $(APP_NAME).app
BUILD_DIR = .build/release
BIN = $(BUILD_DIR)/$(APP_NAME)
ZIP_NAME = $(APP_NAME).zip

.PHONY: all build release app dist run clean install

all: app

build:
	swift build

release:
	swift build -c release

app: release
	@echo "Creating $(APP_BUNDLE)..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@if [ -d Resources ]; then cp -R Resources/* $(APP_BUNDLE)/Contents/Resources/; fi
	@echo "Done! Application bundle built at $(APP_BUNDLE)"

dist: app
	@echo "Packaging $(ZIP_NAME)..."
	@rm -f $(ZIP_NAME) $(ZIP_NAME).sha256
	@ditto -c -k --keepParent $(APP_BUNDLE) $(ZIP_NAME)
	@shasum -a 256 $(ZIP_NAME) > $(ZIP_NAME).sha256
	@echo "Packaged $(ZIP_NAME) successfully!"

run:
	swift run

clean:
	rm -rf .build $(APP_BUNDLE) winman.app $(ZIP_NAME) $(ZIP_NAME).sha256

install: app
	@echo "Installing to /Applications..."
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed $(APP_NAME) to /Applications!"
