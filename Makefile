include $(AXIS_TOP_DIR)/tools/build/Rules.axis

SRC = MJPGPlayer.as
DEST = bin
SWF = $(DEST)/Player.swf
MXMLC = mxmlc
MXMLC_OPTIONS = -use-network \
		-static-link-runtime-shared-libraries=true \
		-use-resource-bundle-metadata \
		-accessible=false \
		-allow-source-path-overlap=false \
		-target-player=11.1 \
		-locale en_US \
		-output $(SWF)
		-debug=false \
		-benchmark=false \
		-verbose-stacktraces=false \
		-omit-trace-statements \
		-strict \
		-warnings \
		-show-unused-type-selector-warnings \
		-show-actionscript-warnings \
		-show-binding-warnings \
		-show-invalid-css-property-warnings \
		-incremental=false \
		-es=false \
		-optimize \
	        -compress

all:

install: all

clean:
	$(RM) $(DEST)

# Since mxmlc is not part of standard Axis environment,
# only build SWF if target triggered explicitly
$(SWF): $(shell find com -type f) $(SRC)
	@mkdir -p $(DEST)
	$(MXMLC) $(MXMLC_OPTIONS) $(SRC)
