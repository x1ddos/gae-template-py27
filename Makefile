SHELL:=/bin/bash

# Assuming all make commands will be run from where this Makefile is,
# i.e. from the app root

# These are useful for overriding too.
# Application ID, default is to take whatever's in app.yaml
APP_ID        := `grep 'application: ' app.yaml | sed s'/application: //'`
# Used with MsgExtractor and Closure Compiler i18n
PROJECT_NAME  := notepad
# Which namespaces we'll need to calculate deps.js on
JS_NAMESPACES   := notepad.start

# HTML (Jinaj2) templates basedir
TEMPLATES_DIR := templates
# "static" assets
ASSETS_DIR    := assets
# Base dir for Stylesheets
ASSETS_CSS    := $(ASSETS_DIR)/css
# Base dir for Javascript files
ASSETS_JS     := $(ASSETS_DIR)/js

# Compiled output of all *.gss
CSS_COMPILED  := $(ASSETS_CSS)/compiled.css
CSS_DEBUG     := $(ASSETS_CSS)/compiled_debug.css
# Compiled Javascripts (with advanced optimisations)
JS_OUT        := $(ASSETS_JS)/compiled.js

# dependencies / other generated stuff
JS_DEPSFILE     := $(ASSETS_JS)/deps.js
CSSMAP_DEBUG_JS := $(ASSETS_JS)/cssmap_debug.js
CSSMAP_JS       := $(ASSETS_JS)/cssmap_compiled.js
CSSMAP_JSON     := $(ASSETS_JS)/cssmap.json

# dev/build templates and assets locations
# dev dirs are renamed to .*-dev when we're 'ready for production' 
# built dirs are renamted to .*-build when in normal, development state. 
ASSETS_DEV    := .assets-dev
ASSETS_BUILD  := .assets-build
TEMPL_DEV     := .templ-dev
TEMPL_BUILD   := .templ-build

# All python modules that are not test cases
NONTESTS := `find handlers models lib -name [a-z]\*.py ! -name \*_test.py`

# Temp dir for dev appengine server for stuff like db.sqlite and blobs
TMP_DIR       := tmp


# vitualenv dir. Don't use a .venv within the app dir 
# as it's being ignored by app.yaml/skip_files
VENV_DIR      := ~/.venv/my-gae-template
PYTHON        := $(VENV_DIR)/bin/python
BABEL         := $(VENV_DIR)/bin/pybabel
COVERAGE      := $(VENV_DIR)/bin/coverage
# Only needed for Closure stuff
JAVA          := `which java`

GAE_SDK       := /usr/local/google_appengine
PORT          := 8080

# Clousure Library dir.
# If you change this, modify app.yaml/skip_files too
CLOSURE_LIB   := $(ASSETS_DIR)/js/closure-lib

# Locations of Closure tools (app-root related)
# *.py and other stuff usually comes from 
# CLOSURE_LIB/closure/bin/build
CLOSURE_DEPSWRITER      := $(CLOSURE_LIB)/closure/bin/build/depswriter.py
CLOSURE_BUIDLER         := $(CLOSURE_LIB)/closure/bin/build/closurebuilder.py
CLOSURE_COMPILER_JAR    := ~/src/closure/compiler/build/compiler.jar
# CSS/GSS stuff
CLOSURE_STYLESHEETS_JAR := ~/src/closure/stylesheets/build/closure-stylesheets.jar
# Soy
SOY_TO_JS_JAR           := ~/src/closure/templates/build/SoyToJsSrcCompiler.jar
#SOY_MSG_EXTRACTOR       := ~/src/closure/templates/build/SoyMsgExtractor.jar

# templates/assets assembler
ASSETASM               := tools/assetasm.py
ASSETASM_IGNORE        := $(ASSETS_JS)/notepad

# Arguments for closurebuilder.py, assetasm.py (make templ|asset)
# and Closure Stylesheets renaming map ()
OUTPUT_MODE := compiled

# Current locale in use with Babel and MsgExtractor
LOCALE=

# Additional flags to compiler.jar or any other make target.
# e.g. "--use_types_for_optimization --output_wrapper=\"(function(){%output%})();\" ..."
FLAGS=

# Version to deploy on production. A better use is
# make deploy VER=myver
VER=


default: help

help:
	@echo
	@echo "Use 'make <target>' where <target> is one of"
	@echo
	@echo "  (t)est      to run unit testing. For a single module test use this:"
	@echo "              make t MOD=mod_name"
	@echo "  (cov)erage  to make test coverage report"
	@echo "  (s)erve     to start the app on development server"
	@echo "  (r)emote    to run Remote API shell"
	@echo
	@echo "  bootstrap   to generate virtualenv in $(VENV) (ONCE, at the very beginning) "
	@echo "              and install needed packages from requirements.txt"
	@echo
	@echo "  all-dev     After bootstrap and installing Closure Tools "
	@echo "  all-prod    (see Makefile vars for customizing paths) it is wise "
	@echo "              to check that at least minimum of the stack works"
	@echo
	@echo "  == i18n and Babel"
	@echo
	@echo "  1. babel_extract                     - extracts all translactions according to babel.cfg"
	@echo "  2. babel_init LOCALE=<your_locale>   - inits messages.pot (ONCE per language)"
	@echo "  3. translate locale/<lang>/LC_MESSAGES/messages.po"
	@echo "  4. babel_compile                     - compiles all translations"
	@echo "  - iterate: "
	@echo "    * repeat step 1."
	@echo "    * run 'make babel_update LOCALE=<your_locale>'"
	@echo "    * repeat step 3 and 4"
	@echo
	@echo "  == Closure-related stuff"
	@echo 
	@echo "  css-debug        to compile *.gss into $(CSS_DEBUG_OUT)"
	@echo "  css-compiled     to compile and minify *.gss (with classes renaming)"
	@echo "                   into $(CSS_OUT)"
	@echo "  css-map          creates renaming map in JSON format."
	@echo "                   Customize which files and how to compile with e.g."
	@echo "                   GSS_FILES=style.gss FLAGS=--rename DEBUG"
	@echo "  jsdeps           to generate $(ASSETS_JS)/deps.js"
	@echo "  (js)compile      to compile JS assets into $(ASSETS_JS)/$(JS_OUT)"
	@echo "                   OUTPUT_MODE=list to list dependencies"
	@echo "                   LOCALE=xx to compile with i18n"
	@echo "  js_extract_msg LOCALE=xx  "
	@echo "                   to extract goog.getMsg() in XTB format > locale/messages.xtb"
	@echo "  soy              to compile Soy templates. Override files to compile"
	@echo "                   with SOY_FILES=..."
	@echo
	@echo "  == Deployment-related stuff"
	@echo
	@echo "  templ       to assemble templates/*.html with tools/assetasm.py"
	@echo "  assets      to assemble assets/*"
	@echo "              Note take assetasm.py will also invoke assets "
	@echo "              building when run with 'make templ'"
	@echo
	@echo "  Alternative output for templ and assets targets works with"
	@echo "  OUTPUT_MODE={manifest|check}"
	@echo
	@echo "  deploy      to deploy the app on production servers."
	@echo "              You could do make deploy VER=myver FLAGS=-v"
	@echo "  2prod       will switch to production (build) version of assets"
	@echo "              and templates"
	@echo "  2dev        will switch to development version of assets"
	@echo "              and templates"
	@echo "  clean       removes .pyc, htmlcov, .coverage and CSS/JS compiled"
	@echo "              stuff"
	@echo "  clean-all   will also remove last assets and templates build"
	@echo
	@echo "You can always use FLAGS='--whatever' as addition arguments to any target."
	@echo
	@echo "To activate this virtualenv:"
	@echo ">> source $(VENV_DIR)/bin/activate"
	@echo

MOD=
ifeq ($(strip $(MOD)),)
	TESTCMD := @PYTHONPATH=.:$(PYTHONPATH) $(PYTHON) tests_runner.py $(FLAGS)
else
	TESTCMD := @PYTHONPATH=.:$(PYTHONPATH) $(PYTHON) -m tests.$(MOD) $(FLAGS)
endif
t test:
	$(TESTCMD)

cov coverage:
	$(COVERAGE) run tests_runner.py $(FLAGS)
	@echo
	@$(COVERAGE) html $(NONTESTS)
	@$(COVERAGE) report -m $(NONTESTS)
	@echo
	@echo ">>> open htmlcov/index.html"
	@echo

s serve:
	@mkdir -p $(TMP_DIR)/blobs
	@PYTHONPATH=.:$(PYTHONPATH) $(PYTHON) $(GAE_SDK)/dev_appserver.py . \
		--port $(PORT) \
		--blobstore_path=$(TMP_DIR)/blobs \
		--use_sqlite \
		--datastore_path=$(TMP_DIR)/db.sqlite \
		--high_replication \
		--require_indexes \
		--disable_static_caching \
		--skip_sdk_update_check \
		$(FLAGS)

HOST=$(APP_ID).appspot.com
r remote:
	@echo "Connecting to $(HOST) ..."
	@$(PYTHON) $(GAE_SDK)/remote_api_shell.py --secure -s $(HOST) $(FLAGS)

#
# GSS/CSS stuff
#

CLOSURE_STYLESHEETS_CMD := $(JAVA) -jar $(CLOSURE_STYLESHEETS_JAR)
GSS_FILES := $(wildcard $(ASSETS_CSS)/*.gss)

# override with make css-debug FLAGS="--rename DEBUG"
_compile_gss:
	$(CLOSURE_STYLESHEETS_CMD) \
		--output-renaming-map $(CSSMAP_OUT) \
		--output-renaming-map-format $(CSSMAP_FORMAT) \
		$(_args) $(FLAGS) $(GSS_FILES) > $(CSS_OUT)

css-debug: CSS_OUT = $(CSS_DEBUG)
css-debug: CSSMAP_FORMAT = CLOSURE_UNCOMPILED
css-debug: CSSMAP_OUT = $(CSSMAP_DEBUG_JS)
css-debug: _args = --pretty-print --rename NONE
css-debug: _compile_gss

css-compiled: CSS_OUT = $(CSS_COMPILED)
css-compiled: CSSMAP_FORMAT = CLOSURE_COMPILED
css-compiled: CSSMAP_OUT = $(CSSMAP_JS)
css-compiled: _args = --rename CLOSURE
css-compiled: _compile_gss

css-map: CSS_OUT = $(CSS_COMPILED)
css-map: CSSMAP_FORMAT = JSON
css-map: CSSMAP_OUT = $(CSSMAP_JSON)
css-map: _args = --rename CLOSURE
css-map: _compile_gss

#
# Closure lib / JS stuff
#

# Args for jsdeps (depswriter.py)
# JS_ROOTS_WITH_PREFIXES = $(foreach jsdir, $(JS_SRCDIRS), --root_with_prefix="$(ASSETS_JS)/$(jsdir) ../../../$(jsdir)")
# If you want to use the above, uncomment JS_SRCDIRS and 
# replace --root_with_prefix with $(JS_ROOTS_WITH_PREFIXES) below
jsdeps:
	$(PYTHON) $(CLOSURE_DEPSWRITER) $(FLAGS) \
		--root_with_prefix="$(ASSETS_JS)/ ../../../" \
		> $(JS_DEPSFILE)


# Real arguments for closure compiler
JSCOMP_FLAGS := $(FLAGS) --warning_level=VERBOSE
JSCOMP_FLAGS += --compilation_level=ADVANCED_OPTIMIZATIONS
JSCOMP_FLAGS += --define=goog.DEBUG=false
JSCOMP_FLAGS += --summary_detail_level=3
JSCOMP_FLAGS += --js $(CSSMAP_JS)

# If you want to have a finer-grained control, 
# see jsdeps target and JS_SRCDIRS description
#CLOSURE_BUILDER_ARGS += $(addprefix --root=$(ASSETS_JS)/,$(JS_SRCDIRS))
CLOSURE_BUILDER_ARGS := --root=$(CLOSURE_LIB)
CLOSURE_BUILDER_ARGS += --root=$(ASSETS_JS)
CLOSURE_BUILDER_ARGS += $(addprefix -n ,$(JS_NAMESPACES))
CLOSURE_BUILDER_ARGS += -c $(CLOSURE_COMPILER_JAR)
CLOSURE_BUILDER_ARGS += $(JSCOMP_FLAGS:%=-f "%")

CLOSURE_BUILDER_CMD  := $(CLOSURE_BUIDLER) $(CLOSURE_BUILDER_ARGS)

ifeq ($(strip $(OUTPUT_MODE)), list)
	CLOSURE_BUILDER_CMD += -o $(OUTPUT_MODE)
else
	CLOSURE_BUILDER_CMD += -o $(OUTPUT_MODE) > $(JS_OUT)
endif

# For localization use something like 
# make js LOCALE=it
ifneq ($(strip $(LOCALE)),)
	CLOSURE_BUILDER_CMD += -f "--translations_file=locale/$(LOCALE)/LC_MESSAGES/messages.xtb"
	CLOSURE_BUILDER_CMD += -f "--translations_project=$(PROJECT_NAME)"
	CLOSURE_BUILDER_CMD += -f "--define=goog.LOCALE='$(LOCALE)'"
endif
# make js FLAGS="--formatting PRETTY_PRINT"
js jscompile:
	$(PYTHON) $(CLOSURE_BUILDER_CMD)

#
# Soy templates
#

SOY_FILES      := $(wildcard $(TEMPLATES_DIR)/soy/*.soy)
SOY_TO_JS_ARGS :=  --outputPathFormat $(ASSETS_JS)/{INPUT_FILE_NAME_NO_EXT}/soy.js
SOY_TO_JS_ARGS += --shouldGenerateJsdoc
SOY_TO_JS_ARGS += --shouldProvideRequireSoyNamespaces
SOY_TO_JS_ARGS += --shouldGenerateGoogMsgDefs
SOY_TO_JS_ARGS += --cssHandlingScheme GOOG
SOY_TO_JS_ARGS += --bidiGlobalDir 1
soy:
	@echo Compitling these Soy templates: $(SOY_FILES)
	$(JAVA) -jar $(SOY_TO_JS_JAR) $(SOY_TO_JS_ARGS) $(FLAGS) $(SOY_FILES)

#
# i18n / Babel targets
#

LOCALE_DIR := locale
_ensure_locale_dir:
	@mkdir -p $(LOCALE_DIR)

XTB_MESSAGES_POT := $(LOCALE_DIR)/messages.xtb
js_extract_msg: _ensure_locale_dir
	$(CLOSURE_BUIDLER) $(CLOSURE_BUILDER_ARGS) -o list > /tmp/jsfiles.txt

	@echo '<?xml version="1.0" ?>' > $(XTB_MESSAGES_POT)
  #@echo '<\!DOCTYPE translationbundle>' >> $(XTB_MESSAGES_POT)
	@echo "<translationbundle lang=\"$(LOCALE)\">" >> $(XTB_MESSAGES_POT)
	for i in `cat /tmp/jsfiles.txt`; do \
		java -cp $(CLOSURE_COMPILER_JAR):./tools MsgExtractor $(PROJECT_NAME) $$i; \
	done >> $(XTB_MESSAGES_POT)
	@echo "</translationbundle>" >> $(XTB_MESSAGES_POT)
	@mkdir -p $(LOCALE_DIR)/$(LOCALE)/LC_MESSAGES
	@cp $(XTB_MESSAGES_POT) $(LOCALE_DIR)/$(LOCALE)/LC_MESSAGES/

babel_extract: _ensure_locale_dir
	$(BABEL) extract -k _T -F babel.cfg -o $(LOCALE_DIR)/messages.pot .

babel_init:
	$(BABEL) init -l $(LOCALE) -d $(LOCALE_DIR) -i $(LOCALE_DIR)/messages.pot

babel_compile:
	$(BABEL) compile -f -d $(LOCALE_DIR)

babel_update:
	$(BABEL) update -l $(LOCALE) -d $(LOCALE_DIR) -i $(LOCALE_DIR)/messages.pot

#
# Dev/production(build) state switching
#

DEV_MARKER := .dev
ASSETS_IN_DEV := $(shell test -f $(ASSETS_DIR)/$(DEV_MARKER) && echo 1)
TEMPL_IN_DEV := $(shell test -f $(TEMPLATES_DIR)/$(DEV_MARKER) && echo 1)

_assets2dev:
	@if [ -z $(ASSETS_IN_DEV) ]; \
		then mv $(ASSETS_DIR) $(ASSETS_BUILD) && mv $(ASSETS_DEV) $(ASSETS_DIR); \
	fi

_assets2prod:
	@if [ -n $(ASSETS_IN_DEV) ]; \
		then mkdir -p $(ASSETS_BUILD); \
		mv $(ASSETS_DIR) $(ASSETS_DEV) && mv $(ASSETS_BUILD) $(ASSETS_DIR); \
	fi

_templ2dev:
	@if [ -z $(TEMPL_IN_DEV) ]; \
		then mv $(TEMPLATES_DIR) $(TEMPL_BUILD) && mv $(TEMPL_DEV) $(TEMPLATES_DIR); \
	fi

_templ2prod:
	@if [ -n $(TEMPL_IN_DEV) ]; \
		then mkdir -p $(TEMPL_BUILD); \
		mv $(TEMPLATES_DIR) $(TEMPL_DEV) && mv $(TEMPL_BUILD) $(TEMPLATES_DIR); \
	fi

2dev: _assets2dev _templ2dev
2prod: _assets2prod _templ2prod

#
# Templates and assets assembling
#

ASSETASM_ARGS := $(ASSETASM_IGNORE:%=--ignore '%')
ASSETASM_ARGS += --ignore $(CSSMAP_JS)
OUTPUT_MODE   := build

assets: 2dev
	$(PYTHON) $(ASSETASM)  $(ASSETASM_ARGS) \
		--static-src $(ASSETS_DIR) \
		--static-dst $(ASSETS_BUILD) \
		$(FLAGS) static $(OUTPUT_MODE)

templ: 2dev
	$(PYTHON) $(ASSETASM) $(ASSETASM_ARGS) \
		--static-src $(ASSETS_DIR) \
		--static-dst $(ASSETS_BUILD) \
		--templates-src $(TEMPLATES_DIR) \
		--templates-dst $(TEMPL_BUILD) \
		--compiler-jar $(CLOSURE_COMPILER_JAR) \
		--cssmap $(CSSMAP_JSON) \
		$(FLAGS) templates $(OUTPUT_MODE) 

#
# Deployment
#

deploy: 2prod
	@echo "Deploying to $(APP_ID).appspot.com as version [$(VER)]"
	@$(PYTHON) $(GAE_SDK)/appcfg.py -A $(APP_ID) -V $(VER) \
		--oauth2 $(FLAGS) \
	  update .

#
# Cleanup
#

# Files to clean up
GENERATED_FILES := htmlcov .coverage 
GENERATED_FILES += $(JS_OUT) $(JS_DEPSFILE)
GENERATED_FILES += $(CSSMAP_JS) $(CSSMAP_DEBUG_JS) $(CSSMAP_JSON) 
GENERATED_FILES += $(CSS_DEBUG) $(CSS_COMPILED)

clean: 2dev
	rm -rf $(GENERATED_FILES)
	rm -f `find . -name \*.pyc -o -name \*~ -o -name @\* -o -name \*.orig -o -name \*.rej -o -name \#*\#`
	rm -f `find $(ASSETS_DIR) -name soy.js`

# removes dirs generated by assetasm.py
clean-asm: 2dev
	rm -rf $(ASSETS_BUILD) $(TEMPL_BUILD)

clean-all: clean clean-asm
	

# This target is here for testing minimum set of dependencies
# dev
all-dev: 2dev soy jsdeps css-debug 
# build / production
all-prod: 2dev soy css-compiled js
	make css-map 
	make templ 
	make test 
	make 2prod


#
# Bootstrapping 
#

override define GAECUSTOMIZE
def fix_sys_path():
  try:
    import sys, os
    from dev_appserver import fix_sys_path, DIR_PATH
    fix_sys_path()
    # must be after fix_sys_path
    # uses non-default version of webob
    #webob_path = os.path.join(DIR_PATH, 'lib', 'webob_1_1_1')
    #sys.path = [webob_path] + sys.path
  except ImportError:
    pass
endef
override define GAEPTH
$(GAE_SDK)
import gaecustomize; gaecustomize.fix_sys_path()
endef

export GAECUSTOMIZE
export GAEPTH

# a dir where py packages live
EXT_DIR=ext

# additional flags to pip install -r requirements.txt
# e.g. --timeout=30
PIP_FLAGS=

# Creates new virtualenv in VENV_DIR
# http://schettino72.wordpress.com/2010/11/21/appengine-virtualenv/
bootstrap:
	@cp -v conf/secrets.py.templ conf/secrets.py

	virtualenv --python python2.7 $(VENV_DIR)
	@echo "$$GAECUSTOMIZE" > $(VENV_DIR)/lib/python2.7/site-packages/gaecustomize.py
	@echo "$$GAEPTH" > $(VENV_DIR)/lib/python2.7/site-packages/gae.pth
	@echo
	$(VENV_DIR)/bin/pip install -r requirements.txt $(PIP_FLAGS)

	@mkdir -p $(EXT_DIR)
	cp -r $(VENV_DIR)/lib/python2.7/site-packages/babel $(EXT_DIR)/
	cp -r $(VENV_DIR)/lib/python2.7/site-packages/pytz $(EXT_DIR)/

	@rm -rf $(EXT_DIR)/babel/localedata/*
	@cp -v $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/en.dat $(EXT_DIR)/babel/localedata/
	@cp -v $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/en_US.dat $(EXT_DIR)/babel/localedata/

	@echo ">>> copy from $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/ "
	@echo "    locales that you need into $(EXT_DIR)/babel/localedata/"
	@echo "    en.dat and en_US.dat are already there."

	@echo ">>> source $(VENV_DIR)/bin/activate"
	@echo ">>> Don't forget to install Closure Tools and adjust paths vars in this Makefile"
