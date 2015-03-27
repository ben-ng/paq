all: js cli

js: paq/acorn.bundle.js paq/escodegen.bundle.js

cli: bin/paq

test: js
	echo "Compiling"
	@xctool -project paq.xcodeproj -scheme paq-tests -sdk macosx build && \
	echo "Running Tests"
	@t="/paq-tests" && \
	d=$$(xcodebuild -project paq.xcodeproj -showBuildSettings | grep CONFIGURATION_BUILD_DIR | cut -c31-) && \
	c=$$d$$t && f="$${c/Release/Debug}" && \
	eval "$$f"

paq/acorn.bundle.js: node_modules/acorn/package.json node_modules/uglifyjs/package.json
	@node node_modules/browserify/bin/cmd.js -s acorn node_modules/acorn | node node_modules/uglifyjs/bin/uglifyjs > paq/acorn.bundle.js

paq/escodegen.bundle.js: node_modules/escodegen/package.json node_modules/uglifyjs/package.json
	@node node_modules/browserify/bin/cmd.js -s escodegen node_modules/escodegen | node node_modules/uglifyjs/bin/uglifyjs > paq/escodegen.bundle.js

bin/paq:
	echo "Compiling..."
	@t="/paq" && \
	d=$$(xcodebuild -project paq.xcodeproj -showBuildSettings | grep CONFIGURATION_BUILD_DIR | cut -c31-) && \
	c=$$d$$t && \
	xctool -project paq.xcodeproj -configuration release -scheme paq -sdk macosx build && \
	mkdir -p bin && \
	mv $$c bin

clean:
	- rm paq/acorn.bundle.js paq/escodegen.bundle.js bin/paq
