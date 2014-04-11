DEST = build
MAIN = src/Player.as
SRCS = $(shell find src/ -type f -name '*.as')
SWF = $(DEST)/Player.swf
MXMLC = $(FLEX_HOME)/bin/mxmlc
MXMLC_OPTIONS = \
		-use-network \
		-static-link-runtime-shared-libraries=true \
		-use-resource-bundle-metadata \
		-accessible=false \
		-allow-source-path-overlap=false \
		-target-player=11.1 \
		-locale en_US \
		-output $(SWF) \
		-debug=true \
		-benchmark=false \
		-verbose-stacktraces=false \
		-strict \
		-warnings \
		-show-unused-type-selector-warnings \
		-show-actionscript-warnings \
		-show-binding-warnings \
		-show-invalid-css-property-warnings \
		-incremental=false \
		-es=false \
		-include-libraries="ext/as3corelib/bin/as3corelib.swc"

all: $(SWF)

install: all

clean:
	rm -rf $(DEST)
	rm VERSION

ext/as3corelib/bin/as3corelib.swc:
	git submodule init
	git submodule update
	ant -f ext/as3corelib/build/build.xml

VERSION: .git
	git describe --exact 2>/dev/null >$@ || \
		echo `git describe --abbrev=0 --tags`.`git rev-parse --short HEAD`-dev 2>/dev/null >$@

$(SWF): $(SRCS) VERSION Makefile ext/as3corelib/bin/as3corelib.swc
	@mkdir -p $(DEST)
	$(MXMLC) $(MXMLC_OPTIONS) $(MAIN)
