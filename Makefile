-include $(AXIS_TOP_DIR)/tools/build/Rules.axis

SRC = src
DEST = bin
MAIN_AS_FILE = $(SRC)/Player.as
SWF = $(DEST)/Player.swf
MXMLC = $(FLEX_HOME)/bin/mxmlc
MXMLC_OPTIONS = -use-network \
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
	$(RM) -r $(DEST)

ext/as3corelib/bin/as3corelib.swc:
	git submodule init
	git submodule update
	ant -f ext/as3corelib/build/build.xml

# Since mxmlc is not part of standard Axis environment,
# only build SWF if target triggered explicitly
$(SWF): $(shell find $(SRC) -type f -name '*.as') ext/as3corelib/bin/as3corelib.swc
	@mkdir -p $(DEST)
	$(MXMLC) $(MXMLC_OPTIONS) $(MAIN_AS_FILE)
