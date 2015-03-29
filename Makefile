d=$$(xcodebuild -showBuildSettings 2> /dev/null | grep TARGET_BUILD_DIR | cut -c24-)
diag_reports=~/Library/Logs/DiagnosticReports

all: js cli

js: paq/acorn.bundle.js paq/escodegen.bundle.js paq/builtins.bundle.json paq/concat-stream.bundle.js

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

copy-fixtures: copy-gcov-fixtures copy-debug-fixtures copy-release-fixtures

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
	./paq-tests && echo "passed" > ~/paq-passed.txt
	@if test -f "~/paq-passed.txt"; then cd $(diag_reports) && cat $$(ls | grep "paq-tests" -m 1) && cat "$(diag_reports)/$$f"; fi;
	@unlink ~/paq-passed.txt

show-crash:
	@cd $(diag_reports) && cat $$(ls | grep "paq-tests" -m 1)

show-build-dir:
	@e=$d && \
	b=$$(dirname "$$e") && \
	b=$$(dirname "$$b") && \
	echo "Build Dir: $$b" && \
	cd $$b && \
	tree | grep .gcno

slather:
	@e=$d && \
	b=$$(dirname "$$e") && \
	b=$$(dirname "$$b") && \
	slather coverage -b $$b

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
	xctool -configuration Release -scheme paq -sdk macosx build && \
	mkdir -p bin && \
	mv $$c bin

clean:
	rm -rf paq/acorn.bundle.js paq/escodegen.bundle.js paq/builtins.bundle.json bin/paq $(d)/fixtures
