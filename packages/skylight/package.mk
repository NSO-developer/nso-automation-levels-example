# === Core =====================================================================

PACKAGE_MK_VERSION = 1.0.0-140-gfb60fc6

# Absolute path of this file, calculated from the list of included files.
PACKAGE_DIR_ABS := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PACKAGE_DIR     := $(PACKAGE_DIR_ABS)

# Relative path of this file (in relation to where make is run). This is used
# to make it possible to make individual targets relative to the current
# working directory, i.e. make load-dir/tailf.fxs or make ../load-dir/tailf.fxs,
# and to make ncsc happy since older versions doesn't like to long filenames.
#
# Getting the relative path is a five step algorithm:
#   1. Get the current directory (where make was run) and remove all spaces.
#   2. Remove the absolute path (of this file) prefix (without spaces). E.g.
#        '/home/guran/tailf'          -> ''
#        '/home/guran/tailf/test'     -> 'test'
#        '/home/guran/tailf/src/java' -> 'src/java'.
#   3. Substitute all / with a single space. E.g.
#        ''         -> ''
#        'test'     -> 'test'
#        'src/java' -> 'src java'.
#   4. For each element in the var (separated by space) map it to '../'. E.g.
#        ''         -> ''
#        'test'     -> '../'
#        'src java' -> '../ ../'.
#   5. Flatten the value of the variable by removing all spaces. E.g.
#        ''        -> ''
#        '../'     -> '../'
#        '../ ../' -> '../../'.
PACKAGE_DIR_REL := $(subst $(eval) ,,$(CUR_DIR))
PACKAGE_DIR_REL := $(CURDIR:$(subst $(eval) ,,$(PACKAGE_DIR_ABS))%=%)
PACKAGE_DIR_REL := $(subst /, ,$(PACKAGE_DIR_REL))
PACKAGE_DIR_REL := $(foreach a,$(PACKAGE_DIR_REL),../)
PACKAGE_DIR_REL := $(subst $(eval) ,,$(PACKAGE_DIR_REL))

ifeq ($(wildcard $(PACKAGE_DIR_ABS)/package-meta-data.xml),)
$(error Missing package-meta-data.xml in directory $(PACKAGE_DIR_ABS))
endif

# Knob to control the verbosity, set to a value between 0-2 where 2 is
# the most verbose.
V ?=0

verbose_0 := @
verbose_1 :=
verbose_2 := set -x;
VERBOSE   := $(verbose_$(V))

empty :=
space := $(empty) $(empty)
tab := $(empty)	$(empty)
comma := ,
define newline


endef

rel = $(subst /,,$(subst .,_,$(PACKAGE_DIR_REL)))

# --- Temp dir -----------------------------------------------------------------
# Temporary directory where package.mk can store stuff related to the build.
PACKAGE_MK_TMP ?= $(PACKAGE_DIR_ABS)/.package.mk
export PACKAGE_MK_TMP

ifeq ($(IS_DEP),)
PACKAGE_MK_TMP_LOCAL := $(PACKAGE_DIR_ABS)/.package.mk
else
PACKAGE_MK_TMP_LOCAL := $(PACKAGE_DIR_ABS)/.package.mk
endif

# --- Main rules ---------------------------------------------------------------
BUILD_OBJECTS += # Stuff that needs to be built

.PHONY: all build build-no-deps pre-build test clean pre-clean distclean pre-distclean

all: build

.SECONDEXPANSION:
build: deps pre-build $$(BUILD_OBJECTS)

build-no-deps: SKIP_DEPS = true
build-no-deps: pre-build $$(BUILD_OBJECTS)

pre-build:
	$(VERBOSE) $(call log,"Build $(PACKAGE_NAME)")

test: build test-deps

clean::
	$(VERBOSE) $(call log,"Clean $(PACKAGE_NAME)")
	$(VERBOSE) rm -rf $(BUILD_OBJECTS)

distclean:: clean
	$(VERBOSE) $(call log,"Clean \(dist\) $(PACKAGE_NAME)")
	$(VERBOSE) rm -rf $(PACKAGE_MK_TMP_LOCAL)

help:
	$(VERBOSE) printf "%s\n" \
		"Usage: [V=1] $(MAKE) [target]..." \
		"" \
		"Core targets:" \
		"  build         Fetch dependencies and build them, then build the package" \
		"  build-no-deps Build the package" \
		"  test          Run the tests for the package" \
		"  clean         Remove most output and temporary files" \
		"  distclean     Remove all output and temporary files" \
		"  deps          Fetch dependencies and build them" \
		"  doc           Build the documentation for the package" \
		"  release       Create a release tarball" \
		"  package-mk    Update package.mk" \
		"  lux-common    Update lux-common"

$(sort $(PACKAGE_MK_TMP) $(PACKAGE_MK_TMP_LOCAL)):
	$(VERBOSE) mkdir -p $@

# --- Metadata -----------------------------------------------------------------
PACKAGE_NAME    := $(shell xmllint --xpath "string(//*[local-name()='ncs-package']/*[local-name()='name'])" $(PACKAGE_DIR_ABS)/package-meta-data.xml)
PACKAGE_VERSION := $(shell xmllint --xpath "string(//*[local-name()='ncs-package']/*[local-name()='package-version'])" $(PACKAGE_DIR_ABS)/package-meta-data.xml)

GIT_HASH        := $(shell cd $(PACKAGE_DIR_ABS); git rev-parse HEAD 2>/dev/null || echo unknown)
GIT_HASH_SHORT  := $(shell cd $(PACKAGE_DIR_ABS); git log --pretty=format:'%h' -n 1 2>/dev/null || echo unknown)

ifeq ($(PACKAGE_NAME),)
$(error Missing package name in package-meta-data.xml)
endif
ifeq ($(PACKAGE_VERSION),)
$(error Missing package version in package-meta-data.xml)
endif

# --- Directories --------------------------------------------------------------

ERL_DIR       := $(PACKAGE_DIR_REL)erlang-lib
LOAD_DIR      := $(PACKAGE_DIR_REL)load-dir
JAVA_DIR      := $(PACKAGE_DIR_REL)src/java
NCSC_OUT_DIR  := $(PACKAGE_DIR_REL)src/ncsc-out
YANG_DIR      := $(PACKAGE_DIR_REL)src/yang
YANG_NED_DIR  := $(PACKAGE_DIR_REL)src/ned
TEMPLATES_DIR := $(PACKAGE_DIR_REL)templates
WEBUI_DIR     := $(PACKAGE_DIR_REL)webui
PYTHON_DIR    := $(PACKAGE_DIR_REL)python
PYTHON_UNITTEST_DIR := $(PACKAGE_DIR_REL)test/internal/pyunit
SHARED_JAR_DIR      := $(PACKAGE_DIR_REL)shared-jar
EXAMPLES_DIR        := $(PACKAGE_DIR_REL)examples

# --- Features -----------------------------------------------------------------
JAVA_ENABLED := $(if $(wildcard $(JAVA_DIR)/build.xml),true,false)

# --- OS -----------------------------------------------------------------------
OS := $(shell uname -s)

# === Utils ====================================================================
SHASUM := $(shell command -v shasum 2>/dev/null)

ifdef SHASUM
SHA512SUM      ?= $(SHASUM)
SHA512SUM_ARGS ?= -a 512
else
SHA512SUM      ?= $(shell command -v sha512sum 2>/dev/null)
SHA512SUM_ARGS ?=
endif

ifeq ($(OS),Darwin)
TAR ?= $(shell (command -v gnu-tar || command -v gnutar || command -v gtar) 2>/dev/null)
else
TAR ?= $(shell command -v tar 2>/dev/null)
endif

ifndef TAR
$(error You need gnu tar installed as either 'gnu-tar', 'gnutar' or 'gtar' on Darwin or 'tar' otherwise in order to make a release.)
endif

log = echo "=== $(1)"
map = $(foreach n,$(1),$(call $(2),$(n)))
find = $(foreach dir,$(wildcard $(1)),$(shell find $(dir) -name "$(2)"))

%.sha512: %
ifdef SHA512SUM
	$(VERBOSE) (cd $(dir $<) && $(SHA512SUM) $(SHA512SUM_ARGS) $(notdir $<) > $(notdir $@))
else
	$(error Cannot create hash of $< since shasum or sha512sum is not available in the system.)
endif

define render_template
	$(VERBOSE) printf -- '$(subst $(newline),\n,$(subst %,%%,$(subst ','\'',$(call $(1)))))\n' > $(2)
endef

# === NCS ======================================================================

ifeq ($(NCS_DIR),)
$(error NCS_DIR not defined, make sure to source NCS source file.)
endif

NCS       ?= ncs
NCSC      ?= ncsc
NCS_SETUP ?= ncs-setup
NCS_CLI   ?= ncs_cli -u admin
YANGER     ?= yanger

NCS_VERSION       ?= $(shell $(NCS) --version)
NCS_VERSION_CLEAN := $(shell echo $(NCS_VERSION) | sed 's/_.*//')
NCS_MAJOR_VERSION := $(shell echo $(NCS_VERSION) | cut -c 1)
NCS_MINOR_VERSION := $(shell echo $(NCS_VERSION) | cut -c 3)
NCS_VERSION_SHORT := $(NCS_MAJOR_VERSION).$(NCS_MINOR_VERSION)

NETSIM_CONFD_DIR := $(NCS_DIR)/netsim/confd
NETSIM_CONFDC  	 := $(NETSIM_CONFD_DIR)/bin/confdc

# === Dependency Utils =========================================================

# --- General Functions --------------------------------------------------------
dep_method         = $(or $(word 1,$($(1))),git)
dep_dir            = $(addprefix $(DEPS_DIR)/,$(1))
dep_local_test_dir = $(addprefix $(LOCAL_TEST_DEPS_DIR)/,$(1))

# --- GIT Functions ------------------------------------------------------------
dep_git_url    = $(or $(word 2,$($(1))),$(call DEFAULT_GIT_URL,$(1)))
dep_git_commit = $(or $(word 3,$($(1))),$(dep_$(1)_commit),master)

# === Dependencies =============================================================

.PHONY: deps test-deps clean-deps-log

# Are we building the package as a dependency of another package?
IS_DEP ?=

# Dependencies
BUILD_DEPS      ?=
TEST_DEPS       ?=
LOCAL_TEST_DEPS ?=

# Default directory for local test dependencies
LOCAL_TEST_DEPS_DIR ?= $(PACKAGE_DIR)/test/packages

# Default GIT url to use for dependencies
DEFAULT_GIT_URL ?= ssh://git@stash.tail-f.com/pkg/$(1).git

# File to put depndency information in when building.
deps_log := $(PACKAGE_MK_TMP)/deps.log


# NOTE: If the package is not a git repository assume that we are building from
#       an unpacked release and that any dependencies are present in the parent
#       directory of the package. Otherwise (if git repo) use the default deps
#       directory. Also don't download deps when GIT repo is not present.
#       Will always honor DEPS_DIR and SKIP_DEPS set by the user.
default_deps_dir := $(PACKAGE_DIR_ABS)/src/deps

ifeq ($(shell git rev-parse --is-inside-work-tree 2>/dev/null),true)
DEPS_DIR  ?= $(default_deps_dir)
SKIP_DEPS ?=
else
DEPS_DIR  ?= $(PACKAGE_DIR_ABS)/..
SKIP_DEPS ?= true
endif
export DEPS_DIR

# Use sort to remove duplicates
build_deps      = $(sort $(BUILD_DEPS))
test_deps       = $(sort $(TEST_DEPS))
local_test_deps = $(sort $(LOCAL_TEST_DEPS))
all_deps        = $(sort $(BUILD_DEPS) $(TEST_DEPS))

build_deps_dirs      = $(call map,$(build_deps),dep_dir)
test_deps_dirs       = $(call map,$(test_deps),dep_dir)
local_test_deps_dirs = $(call map,$(local_test_deps),dep_local_test_dir)
all_deps_dirs        = $(sort $(build_deps_dirs) $(test_deps_dirs))

# --- Templates --------------------------------------------------------------------
define do_with_deps
	$(VERBOSE) for dep in $(1); do \
		if ! grep -qs ^$$dep $(1)$$ $(deps_log); then \
			if [ -f $$dep/Makefile ]; then \
				echo "$$dep $(2)" >> $(deps_log); \
				$(MAKE) --no-print-directory -C $$dep $(2) IS_DEP=1 || exit $$?; \
			else \
				echo "$$dep $(3)" >> $(deps_log); \
				$(MAKE) --no-print-directory -C $$dep/src $(3) IS_DEP=1 || exit $$?; \
			fi \
		fi; \
	done
endef

define dep_fetch_git
	$$(VERBOSE) $$(call log,"Fetch $(1)")
	$$(VERBOSE) git clone $(call dep_git_url,$(1)) $$@
	$$(VERBOSE) (cd $$@; git checkout $(call dep_git_commit,$(1)))
endef

# Target template
define dep_target

ifndef dep_target_$(1)

dep_target_$(1) = true

$(call dep_dir,$(1)): $(if $(findstring local,$(call dep_method,$(1))),,| $$(DEPS_DIR))
	$(call dep_fetch_$(call dep_method,$(1)),$(1))

endif

endef

# --- Build --------------------------------------------------------------------
ifeq ($(SKIP_DEPS),)
deps: $(build_deps_dirs) clean-deps-log | $(PACKAGE_MK_TMP)
	$(call do_with_deps,$(build_deps_dirs),build,all)
else
deps:
endif

# --- Test ---------------------------------------------------------------------
ifeq ($(SKIP_DEPS),)
all_test_deps_dirs = $(test_deps_dirs) $(local_test_deps_dirs)
else
all_test_deps_dirs = $(local_test_deps_dirs)
endif

test-deps: $(all_test_deps_dirs) clean-deps-log | $(PACKAGE_MK_TMP)
	$(call do_with_deps,$(all_test_deps_dirs),build,all)

# --- Fetch targets ------------------------------------------------------------

$(foreach dep,$(all_deps),$(eval $(call dep_target,$(dep))))

$(DEPS_DIR):
	$(VERBOSE) mkdir -p $@

# --- Clean --------------------------------------------------------------------

# Clean depdencies, only clean test dependencies when not built as dependency
ifeq ($(SKIP_DEPS),)
clean:: clean-deps-log | $(PACKAGE_MK_TMP)
	$(call do_with_deps,$(wildcard $(build_deps_dirs)),clean,clean)
ifeq ($(IS_DEP),)
	$(call do_with_deps,$(wildcard $(test_deps_dirs)),clean,clean)
endif
endif

# Clean local test dependencies (only if not cleaned as a dependency)
ifeq ($(IS_DEP),)
clean:: clean-deps-log | $(PACKAGE_MK_TMP)
	$(call do_with_deps,$(wildcard $(sort $(local_test_deps_dirs))),clean,clean)
	$(VERBOSE) rm -rf $(deps_log)
endif

# Only remove the default dependency dir, not the user set one (DEPS_DIR).
distclean::
	$(VERBOSE) rm -rf $(default_deps_dir)

# Only clean the deps log for the top most package, otherwise we will rebuild
# packages further down the tree.
ifeq ($(IS_DEP),)
clean-deps-log:
	$(VERBOSE) rm -f $(deps_log)
else
clean-deps-log:
endif

# === Yang =====================================================================
YANG_DEPS          = $(build_deps_dirs)
YANG_ALL_FILES    := $(wildcard $(YANG_DIR)/*.yang) $(wildcard $(YANG_NED_DIR)/*.yang)
YANG_FILES        ?= $(and $(YANG_ALL_FILES),$(notdir $(shell grep -L "belongs-to" $(YANG_ALL_FILES))))
YANG_PATHS        += $(YANG_DIR) \
					 $(YANG_NED_DIR) \
			         $(patsubst %,%/src/yang,$(YANG_DEPS)) \
			         $(patsubst %,%/src/ncsc-out/modules/yang,$(YANG_DEPS))

NED                    ?=
NED_DEVICE_TYPE        ?= netconf
NED_YANG_COMMAND_FILES ?=
NED_ID_MODULE          ?= $(PACKAGE_NAME)-id
# --- FXS ----------------------------------------------------------------------
BUILD_OBJECTS += $(YANG_FILES:%.yang=$(LOAD_DIR)/%.fxs)

ifneq ($(wildcard $(YANG_NED_DIR)),)
ifeq ($(wildcard $(YANG_DIR)/$(NED_ID_MODULE).yang),)
$(error Invalid NED_ID_MODULE)
endif
NCSC_SUPPORTS_CDM := $(shell $(NCSC) -h | grep -q ncs-ned-id && echo true)
ifeq ($(NCSC_SUPPORTS_CDM),true)
	NED_ID = $(shell grep identity $(YANG_DIR)/$(NED_ID_MODULE).yang | awk '{print $$2}')
	NED_ID_ARGS = --ncs-ned-id $(NED_ID_MODULE):$(NED_ID)
endif
endif

$(LOAD_DIR)/%.fxs: $(YANG_DIR)/%.yang | $(LOAD_DIR) $(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang
	$(VERBOSE) $(NCSC) $(YANG_PATHS:%=--yangpath %) -c $< -o $@
	$(VERBOSE) $(YANGER) -f depend $(YANG_PATHS:%=-p %) --depend-include-path --depend-target $@ -o $(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang/$(rel)$(basename $(notdir $<)).yang.dep $<

$(LOAD_DIR)/%.fxs: $(NCSC_OUT_DIR)/modules/fxs/%.fxs | $(LOAD_DIR) $(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned
	$(VERBOSE) cp $< $@
	$(VERBOSE) $(YANGER) -f depend $(YANG_PATHS:%=-p %) --depend-include-path --depend-target $@ -o $(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned/$(rel)$(basename $(notdir $@)).yang.dep $(YANG_NED_DIR)/$(basename $(notdir $@)).yang

.PRECIOUS: $(NCSC_OUT_DIR)/modules/fxs/%.fxs

$(NCSC_OUT_DIR)/modules/fxs/%.fxs: $(YANG_NED_DIR)/%.yang | $(NCSC_OUT_DIR)
ifeq ($(NED),bundle)
	$(VERBOSE) $(NCSC) $(YANG_PATHS:%=--yangpath %) \
               --ncs-compile-bundle $(dir $<) \
               --ncs-device-dir $(NCSC_OUT_DIR) \
               --ncs-device-type $(NED_DEVICE_TYPE) \
               $(NED_ID_ARGS)
else
	$(VERBOSE) $(NCSC) $(YANG_PATHS:%=--yangpath %) \
               --ncs-compile-module $< \
               $(if $(findstring $(notdir $<),$(NED_YANG_COMMAND_FILES)),--ncs-skip-config) \
               --ncs-device-dir $(NCSC_OUT_DIR) \
               --ncs-device-type $(NED_DEVICE_TYPE) \
               $(NED_ID_ARGS)
endif

$(NCSC_OUT_DIR) $(LOAD_DIR) $(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang $(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned:
	$(VERBOSE) mkdir -p $@

$(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang/$(rel)%.yang.dep:
.PRECIOUS: $(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang/$(rel)%.yang.dep

$(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned/$(rel)%.yang.dep:
.PRECIOUS: $(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned/$(rel)%.yang.dep

include $(wildcard $(YANG_FILES:%.yang=$(PACKAGE_MK_TMP_LOCAL)/deps/yang/yang/$(rel)%.yang.dep))
include $(wildcard $(YANG_FILES:%.yang=$(PACKAGE_MK_TMP_LOCAL)/deps/yang/ned/$(rel)%.yang.dep))

clean::
	$(VERBOSE) rm -rf $(NCSC_OUT_DIR)

# --- Erlang -------------------------------------------------------------------

ERL_YANG_INCLUDES_DIR := $(PACKAGE_MK_TMP_LOCAL)/erlang/yang-includes

.PRECIOUS: $(ERL_YANG_INCLUDES_DIR)/%.hrl
$(ERL_YANG_INCLUDES_DIR)/%.hrl: $(LOAD_DIR)/%.fxs | $(ERL_YANG_INCLUDES_DIR)
	$(VERBOSE) $(NCSC) --emit-hrl $@ $<

$(ERL_YANG_INCLUDES_DIR):
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) rm -rf $(ERL_YANG_INCLUDES_DIR) $(PACKAGE_MK_TMP_LOCAL)/deps/yang

# --- Java ---------------------------------------------------------------------
# No namespace or build.xml, so no use creating Java files
ifeq ($(JAVA_ENABLED),true)

NAMESPACE ?=

yang_namespace     = $(if $($(1)_namespace),$($(1)_namespace),$(NAMESPACE))
yang_namespace_dir = $(JAVA_DIR)/src/$(shell echo $(call yang_namespace,$(1)) | sed 's/\./\//g')

JAVA_NCSC_ARGS ?= --java-disable-prefix \
				  --exclude-enums \
				  --fail-on-warnings

define yang_java_template

YANG_JAVA_FILES += $(call yang_namespace_dir,$(1))/$(patsubst %.yang,%.java,$(shell echo $(1) | awk -F - ' {printf $$1; for (i=2; i<=NF; i++) printf toupper(substr($$i,1,1)) substr($$i,2)} '))

$(call yang_namespace_dir,$(1))/$(patsubst %.yang,%.java,$(shell echo $(1) | awk -F - ' {printf $$1; for (i=2; i<=NF; i++) printf toupper(substr($$i,1,1)) substr($$i,2)} ')): $$(LOAD_DIR)/$(patsubst %.yang,%.fxs,$(1)) | $(call yang_namespace_dir,$(1))
	$$(VERBOSE) $$(NCSC) $$(JAVA_NCSC_ARGS) --java-package "$(call yang_namespace,$(1))" --emit-java $$@ $$<

ifndef $(call yang_namespace,$(1))_namespace_dir

$(call yang_namespace,$(1))_namespace_dir = true

$(call yang_namespace_dir,$(1)):
	$$(VERBOSE) mkdir -p $$@

endif

endef

$(foreach file,$(YANG_FILES),$(eval $(call yang_java_template,$(file))))

endif

# === Erlang ===================================================================

ERLANG_APPS := $(patsubst $(ERL_DIR)/%,%,$(wildcard $(ERL_DIR)/*))

ERLC        ?= erlc
DEBUG_FLAGS  = $(patsubst debug,-Ddebug,$(TYPE))
ERLC_FLAGS  += -W +debug_info $(DEBUG_FLAGS) -I $(NCS_DIR)/erlang/econfd/include
APPSCRIPT   ?= '$$vsn=shift; $$mods=""; while(@ARGV){ $$_=shift; s/^([A-Z].*)$$/\'\''$$1\'\''/; $$mods.=", " if $$mods; $$mods .= $$_; } while(<>) { s/%VSN%/$$vsn/; s/%MODULES%/$$mods/; print; }'
BEAM_FILES  +=
APP_FILES   +=

define erlang_app_template
BEAM_FILES_$(1) = $$(patsubst $$(ERL_DIR)/$(1)/src/%.erl,%.beam,$$(wildcard $$(ERL_DIR)/$(1)/src/*.erl))
APP_FILES_$(1)  = $$(patsubst $$(ERL_DIR)/$(1)/src/%.app.src,%.app,$$(wildcard $$(ERL_DIR)/$(1)/src/*.app.src))
BUILD_OBJECTS  += $$(addprefix $$(ERL_DIR)/$(1)/ebin/,$$(APP_FILES_$(1)) $$(BEAM_FILES_$(1)))

$$(ERL_DIR)/$(1)/ebin/%.beam: $$(ERL_DIR)/$(1)/src/%.erl $$(YANG_FILES:%.yang=$$(ERL_YANG_INCLUDES_DIR)/%.hrl)| $$(ERL_DIR)/$(1)/ebin $$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1)
	$$(VERBOSE) $$(ERLC) $$(ERLC_FLAGS) -I $$(ERL_DIR)/$(1)/include -I $$(ERL_YANG_INCLUDES_DIR) -M -MP -MQ $$(patsubst $$(ERL_DIR)/$(1)/src/%.erl,$$(ERL_DIR)/$(1)/ebin/%.beam,$$<) -MF $$(patsubst $$(ERL_DIR)/$(1)/src/%.erl,$$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1)/$$(rel)%.Pbeam,$$<) $$<
	$$(VERBOSE) $$(ERLC) $$(ERLC_FLAGS) -I $$(ERL_DIR)/$(1)/include -I $$(ERL_YANG_INCLUDES_DIR) -o $$(dir $$@) $$<

$$(ERL_DIR)/$(1)/ebin/%.app: $$(ERL_DIR)/$(1)/src/%.app.src | $$(ERL_DIR)/$(1)/ebin
	$$(VERBOSE) perl -e $$(APPSCRIPT) $$(PACKAGE_VERSION) $$(patsubst $$(ERL_DIR)/$(1)/src/%.erl,%,$$(wildcard $$(ERL_DIR)/$(1)/src/*.erl)) < $$< > $$@

$$(ERL_DIR)/$(1)/ebin:
	$$(VERBOSE) mkdir -p $$@

$$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1)/$$(rel)%.Pbeam:
.PRECIOUS: $$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1)/$$(rel)%.Pbeam

$$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1): | $(PACKAGE_MK_TMP_LOCAL)
	$$(VERBOSE) mkdir -p $$@

# Include header dependency information
include $$(wildcard $$(BEAM_FILES_$(1):%.beam=$$(PACKAGE_MK_TMP_LOCAL)/deps/erlang/$(1)/$$(rel)%.Pbeam))
endef

$(foreach app,$(ERLANG_APPS),$(eval $(call erlang_app_template,$(app))))

clean::
	$(VERBOSE) rm -rf $(PACKAGE_MK_TMP_LOCAL)/deps/erlang/

# === Java =====================================================================

ANT ?= ant

ifeq ($(JAVA_ENABLED),true)

BUILD_OBJECTS += $(JAVA_DIR)/build/.built
JAVA_FILES    := $(call find,$(JAVA_DIR),*.java)

$(JAVA_DIR)/build/.built: deps $(YANG_JAVA_FILES) $(JAVA_DIR)/build.xml $(JAVA_FILES) | $(JAVA_DIR)/build
	$(VERBOSE) (cd $(JAVA_DIR) && $(ANT) -q -S all)
	$(VERBOSE) touch $@

$(JAVA_DIR)/build:
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) (cd $(JAVA_DIR) && $(ANT) -q -S clean)

endif

# === Python ===================================================================

PYTHON        ?= python
PYTHON_FILES  ?= $(call find,$(PYTHON_DIR),*.py)
BUILD_OBJECTS += $(PYTHON_FILES:%.py=%.pyc)

PYTHON_UNITTEST_FILES ?= $(call find,$(PYTHON_UNITTEST_DIR),*.py)

define python_template

$(1)c: $(1)
	$$(VERBOSE) $$(PYTHON) -m py_compile $$<

endef

$(foreach file,$(PYTHON_FILES),$(eval $(call python_template,$(file))))

PY_LINT       ?= $(shell command -v pylint 2>/dev/null)
PY_LINT_FLAGS ?= -E
PY_LINT_FILES ?= $(PYTHON_FILES) $(PYTHON_UNITTEST_FILES)

ifdef PY_LINT
.PHONY: pylint

pylint:
	$(VERBOSE) $(call log, "Running PyLint.")
	$(VERBOSE) PYTHONPATH=$(PYTHON_PATH) $(PY_LINT) $(PY_LINT_FLAGS) $(PY_LINT_FILES)
else
pylint:
	$(error Target 'pylint' not valid as 'pylint' is not available on your system.)
endif

# === Release ==================================================================

RELEASE_FILENAME ?= ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz

RELEASE_PATHS  += CHANGES.txt erlang-lib/*/ebin/ load-dir/ package-meta-data.xml private-jar/ shared-jar/ python/ templates/ webui/ src/yang src/ncsc-out netsim src/Makefile package.mk Makefile
RELEASE_PATHSS  = $(wildcard $(RELEASE_PATHS:%=$(PACKAGE_DIR_REL)%))
RELEASE_PATHSSS = $(RELEASE_PATHSS:$(PACKAGE_DIR_REL)%=%)

RELEASE_DEPS     += $(foreach dir,$(wildcard $(PYTHON_DIR)),$(shell find $(dir) -name "*.py"))
RELEASE_EXCLUDES += .git* *.java *.erl *.hrl *.app.src *.Pbeam *.pyc .package.mk/* examples/

.PHONY: release
release: $(PACKAGE_DIR_ABS)/$(RELEASE_FILENAME) $(PACKAGE_DIR_ABS)/$(RELEASE_FILENAME).sha512

%/$(RELEASE_FILENAME): build $(RELEASE_PATHSS) $(RELEASE_DEPS) | $(PACKAGE_MK_TMP)
	$(VERBOSE) $(TAR) -C $(PACKAGE_DIR_ABS)/.. -czf $@ \
		--xform 's,^$(notdir $(PACKAGE_DIR_ABS)),$(PACKAGE_NAME),' \
		$(RELEASE_EXCLUDES:%=--exclude "%") \
		$(addprefix $(notdir $(PACKAGE_DIR_ABS))/,$(RELEASE_PATHSSS))

clean::
	$(VERBOSE) rm -f $(RELEASE_FILENAME) $(RELEASE_FILENAME).sha512

# --- Bundle -------------------------------------------------------------------

BUNDLE_FILENAME ?= ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-bundle.tar.gz
bundle_log      := $(PACKAGE_MK_TMP)/bundle.log
bundle_dir      := $(PACKAGE_MK_TMP)/bundle

.PHONY: bundle bundle-release bundle-release-deps clean-bundle-log

bundle: $(PACKAGE_DIR)/$(BUNDLE_FILENAME).sha512 $(PACKAGE_DIR)/$(BUNDLE_FILENAME)

%/$(BUNDLE_FILENAME): bundle-release
	$(VERBOSE) $(call log,"Creating bundle $(notdir $@)")
	$(VERBOSE) tar czf $@ -C $(bundle_dir) -T $(bundle_log)

bundle-release: clean-bundle-log bundle-release-deps $(bundle_dir)/$(RELEASE_FILENAME)
	$(VERBOSE) echo $(RELEASE_FILENAME) >> $(bundle_log)

$(bundle_dir)/$(RELEASE_FILENAME): | $(bundle_dir)

ifeq ($(SKIP_DEPS),)
bundle-release-deps: $(build_deps_dirs) clean-deps-log | $(PACKAGE_MK_TMP)
	$(call do_with_deps,$(build_deps_dirs),bundle-release,bundle-release)
else
bundle-release-deps:
endif

# Only clean the bundle log for the top most package, otherwise we will rebundle
# packages further down the tree.
ifeq ($(IS_DEP),)
clean-bundle-log:
	$(VERBOSE) rm -f $(bundle_log)
else
clean-bundle-log:
endif

$(bundle_dir): | $(PACKAGE_MK_TMP)
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) rm -rf $(BUNDLE_FILENAME) \
		$(BUNDLE_FILENAME).sha512 \
		$(bundle_log) \
		$(bundle_dir)


# --- Development bundle -------------------------------------------------------

.PHONY: development-bundle

DEVELOPMENT_BUNDLE_FILENAME ?= ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-dev.tar.gz
development_bundle_dir      := $(PACKAGE_MK_TMP_LOCAL)/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-dev

development-bundle: $(PACKAGE_DIR)/$(DEVELOPMENT_BUNDLE_FILENAME).sha512 $(PACKAGE_DIR)/$(DEVELOPMENT_BUNDLE_FILENAME)

%/$(DEVELOPMENT_BUNDLE_FILENAME): $(development_bundle_dir)/yang $(if $(JAVA_ENABLED),$(development_bundle_dir)/shared-jar,) $(if $(NED),$(development_bundle_dir)/ncsc-out,)
	$(VERBOSE) $(call log,"Creating development bundle $(notdir $@)")
	$(VERBOSE) tar czf $@ -h -C $(dir $(development_bundle_dir)) --exclude ".*" $(notdir $(development_bundle_dir))

$(development_bundle_dir)/yang: $(YANG_ALL_FILES) | $(development_bundle_dir)
	$(VERBOSE) ln -sf $(realpath $(YANG_DIR)) $(realpath $(development_bundle_dir))

ifneq ($(NED),)
$(development_bundle_dir)/ncsc-out: $(YANG_FILES:%.yang=$(NCSC_OUT_DIR)/modules/fxs/%.fxs) | $(development_bundle_dir)
	$(VERBOSE) ln -sf $(realpath $(NCSC_OUT_DIR)) $(realpath $(development_bundle_dir))
endif

ifneq ($(JAVA_ENABLED),)
$(development_bundle_dir)/shared-jar: $(JAVA_DIR)/build/.built | $(development_bundle_dir)
	$(VERBOSE) ln -sf $(realpath $(SHARED_JAR_DIR)) $(realpath $(development_bundle_dir))
endif

$(development_bundle_dir):
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) rm -rf $(PACKAGE_DIR)/$(DEVELOPMENT_BUNDLE_FILENAME).sha512 \
		$(PACKAGE_DIR)/$(DEVELOPMENT_BUNDLE_FILENAME) \
		$(development_bundle_dir)

# --- Examples bundle -----------------------------------------------------------

.PHONY: examples-bundle

EXAMPLES ?= $(notdir $(wildcard $(EXAMPLES_DIR)/*))

examples_dirs = $(wildcard $(addprefix $(EXAMPLES_DIR)/,$(EXAMPLES)))
examples      = $(notdir $(examples_dirs))

ifeq ($(examples_dirs),)

examples-bundle:
	$(VERBOSE) echo "No examples found in $(EXAMPLES_DIR), will not create examples bundle"

else

EXAMPLES_BUNDLE_FILENAME ?= ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-examples.tar.gz
EXAMPLES_EXCLUDES        += .git*

examples_bundle_dir      := $(PACKAGE_MK_TMP_LOCAL)/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-examples

examples-bundle: $(PACKAGE_DIR)/$(EXAMPLES_BUNDLE_FILENAME).sha512 $(PACKAGE_DIR)/$(EXAMPLES_BUNDLE_FILENAME)

%/$(EXAMPLES_BUNDLE_FILENAME): $(examples:%=$(examples_bundle_dir)/packages/%) $(examples_bundle_dir)/README $(examples_bundle_dir)/Makefile bundle-release | $(examples_bundle_dir)/packages
	$(VERBOSE) for bundle in `cat $(bundle_log)`; do \
			       tar -C $(examples_bundle_dir)/packages -xzf $(PACKAGE_MK_TMP)/bundle/$$bundle; \
			   done
	$(VERBOSE) $(call log,"Building/testing examples")
	$(VERBOSE) $(MAKE) --no-print-directory -C $(examples_bundle_dir) test || (echo "ERROR: Failed building/testing examples" && exit 1)
	$(VERBOSE) $(MAKE) --no-print-directory -C $(examples_bundle_dir) clean || (echo "ERROR: Failed building/testing examples" && exit 1)
	$(VERBOSE) $(call log,"Creating examples bundle $(notdir $@)")
	$(VERBOSE) tar czf $@ -h -C $(dir $(examples_bundle_dir)) --exclude ".*" $(notdir $(examples_bundle_dir))

.PRECIOUS: $(examples_bundle_dir)/packages/%
$(examples_bundle_dir)/packages/%: $(EXAMPLES_DIR)/% | $(examples_bundle_dir)/packages
	$(VERBOSE) cp -r $< $@

$(examples_bundle_dir)/Makefile: | $(examples_bundle_dir)
	$(call render_template,examples_Makefile,$(examples_bundle_dir)/Makefile)

$(examples_bundle_dir)/README: | $(examples_bundle_dir)
	$(call render_template,examples_README,$(examples_bundle_dir)/README)

$(examples_bundle_dir):
	$(VERBOSE) mkdir -p $@

$(examples_bundle_dir)/packages:
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) rm -rf $(examples_bundle_dir) \
		$(PACKAGE_DIR)/$(EXAMPLES_BUNDLE_FILENAME).sha512 \
		$(PACKAGE_DIR)/$(EXAMPLES_BUNDLE_FILENAME)

define examples_Makefile
.PHONY: all clean test

all clean test:
	@for example in $(examples); do \\
		if [ -f packages/$$$$example/Makefile ]; then \\
			$$(MAKE) -C packages/$$$$example $$@; \\
		else \\
			$$(MAKE) -C packages/$$$$example/src $$@; \\
		fi \\
	 done
endef

define examples_README
$(PACKAGE_NAME) $(PACKAGE_VERSION) example bundle
===================================================

The example packages are available in the packages/ directory and to build them
run `make` in the root directory. To run the examples in NSO run
`ncs-setup --dest .` in the root directory to create a NSO installation. Then
one can start an NSO instance with the example packages (and any dependencies)
loaded by running `ncs` in the root directory.
endef

endif

# === Test =====================================================================

.PHONY: test-setup-ncs test-ncs-cli test-reload-packages

ifeq ($(patsubst $(PACKAGE_DIR_ABS)/test%,true,$(realpath .)),true)
DEFAULT_TEST_DIRS = $(realpath .)
else
DEFAULT_TEST_DIRS = $(PACKAGE_DIR)/test
endif

TEST_DIRS ?= $(DEFAULT_TEST_DIRS)
TEST_DIRSS = $(wildcard $(TEST_DIRS))

# --- Python -------------------------------------------------------------------

PYTHON_UNITTEST_TEST_FILES ?= $(call find,$(TEST_DIRSS),test_*.py)
PYTHON_UNITTEST_MODULES    := $(notdir $(PYTHON_UNITTEST_TEST_FILES:%.py=%))

PYTHON_PATHS += $(PYTHONPATH) $(PYTHON_DIR) $(PYTHON_UNITTEST_DIR)
PYTHON_PATH  ?= $(subst $(eval) ,:,$(PYTHON_PATHS))

ifneq ($(PYTHON_UNITTEST_MODULES),)
test: test-python-unittest

.PHONY: test-python-unittest clean-python-unittest

test-python-unittest: build
	$(VERBOSE) $(call log,"Running Python unittest")
	$(VERBOSE) PYTHONPATH=$(PYTHON_PATH) $(PYTHON) -m unittest -v $(PYTHON_UNITTEST_MODULES)

clean-python-unittest:
	$(VERBOSE) rm -f $(PYTHON_UNITTEST_DIR)/*.pyc $(PYTHON_UNITTEST_DIR)/unittest.log

clean:: clean-python-unittest

endif


# --- NCS ----------------------------------------------------------------------
TEST_NCS_DIR ?= $(PACKAGE_DIR_REL)test/ncs

test-setup-ncs: $(TEST_NCS_DIR)/packages/$(RELEASE_FILENAME) \
				test-deps \
	            $(addprefix $(TEST_NCS_DIR)/packages/,$(sort $(test_deps) $(local_test_deps)))

$(TEST_NCS_DIR)/packages/$(RELEASE_FILENAME): $(TEST_NCS_DIR)

$(TEST_NCS_DIR):
# Disable commit messages in the CLI by default. Commit messages can be troublesome when running
# Lux tests beacuse they can come at any time and completely change the output of a command when
# run in a shell.
# To disable rollback file generation, set DISABLE_LOGS = rollback
# To disable xpath trace as well, set DISABLE_LOGS = rollback xpath-trace-log
	$(VERBOSE) $(NCS_SETUP) --dest $@ --no-netsim
	$(VERBOSE) cp $@/ncs.conf $@/ncs.conf.in
	$(VERBOSE) sed -e "s|</cli>| <commit-message>false</commit-message>  </cli>|" \
                       -e "s|<port>|<port>4|" \
                       -e "s|</ncs-config>|$(EXTRA_NCS_CONFIG)</ncs-config>|" \
                       < $@/ncs.conf.in > $@/ncs.conf
	@for i in $(DISABLE_LOGS); do \
		cp $@/ncs.conf $@/ncs.conf.in; \
		sed -e "s|<$$i>|<$$i><enabled>false</enabled>|" \
            -e "/<$$i>/{n;d;}" \
            < $@/ncs.conf.in > $@/ncs.conf; \
	done

	@for i in $(ENABLE_ENTITY); do \
		cp $@/ncs.conf $@/ncs.conf.in; \
		sed -e "s|<$$i>|<$$i><enabled>true</enabled>|" \
            -e "/<$$i>/{n;d;}" \
            < $@/ncs.conf.in > $@/ncs.conf; \
	done

	$(VERBOSE) rm $@/ncs.conf.in

clean::
	$(VERBOSE) rm -rf $(TEST_NCS_DIR)

test-ncs-cli: test-setup-ncs
	$(VERBOSE) $(NCS_CLI)

test-reload-packages: test-setup-ncs
	$(VERBOSE) $(call log,"Reloading packages")
	$(VERBOSE) echo "request packages reload" | $(NCS_CLI)

# --- Dependencies -------------------------------------------------------------

# Generate targets for adding the test dependencies to the test NCS
define test_dep_target

$$(TEST_NCS_DIR)/packages/$(1): $(call dep_dir,$(1))
	$$(VERBOSE) ln -fs $$(abspath $$<) $$@

endef

$(foreach dep,$(test_deps),$(eval $(call test_dep_target,$(dep))))

# Generate targets for adding the local test dependencies to the test NCS
define local_test_dep_target

$$(TEST_NCS_DIR)/packages/$(1): $(call dep_local_test_dir,$(1))
	$$(VERBOSE) ln -fs $$(abspath $$<) $$@

endef

$(foreach dep,$(local_test_deps),$(eval $(call local_test_dep_target,$(dep))))

# --- Lux ----------------------------------------------------------------------
LUX            ?= lux
LUX_ARGS       ?=

LUX_COMMON_DIR          ?= $(PACKAGE_DIR_REL)test/internal/lux/lux-common
LUX_COMMON_REPO         ?= ssh://git@stash.tail-f.com/pkg/lux-common.git
LUX_COMMON_COMMIT       ?=
LUX_COMMON_BUILD_DIR    ?= $(PACKAGE_DIR)/.lux_common.build
LUX_COMMON_BUILD_CONFIG ?= $(PACKAGE_DIR)/lux_common.build.config

ifneq ($(TEST_DIRSS),)
LUX_TESTS = $(shell find $(TEST_DIRSS) -name "*.lux")
endif

ifneq ($(LUX_TESTS),)
test: test-lux

.PHONY: test-lux lux-common

test-lux:
	$(VERBOSE) $(call log,"Running Lux testing")
	$(VERBOSE) $(LUX) $(LUX_ARGS) $(LUX_TESTS)

lux-common: $(LUX_COMMON_DIR)
	$(VERBOSE) git clone $(LUX_COMMON_REPO) $(LUX_COMMON_BUILD_DIR)
ifneq ($(LUX_COMMON_COMMIT),)
	$(VERBOSE) cd $(LUX_COMMON_BUILD_DIR) && git checkout $(LUX_COMMON_COMMIT)
endif
	$(VERBOSE) if [ -f $(LUX_COMMON_BUILD_CONFIG) ]; then cp $(LUX_COMMON_BUILD_CONFIG) $(LUX_COMMON_BUILD_DIR); fi
	$(VERBOSE) cd $(LUX_COMMON_BUILD_DIR) && $(MAKE)
	$(VERBOSE) cp $(LUX_COMMON_BUILD_DIR)/lux_common.luxinc $(LUX_COMMON_DIR)
	$(VERBOSE) rm -rf $(LUX_COMMON_BUILD_DIR)

$(LUX_COMMON_DIR):
	$(VERBOSE) mkdir -p $@
endif

# === Doc ======================================================================

DOC_DIR           ?= $(PACKAGE_DIR_REL)doc
DOC_BOOK_NAMES    ?= $(shell echo $(PACKAGE_NAME) | sed -E 's/-/_/g')

.PHONY: doc

# If no xml files don't build any documentation.
ifeq ($(wildcard $(patsubst %,$(DOC_DIR)/%.xml,$(DOC_BOOK_NAMES))),)

doc:
	$(VERBOSE) echo "WARNING: No XML files found to generate documentation for"

else

DOC_PRODUCT       ?= NSO
DOC_OUT_DIR        = $(DOC_DIR)/output
DOC_HTML_DIR       = $(DOC_OUT_DIR)/html
DOC_HTML_DIRS      = $(DOC_BOOK_NAMES:%=$(DOC_HTML_DIR)/%)
DOC_PDF_FILES      = $(DOC_BOOK_NAMES:%=$(DOC_OUT_DIR)/%.pdf)
DOC_GLOBAL_ENT     = $(DOC_DIR)/global.ent

# Uncertain if this variable should be set explicitly,
# or defined by the tailf-doc environment.
DOC_TAILF_DOC_COMMON = --product "$(DOC_PRODUCT)"

doc: doc-pdf doc-html

.PHONY: doc-pdf doc-html

doc-html:  $(DOC_HTML_DIRS:%=%/index.html)

ifeq ($(words $(DOC_PDF_FILES)),1)

doc-pdf: $(PACKAGE_DIR)/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.pdf

%/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.pdf: $(DOC_PDF_FILES)
	$(VERBOSE) cp $< $@

else

doc-pdf: $(PACKAGE_DIR)/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.tar.gz

%/ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.tar.gz: $(DOC_PDF_FILES)
	$(VERBOSE) tar czf $@ -C $(DOC_OUT_DIR) $(notdir $(DOC_PDF_FILES))

endif

$(DOC_GLOBAL_ENT): $(DOC_DIR)/global.ent.in
	$(VERBOSE) sed -e "s|@NSO_VERSION@|$(shell ncs --version)|g" -e "s|@PKG_VERSION@|$(PACKAGE_VERSION)|g" < $< > $@

.PRECIOUS: $(DOC_OUT_DIR)/%.pdf
$(DOC_OUT_DIR)/%.pdf: $(DOC_DIR)/%.fo | $(DOC_OUT_DIR)
	$(VERBOSE) tailf-doc $(DOC_TAILF_DOC_COMMON) --output $@ pdf $<

.PRECIOUS: $(DOC_DIR)/%.fo
$(DOC_DIR)/%.fo: $(DOC_DIR)/%.xml $(DOC_GLOBAL_ENT) | $(DOC_OUT_DIR) $(PACKAGE_MK_TMP_LOCAL)/deps/doc
	$(VERBOSE) tailf-doc depend -s fo $< > $(patsubst $(DOC_DIR)/%.xml,$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.fo.d,$<)
	$(VERBOSE) tailf-doc $(DOC_TAILF_DOC_COMMON) --output $@ fo $<

$(DOC_HTML_DIR)/%/index.html: $(DOC_DIR)/%.xml $(DOC_GLOBAL_ENT) | $(DOC_HTML_DIR)/%/ $(PACKAGE_MK_TMP_LOCAL)/deps/doc
	$(VERBOSE) tailf-doc depend -t $@ $< > $(patsubst $(DOC_DIR)/%.xml,$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.html.d,$<)
	$(VERBOSE) (cd $(DOC_DIR) && tailf-doc $(DOC_TAILF_DOC_COMMON) --output $(realpath $(dir $@)) html $(realpath $<))

$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.fo.d:
.PRECIOUS: $(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.fo.d

$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.html.d:
.PRECIOUS: $(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.html.d

include $(wildcard $(DOC_BOOK_NAMES:%=$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.fo.d))
include $(wildcard $(DOC_BOOK_NAMES:%=$(PACKAGE_MK_TMP_LOCAL)/deps/doc/$(rel)%.xml.d))

$(PACKAGE_MK_TMP_LOCAL)/deps/doc: | $(PACKAGE_MK_TMP_LOCAL)
	$(VERBOSE) mkdir -p $@

$(DOC_OUT_DIR):
	$(VERBOSE) mkdir -p $@

.PRECIOUS: $(DOC_HTML_DIR)/%/
$(DOC_HTML_DIR)/%/:
	$(VERBOSE) mkdir -p $@

clean::
	$(VERBOSE) rm -rf $(DOC_OUT_DIR) \
		$(DOC_GLOBAL_ENT) \
		$(DOC_DIR)/*.fo \
		$(PACKAGE_MK_TMP_LOCAL)/deps/doc/ \
		ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.pdf \
		ncs-$(NCS_VERSION)-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-doc.tar.gz \

endif

# === Netsim ===================================================================

.PHONY: install netsim-install

NETSIM_DIR := $(PACKAGE_DIR_REL)netsim

ifneq ($(wildcard $(NETSIM_DIR)/),)
NETSIM_XML         += $(NCS_DIR)/netsim/confd/var/confd/cdb/aaa_init.xml
NETSIM_EXTRA_FILES ?=
NETSIM_YANG_PATHS  += $(YANG_DIR) $(YANG_NED_DIR)
NETSIM_YANG_FILES  ?= $(filter-out $(NED_ID_MODULE).yang,$(YANG_FILES))
NETSIM_ERL_FILES    = $(wildcard $(NETSIM_DIR)/*.erl)

BUILD_OBJECTS += $(patsubst %.erl,%.beam,$(NETSIM_ERL_FILES))
BUILD_OBJECTS += $(patsubst %.app.src,%.app,$(wildcard $(NETSIM_DIR)/*.app.src))
BUILD_OBJECTS += $(patsubst %.yang,%.fxs,$(wildcard $(NETSIM_DIR)/*.yang))
BUILD_OBJECTS += $(patsubst %.yang,$(NETSIM_DIR)/%.fxs,$(NETSIM_YANG_FILES))

$(NETSIM_DIR)/%.app: $(NETSIM_DIR)/%.app.src
	$(VERBOSE) perl -e $(APPSCRIPT) $(PACKAGE_VERSION) $(patsubst $(NETSIM_DIR)/%.erl,%,$(wildcard $(NETSIM_DIR)/*.erl)) < $< > $@

$(NETSIM_DIR)/%.beam: $(NETSIM_DIR)/%.erl $(NETSIM_YANG_FILES:%.yang=$(NETSIM_DIR)/%.hrl) $(patsubst %.yang,%.hrl,$(wildcard $(NETSIM_DIR)/*.yang)) | $(PACKAGE_MK_TMP_LOCAL)/deps/netsim
	$(VERBOSE) $(ERLC) $(ERLC_FLAGS) -I $(NETSIM_DIR) -M -MP -MG -MQ $(patsubst $(NETSIM_DIR)/%.erl,$(NETSIM_DIR)/%.beam,$<) -MF $(patsubst $(NETSIM_DIR)/%.erl,$(PACKAGE_MK_TMP_LOCAL)/deps/netsim/$(rel)%.Pbeam,$<) $<
	$(VERBOSE) $(ERLC) $(ERLC_FLAGS) -I $(NETSIM_DIR) -o $(NETSIM_DIR) $<

.PRECIOUS: $(NETSIM_DIR)/%.hrl
$(NETSIM_DIR)/%.hrl: $(NETSIM_DIR)/%.fxs
	$(VERBOSE) $(NETSIM_CONFDC) --emit-hrl $@ $<

$(NETSIM_DIR)/%.fxs: $(YANG_DIR)/%.yang
	$(VERBOSE) $(NETSIM_CONFDC) $(NETSIM_YANG_PATHS:%=--yangpath %) -c $< -o $@

$(NETSIM_DIR)/%.fxs: $(YANG_NED_DIR)/%.yang
	$(VERBOSE) $(NETSIM_CONFDC) $(NETSIM_YANG_PATHS:%=--yangpath %) -c $< -o $@

$(NETSIM_DIR)/%.fxs: $(NETSIM_DIR)/%.yang
	$(VERBOSE) $(NETSIM_CONFDC) $(NETSIM_YANG_PATHS:%=--yangpath %) -c $< -o $@

$(PACKAGE_MK_TMP_LOCAL)/deps/netsim/$(rel)%.Pbeam:

$(PACKAGE_MK_TMP_LOCAL)/deps/netsim: | $(PACKAGE_MK_TMP_LOCAL)
	$(VERBOSE) mkdir -p $@

# Include header dependency information
include $(wildcard $(NETSIM_ERL_FILES:$(NETSIM_DIR)/%.erl=$(PACKAGE_MK_TMP_LOCAL)/deps/netsim/$(rel)%.Pbeam))

# Invoked by netsim, who will sed substitute the %var% PORT variables
# in the confd.conf.netsim file
# The install target here will be invoked multiple times by ncs-netsim,
# once for each device in the simulation network
# The following env variable will be set when ncs-netsim invokes this
# install target
# - DEST_DIR this is where all the files shall go, it's the directory
#   that will be used as execution environment for this ConfD instance
# - NAME this is the name of the managed device
# - COUNTER this is the number of the managed device
install: $(if $(wildcard $(DEST_DIR)),netsim-install)

netsim-install:
	@if [ -z "$${DEST_DIR}" ]; then echo "No DEST_DIR  var"; exit 1; fi
	@if [ ! -d "$${DEST_DIR}" ]; then "echo No DEST_DIR"; exit 1; fi
	@mkdir $${DEST_DIR}/cdb 2>/dev/null || true
	@mkdir $${DEST_DIR}/logs 2>/dev/null || true
	@for i in $(NETSIM_XML); do \
		sed -e 's/%NAME%/$(NAME)/g' -e 's/%COUNTER%/$(COUNTER)/g' \
		  $$i > $${DEST_DIR}/cdb/`basename $$i`; \
	done
ifneq ($(wildcard $(NETSIM_DIR)/*.fxs),)
	@cp -f $(NETSIM_DIR)/*.fxs $${DEST_DIR}
endif
ifneq ($(wildcard $(NETSIM_DIR)/*.app),)
	@cp -f $(NETSIM_DIR)/*.app $${DEST_DIR}
endif
ifneq ($(wildcard $(NETSIM_DIR)/*.beam),)
	@cp -f $(NETSIM_DIR)/*.beam $${DEST_DIR}
endif
	@cp -af $(NCS_DIR)/netsim/confd/etc/confd/ssh $${DEST_DIR}
ifneq ($(wildcard $(NETSIM_EXTRA_FILES:%=$(NETSIM_DIR)/%)),)
	@cp -f $(wildcard $(NETSIM_EXTRA_FILES:%=$(NETSIM_DIR)/%)) $${DEST_DIR}
endif

clean::
	$(VERBOSE) rm -rf $(PACKAGE_MK_TMP_LOCAL)/deps/netsim/

endif

# === Bootstrap ================================================================

# Targets for updating the package.mk file to the latest version.

.PHONY: package-mk

PACKAGE_MK_REPO         ?= ssh://git@stash.tail-f.com/pkg/package.mk.git
PACKAGE_MK_COMMIT       ?=
PACKAGE_MK_BUILD_DIR    ?= $(PACKAGE_DIR)/.package.mk.build
PACKAGE_MK_BUILD_CONFIG ?= $(PACKAGE_DIR)/build.config

package-mk:
	$(VERBOSE) git clone $(PACKAGE_MK_REPO) $(PACKAGE_MK_BUILD_DIR)
ifneq ($(PACKAGE_MK_COMMIT),)
	$(VERBOSE) cd $(PACKAGE_MK_BUILD_DIR) && git checkout $(PACKAGE_MK_COMMIT)
endif
	$(VERBOSE) if [ -f $(PACKAGE_MK_BUILD_CONFIG) ]; then cp $(PACKAGE_MK_BUILD_CONFIG) $(PACKAGE_MK_BUILD_DIR); fi
	$(VERBOSE) cd $(PACKAGE_MK_BUILD_DIR) && $(MAKE)
	$(VERBOSE) cp $(PACKAGE_MK_BUILD_DIR)/package.mk $(PACKAGE_DIR)/package.mk
	$(VERBOSE) rm -rf $(PACKAGE_MK_BUILD_DIR)
