d = $$(xcodebuild -showBuildSettings 2> /dev/null | grep CONFIGURATION_BUILD_DIR | cut -c31-)

all: js cli

js: paq/acorn.bundle.js paq/escodegen.bundle.js paq/builtins.bundle.json paq/concat-stream.bundle.js

cli: bin/paq

test: compile-test run-test

compile-test:
	@echo "Compiling Tests..."
	@xctool -scheme paq-tests -sdk macosx -configuration Release build

copy-fixtures:
	@echo "Copying Fixtures To $d/fixtures..."
	-@ed="$d" && \
	rm -rf $$ed/fixtures || true && \
	mkdir -p "$$ed/fixtures" && \
	cp -rf fixtures "$$ed" && \
	cp -rf node_modules/hbsfy "$$ed/fixtures/node_modules" && \
	cp -rf node_modules/handlebars "$$ed/fixtures/node_modules"

run-test:
	@echo "Running Tests..."
	@ed="$d" && \
	echo "Running tests from $$ed" && \
	cd $$ed && \
	./paq-tests

submit-coverage:
	@echo "Submitting Coverage Report..."
	@ed="$d" && \
	bd=$$(dirname "$$ed") && \
	bd=$$(dirname "$$bd") && \
	echo "Build Dir: $$bd" && \
	echo "service_name: travis-ci\n\
	coverage_service: coveralls\n\
	xcodeproj: paq.xcodeproj\n\
	ignore:\n\
	  - paq-tests/catch.hpp" > .slather.yml
	slather coverage -b $$bd -s paq.xcodeproj

paq/builtins.bundle.json: node_modules/browserify/package.json scripts/builtins.js
	@echo "Compiling builtins..."
	@node scripts/builtins.js > paq/builtins.bundle.json

paq/acorn.bundle.js: node_modules/acorn/package.json
	@echo "Compiling acorn..."
	@node node_modules/browserify/bin/cmd.js -s acorn node_modules/acorn | node node_modules/uglifyjs/bin/uglifyjs > paq/acorn.bundle.js

paq/concat-stream.bundle.js: node_modules/concat-stream/package.json
	@echo "Compiling concat-stream..."
	@node node_modules/browserify/bin/cmd.js -s concat node_modules/concat-stream | node node_modules/uglifyjs/bin/uglifyjs > paq/concat-stream.bundle.js

paq/escodegen.bundle.js: node_modules/escodegen/package.json
	@echo "Compiling escodegen..."
	@node node_modules/browserify/bin/cmd.js -s escodegen node_modules/escodegen | node node_modules/uglifyjs/bin/uglifyjs > paq/escodegen.bundle.js

bin/paq:
	@echo "Compiling paq..."
	@ed="$d" && \
	c="$$ed/paq" && \
	xctool -configuration release -scheme paq -sdk macosx build && \
	mkdir -p bin && \
	mv $$c bin

clean:
	rm -rf paq/acorn.bundle.js paq/escodegen.bundle.js paq/builtins.bundle.json bin/paq $(d)/fixtures
