d=$$(xcodebuild -showBuildSettings 2> /dev/null | grep TARGET_BUILD_DIR | cut -c24-)
diag_reports=~/Library/Logs/DiagnosticReports

all: js cli

js: paq/detective.bundle.js paq/builtins.bundle.json paq/concat-stream.bundle.js

cli: bin/paq

test: compile-test run-test

compile-test:
	@echo "Compiling Tests..."
	@xctool build -scheme paq-tests \
	-sdk macosx \
	-configuration GCov_Build \
	ONLY_ACTIVE_ARCH=NO \
	GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES \
	GCC_GENERATE_TEST_COVERAGE_FILES=YES

copy-fixtures: copy-browserify copy-gcov-fixtures copy-debug-fixtures copy-release-fixtures

copy-browserify:
	@e=$d && \
	rm -rf $$e/../node_modules || true && \
	mkdir -p "$$e/../node_modules" && \
	cp -rf node_modules/browserify "$$e/../node_modules"

copy-release-fixtures:
	@e=$d && \
	echo "Copying Fixtures To $$e/fixtures..." && \
	rm -rf $$e/fixtures || true && \
	mkdir -p "$$e/fixtures" && \
	cp -rf fixtures "$$e" && \
	cp -rf node_modules/hbsfy "$$e/fixtures/node_modules" && \
	cp -rf node_modules/handlebars "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babelify "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babel-runtime "$$e/fixtures/node_modules" && \
	mv "$$e/fixtures/babel-core-patch.js" "$$e/fixtures/node_modules/babelify/node_modules/babel-core/lib/babel/api/register/node.js"

copy-gcov-fixtures:
	@e=$d && \
	e="$${e/Release/GCov_Build}" && \
	echo "Copying Fixtures To $$e/fixtures..." && \
	rm -rf $$e/fixtures || true && \
	mkdir -p "$$e/fixtures" && \
	cp -rf fixtures "$$e" && \
	cp -rf node_modules/hbsfy "$$e/fixtures/node_modules" && \
	cp -rf node_modules/handlebars "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babelify "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babel-runtime "$$e/fixtures/node_modules" && \
	mv "$$e/fixtures/babel-core-patch.js" "$$e/fixtures/node_modules/babelify/node_modules/babel-core/lib/babel/api/register/node.js"

copy-debug-fixtures:
	@e=$d && \
	e="$${e/Release/Debug}" && \
	echo "Copying Fixtures To $$e/fixtures..." && \
	rm -rf $$e/fixtures || true && \
	mkdir -p "$$e/fixtures" && \
	cp -rf fixtures "$$e" && \
	cp -rf node_modules/hbsfy "$$e/fixtures/node_modules" && \
	cp -rf node_modules/handlebars "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babelify "$$e/fixtures/node_modules" && \
	cp -rf node_modules/babel-runtime "$$e/fixtures/node_modules" && \
	mv "$$e/fixtures/babel-core-patch.js" "$$e/fixtures/node_modules/babelify/node_modules/babel-core/lib/babel/api/register/node.js"

run-test:
	@echo "Running Tests..."
	@e=$d && \
	e="$${e/Release/GCov_Build}" && \
	echo "Running tests from $$e" && \
	cd $$e && \
	./paq-tests

show-crash:
	@cd $(diag_reports) && ls | grep "paq-tests" | while read -r line ; do echo "------ Crash Report: $$line ------\n" && cat "$$line"; done

show-build-dir:
	@e=$d && \
	b=$$(dirname "$$e") && \
	b=$$(dirname "$$b") && \
	echo "Build Dir: $$b" && \
	cd $$b && \
	tree | grep .gcno

paq/builtins.bundle.json: node_modules/browserify/package.json scripts/builtins.js
	@echo "Compiling builtins..."
	@node scripts/builtins.js > paq/builtins.bundle.json

paq/detective.bundle.js: node_modules/detective/package.json
	@echo "Compiling detective..."
	@node node_modules/browserify/bin/cmd.js --noParse "$$(pwd)/node_modules/detective/node_modules/acorn/dist/acorn.js" -s detective "$$(pwd)/node_modules/detective/index.js" | node node_modules/uglifyjs/bin/uglifyjs > paq/detective.bundle.js

paq/concat-stream.bundle.js: node_modules/concat-stream/package.json
	@echo "Compiling concat-stream..."
	@node node_modules/browserify/bin/cmd.js -s concat node_modules/concat-stream | node node_modules/uglifyjs/bin/uglifyjs > paq/concat-stream.bundle.js

bin/paq:
	@echo "Compiling paq..."
	@ed="$d" && \
	c="$$ed/paq" && \
	xctool -configuration Release -scheme paq -sdk macosx build && \
	mkdir -p bin && \
	mv $$c bin

clean:
	rm -rf paq/*.bundle.js paq/builtins.bundle.json bin/paq $(d)/fixtures
