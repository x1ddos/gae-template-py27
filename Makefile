SHELL:=/bin/bash

# Assuming all make commands will be run from where this Makefile is,
# i.e. from the app root

# vitualenv dir. Don't use a .venv within the app dir 
# as it's being ignored by app.yaml/skip_files
VENV_DIR      = ~/.venv/my-gae-template
PYTHON        = $(VENV_DIR)/bin/python
BABEL         = $(VENV_DIR)/bin/pybabel
COVERAGE      = $(VENV_DIR)/bin/coverage
# Only needed for Closure stuff
JAVA          = `which java`

GAE_SDK       = /usr/local/google_appengine
PORT          = 8080
# Temp dir for dev appengine server for stuff like db.sqlite and blobs
TMP_DIR       = tmp

# These are useful for overriding too.
# Application ID, default is to take whatever's in app.yaml
APP_ID        = `grep 'application: ' app.yaml | sed s'/application: //'`
# Version to deploy on production. A better use is
# make deploy VER=myver
VER=
# Used with MsgExtractor and Closure compiler i18n
PROJECT_NAME  = notepad

# All python modules that are not test cases
NONTESTS=`find handlers models lib -name [a-z]\*.py ! -name \*_test.py`

# "static" assets

# Base dir for Stylesheets
ASSETS_CSS    = assets/css
# Compiled output of all *.gss
CSS_OUT       = compiled.css

# Base dir for Javascript files
ASSETS_JS     = assets/js
# Compiled Javascripts (with advanced optimisations)
JS_OUT        = compiled.js

# Javascript source dirs, space-separated.
# These are closure-like namespaced JS (goog.provide/require)
# If you want to have a finer-grained control, 
# see comments above jsdeps target
# JS_SRCDIRS    = notepad

# Which namespaces we'll need to calculate deps.js on
JS_NAMESPACES = notepad.start
JS_DEPSFILE   = deps.js
# related to app root.
# If you change this, modify app.yaml/skip_files too
CLOSURE_LIB   = assets/js/closure-lib

# Javascript stuff and Closure builder/compiler

# Locations of Closure tools (app-root related)
# *.py and other stuff usually comes from 
# CLOSURE_LIB/closure/bin/build
CLOSURE_DEPSWRITER     = $(CLOSURE_LIB)/closure/bin/build/depswriter.py
CLOSURE_BUIDLER        = $(CLOSURE_LIB)/closure/bin/build/closurebuilder.py
CLOSURE_COMPILER_JAR   = ~/src/closure/compiler/build/compiler.jar
# CSS/GSS stuff
CLOSURE_STYLESHEETS_JAR = ~/src/closure/stylesheets/build/closure-stylesheets.jar
# Soy
SOY_TO_JS_JAR           = ~/src/closure/templates/build/SoyToJsSrcCompiler.jar
#SOY_MSG_EXTRACTOR       = ~/src/closure/templates/build/SoyMsgExtractor.jar

# Current locale in use with Babel and MsgExtractor
LOCALE=

# Additional flags to compiler.jar or any other make target.
# e.g. "--use_types_for_optimization --output_wrapper=\"(function(){%output%})();\" ..."
FLAGS=


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
	@echo "  css              to compile assets/css/*.gss into $(ASSETS_CSS)/$(CSS_OUT)"
	@echo "  jsdeps           to generate $(ASSETS_JS)/deps.js"
	@echo "  (js)compile      to compile JS assets into $(ASSETS_JS)/$(JS_OUT)"
	@echo "  js_extract_msg LOCALE=xx  to extract goog.getMsg() in XTB format > locale/messages.xtb"
	@echo "  soy2js           to compile Soy templates"
	@echo
	@echo "  == Deployment-related stuff"
	@echo
	@echo "  deploy      to deploy the app on production servers. You could do"
	@echo "              make deploy VER=myver FLAGS=-v"
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
	@PYTHONPATH=.:$(PYTHONPATH) $(PYTHON) $(GAE_SDK)/dev_appserver.py . --port $(PORT) $(FLAGS) \
		--blobstore_path=$(TMP_DIR)/blobs \
		--use_sqlite \
		--datastore_path=$(TMP_DIR)/db.sqlite \
		--high_replication \
		--require_indexes \
		--disable_static_caching \
		--skip_sdk_update_check

deploy:
	@echo "Deploying to $(APP_ID).appspot.com as version [$(VER)]"
	@$(PYTHON) $(GAE_SDK)/appcfg.py -A $(APP_ID) -V $(VER) \
		--oauth2 \
	  $(FLAGS) update .

HOST=$(APP_ID).appspot.com
r remote:
	@echo "Connecting to $(HOST) ..."
	@$(PYTHON) $(GAE_SDK)/remote_api_shell.py --secure -s $(HOST) $(FLAGS)

# GSS/CSS stuff

css:
	$(JAVA) -jar $(CLOSURE_STYLESHEETS_JAR) $(ASSETS_CSS)/*.gss $(FLAGS) \
		> $(ASSETS_CSS)/$(CSS_OUT)


# Closure lib / JS stuff

# Args for jsdeps (depswriter.py)
# JS_ROOTS_WITH_PREFIXES = $(foreach jsdir, $(JS_SRCDIRS), --root_with_prefix="$(ASSETS_JS)/$(jsdir) ../../../$(jsdir)")
# If you want to use the above, uncomment JS_SRCDIRS and 
# replace --root_with_prefix with $(JS_ROOTS_WITH_PREFIXES) below
jsdeps:
	$(PYTHON) $(CLOSURE_DEPSWRITER) $(FLAGS) \
		--root_with_prefix="$(ASSETS_JS)/ ../../../" \
		> $(ASSETS_JS)/$(JS_DEPSFILE)


# Real arguments for closure compiler
JSCOMP_FLAGS := $(FLAGS) --warning_level=VERBOSE
JSCOMP_FLAGS += --compilation_level=ADVANCED_OPTIMIZATIONS
JSCOMP_FLAGS += --define=goog.DEBUG=false
JSCOMP_FLAGS += --summary_detail_level=3

# Arguments for closurebuilder.py
OUTPUT_MODE = compiled
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
	CLOSURE_BUILDER_CMD += -o $(OUTPUT_MODE) > $(ASSETS_JS)/$(JS_OUT)
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

XTB_MESSAGES_POT=locale/messages.xtb
js_extract_msg:
	$(CLOSURE_BUIDLER) $(CLOSURE_BUILDER_ARGS) -o list > /tmp/jsfiles.txt

	@echo '<?xml version="1.0" ?>' > $(XTB_MESSAGES_POT)
  #@echo '<\!DOCTYPE translationbundle>' >> $(XTB_MESSAGES_POT)
	@echo "<translationbundle lang=\"$(LOCALE)\">" >> $(XTB_MESSAGES_POT)
	for i in `cat /tmp/jsfiles.txt`; do \
		java -cp $(CLOSURE_COMPILER_JAR):./tools MsgExtractor $(PROJECT_NAME) $$i; \
	done >> $(XTB_MESSAGES_POT)
	@echo "</translationbundle>" >> $(XTB_MESSAGES_POT)


SOY_FILES      = $(wildcard templates/soy/*.soy)
SOY_TO_JS_ARGS =  --outputPathFormat $(ASSETS_JS)/{INPUT_FILE_NAME_NO_EXT}/soy.js
SOY_TO_JS_ARGS += --shouldGenerateJsdoc
SOY_TO_JS_ARGS += --shouldProvideRequireSoyNamespaces
SOY_TO_JS_ARGS += --shouldGenerateGoogMsgDefs
SOY_TO_JS_ARGS += --bidiGlobalDir 1
soy2js:
	@echo Compitling these Soy templates: $(SOY_FILES)
	$(JAVA) -jar $(SOY_TO_JS_JAR) $(SOY_TO_JS_ARGS) $(FLAGS) $(SOY_FILES)

# Babel targets

babel_extract:
	@mkdir -p locale
	$(BABEL) extract -k _T -F babel.cfg -o locale/messages.pot .

babel_init:
	$(BABEL) init -l $(LOCALE) -d locale -i locale/messages.pot

babel_compile:
	$(BABEL) compile -f -d locale

babel_update:
	$(BABEL) update -l $(LOCALE) -d locale -i locale/messages.pot

# Files to clean up
GENERATED_FILES =  $(ASSETS_JS)/$(JS_DEPSFILE)
GENERATED_FILES +=  $(ASSETS_JS)/$(JS_OUT)
GENERATED_FILES += $(ASSETS_CSS)/$(CSS_OUT)

clean:
	rm -rf htmlcov .coverage
	rm -f  $(GENERATED_FILES)
	rm -f `find . -name \*.pyc -o -name \*~ -o -name @\* -o -name \*.orig -o -name \*.rej -o -name \#*\#`


# Bootstrapping 

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

# Creates new virtualenv in VENV_DIR
# http://schettino72.wordpress.com/2010/11/21/appengine-virtualenv/
EXT_DIR=ext
bootstrap:
	@cp -v conf/secrets.py.templ conf/secrets.py

	virtualenv --python python2.7 $(VENV_DIR)
	@echo "$$GAECUSTOMIZE" > $(VENV_DIR)/lib/python2.7/site-packages/gaecustomize.py
	@echo "$$GAEPTH" > $(VENV_DIR)/lib/python2.7/site-packages/gae.pth
	@echo
	$(VENV_DIR)/bin/pip install -r requirements.txt

	@mkdir -p $(EXT_DIR)
	cp -r $(VENV_DIR)/lib/python2.7/site-packages/babel $(EXT_DIR)/
	cp -r $(VENV_DIR)/lib/python2.7/site-packages/pytz $(EXT_DIR)/

	@rm -rf lib/babel/localedata/*
	@cp -v $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/en.dat $(EXT_DIR)/babel/localedata/
	@cp -v $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/en_US.dat $(EXT_DIR)/babel/localedata/

	@echo ">>> copy from $(VENV_DIR)/lib/python2.7/site-packages/babel/localedata/ "
	@echo "    locales that you need into $(EXT_DIR)/babel/localedata/"
	@echo "    en.dat and en_US.dat are already there."

	@echo ">>> source $(VENV_DIR)/bin/activate"
