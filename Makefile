SHELL:=/bin/bash

# Assuming all make commands will be run from where this Makefile is,
# i.e. from the app root

# vitualenv dir
VENV_DIR      = ~/.venv/my-gae-template
PYTHON        = $(VENV_DIR)/bin/python
BABEL         = $(VENV_DIR)/bin/pybabel
COVERAGE      = $(VENV_DIR)/bin/coverage
JAVA          = `which java`

# These are useful for overriding too.
# Application ID
APP_ID        = `grep 'application: ' app.yaml | sed s'/application: //'`
# Version to deploy on production
VER=
# All python modules that are not test cases
NONTESTS=`find handlers models lib -name [a-z]\*.py ! -name \*_test.py`

# Additional flags to compiler.jar
CLOSURE_COMPILER_FLAGS=

# Temp dir for dev appengine server for stuff like db.sqlite and blobs
TMP_DIR       = tmp

# Base dir for Javascript files
ASSETS_JS     = assets/js

# Base dir for Stylesheets
ASSETS_CSS    = assets/css

# Compiled output of all *.gss
CSS_OUT       = compiled.css

# Compiled Javascripts (with advanced optimisations)
JS_OUT        = compiled.js


JS_SRCDIRS    = dir1 dir2
JS_NAMESPACES = app.start
JS_DEPSFILE   = deps.js
CLOSURE_LIB   = closure/

GAE_SDK       = /usr/local/google_appengine
PORT          = 8080

# Javascript stuff and Closure builder/compiler
CLOSURE_DEPSWRITER     = tools/compiler/depswriter.py
CLOSURE_BUIDLER        = tools/compiler/closurebuilder.py
CLOSURE_COMPILER_JAR   = tools/compiler/compiler.jar

JSCOMP_FLAGS := $(CLOSURE_COMPILER_FLAGS) --warning_level=VERBOSE
JSCOMP_FLAGS += --compilation_level=ADVANCED_OPTIMIZATIONS
JSCOMP_FLAGS += --define=goog.DEBUG=false
JSCOMP_FLAGS += --summary_detail_level=3
#JSCOMP_FLAGS += --use_types_for_optimization
#JSCOMP_FLAGS += --output_wrapper="(function(){%output%})();"

CLOSURE_BUILDER_ARGS =  --root=$(ASSETS_JS)/$(CLOSURE_LIB)
CLOSURE_BUILDER_ARGS += $(addprefix --root=$(ASSETS_JS)/,$(JS_SRCDIRS))
CLOSURE_BUILDER_ARGS += $(addprefix -n ,$(JS_NAMESPACES))
CLOSURE_BUILDER_ARGS += -o compiled
CLOSURE_BUILDER_ARGS += -c $(CLOSURE_COMPILER_JAR)
CLOSURE_BUILDER_ARGS += $(JSCOMP_FLAGS:%=-f "%")
#CLOSURE_BUILDER_ARGS += -f "$(CLOSURE_COMPILER_FLAGS)"

# CSS/GSS stuff
CLOSURE_STYLESHEETS_JAR = tools/closure-stylesheets.jar

# Additional flags to any make <target>'s underlying command.
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
	@echo "  deploy      to deploy the app on production servers"
	@echo
	@echo "  bootstrap   to generate virtualenv in $(VENV) (ONCE, at the very beginning) "
	@echo "              and install needed packages from requirements.txt"
	@echo
	@echo "  == Babel and i18n"
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
	@echo "You can always use FLAGS='--whatever' as addition arguments to any target."


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

css:
	$(JAVA) -jar $(CLOSURE_STYLESHEETS_JAR) $(ASSETS_CSS)/*.gss $(FLAGS) \
		> $(ASSETS_CSS)/$(CSS_OUT)

jsdeps:
	$(PYTHON) $(CLOSURE_DEPSWRITER) $(FLAGS) \
		--root_with_prefix="assets/js/notepad/ ../../../notepad" \
		> $(ASSETS_JS)/$(JS_DEPSFILE)

js jscompile:
	$(PYTHON) $(CLOSURE_BUIDLER) $(CLOSURE_BUILDER_ARGS) $(FLAGS) \
		> $(ASSETS_JS)/$(JS_OUT)


GENERATED_FILES =  $(ASSETS_JS)/$(JS_DEPSFILE)
GENERATED_FILES +=  $(ASSETS_JS)/$(JS_OUT)
GENERATED_FILES += $(ASSETS_CSS)/$(CSS_OUT)

clean:
	rm -rf htmlcov .coverage
	rm -f  $(GENERATED_FILES)
	rm -f `find . -name \*.pyc -o -name \*~ -o -name @\* -o -name \*.orig -o -name \*.rej -o -name \#*\#`

# Locales management with Babel
LOCALE=

babel_extract:
	@mkdir -p locale
	$(BABEL) extract -k _T -F babel.cfg -o locale/messages.pot .

babel_init:
	$(BABEL) init -l $(LOCALE) -d locale -i locale/messages.pot

babel_compile:
	$(BABEL) compile -f -d locale

babel_update:
	$(BABEL) update -l $(LOCALE) -d locale -i locale/messages.pot


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
