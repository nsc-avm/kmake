.DEFAULT_GOAL := all

FORCE: ;

AT = @
ifeq ($(V),2)
QQ :=
Q  :=
else ifeq ($(V),1)
QQ := @
Q  :=
else
QQ := @
Q  := @
endif

# LTTAG, COMPILE and LINK are set in per-target rules
CC              := $(CROSS_COMPILE)$(CC)
CXX             := $(CROSS_COMPILE)$(CXX)
AR              := $(CROSS_COMPILE)$(AR)
STRIP           ?= $(CROSS_COMPILE)strip
RM              ?= rm -f
LIBTOOL         ?= libtool
INSTALL_PROGRAM ?= install

LIBTOOL_COMPILE  = $(LIBTOOL) $(if $(Q),--silent) --tag $(LTTAG) --mode=compile $(COMPILE)
LIBTOOL_LINK     = $(LIBTOOL) $(if $(Q),--silent) --tag $(LTTAG) --mode=link $(LINK)
LIBTOOL_RM       = $(LIBTOOL) $(if $(Q),--silent) --mode=clean $(RM)
LIBTOOL_INSTALL  = $(LIBTOOL) $(if $(Q),--silent) --mode=install $(INSTALL_PROGRAM)

DEFAULT_SUFFIX  ?= .c
DEFAULT_DRIVER  ?= "sh -c"

STRIPWD         ?=

# adds a traling slash to each of $(1), unless they already end with a slash
ensure_slash     = $(addsuffix /,$(patsubst %/,%,$(1)))

ifneq ($(S),)
SRCDIR := $(call ensure_slash,$(S))
endif

ifneq ($(O),)
OUTDIR := $(call ensure_slash,$(O))
endif

ifneq ($(M),)
PARTDIR := $(call ensure_slash,$(M))
endif

ifneq ($(D),)
DISTDIR := $(abspath $(D))
endif

KMAKEDIR := $(filter-out ./,$(dir $(lastword $(MAKEFILE_LIST))))

define clearvar
$(1)-y :=

endef

define clearvars
# clear each $xx-y
$(foreach v,$(prog_vars) $(lib_vars) $(data_vars),$(call clearvar,$(v)))
$(foreach v,$(test_vars) $(gen_vars),$(call clearvar,$(v)))
$(foreach v,clean distclean dist nodist submake postmake,$(call clearvar,$(v)))
$(foreach v,$(flag_names) $(aflag_names),$(call clearvar,$(v)))
$(foreach v,$(flag_names) $(aflag_names),$(call clearvar,subdir-$(v)))
extra-progs :=
extra-libs :=
extra-data :=
endef

subdir-y      ?= .
prefix        ?= /usr/local/
prefix_s      := $(call ensure_slash,$(prefix))
bindir        ?= $(prefix_s)bin
sbindir       ?= $(prefix_s)sbin
libdir        ?= $(prefix_s)lib
datadir       ?= $(prefix_s)share
sysconfdir    ?= $(prefix_s)etc
includedir    ?= $(prefix_s)include

prog_vars     := bin sbin noinstprogs
prog_vars     += $(extra-progs)
lib_vars      := libs noinstlibs
lib_vars      += $(extra-libs)
data_vars     := data sysconf headers
data_vars     += $(extra-data)
test_vars     := tests testscripts
test_vars     += $(extra-tests)
gen_vars      := byproduct
gen_vars      += $(extra-gen)
flag_names    := CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
flag_names    += $(extra-flags)
aflag_names   := INCLUDES DEPS LIBS
aflag_names   += $(extra-append-flags)
prop_names    := dir suffix driver compiler
prop_names    += $(extra-properties)

bin-dir       := $(bindir)
bin-suffix    := $(DEFAULT_SUFFIX)
sbin-dir      := $(sbindir)
sbin-suffix   := $(DEFAULT_SUFFIX)
libs-dir      := $(libdir)
libs-suffix   := $(DEFAULT_SUFFIX)
data-dir      := $(datadir)
sysconf-dir   := $(sysconfdir)
headers-dir   := $(includedir)
tests-suffix  := $(DEFAULT_SUFFIX)
tests-driver  := $(DEFAULT_DRIVER)
testscripts-driver  := $(DEFAULT_DRIVER)
noinstprogs-dir     := noinst
noinstprogs-suffix  := $(DEFAULT_SUFFIX)
noinstlibs-dir      := noinst
noinstlibs-suffix   := $(DEFAULT_SUFFIX)

all_dist      := $(KMAKEDIR)kmake.mk $(KMAKEDIR)process-subdir.mk
all_dist      += $(KMAKEDIR)gen-sed.mk $(KMAKEDIR)gen-cat.mk
all_dist      += $(KMAKEDIR)README

DISTDIR       ?= $(abspath $(or $(and $(PACKAGE_NAME),$(PACKAGE_VERSION),$(PACKAGE_NAME)-$(PACKAGE_VERSION)),dist-dir))
ifneq ($(filter-out /%,$(DISTDIR)),)
$(error DISTDIR must be absolute, actual is $(DISTDIR))
endif
DISTDIR       := $(call ensure_slash,$(DISTDIR))

# Set -I to $(OUTDIR) and $(SRCDIR), or -I. if both are empty
KM_CPPFLAGS ?= $(call uniq,-I$(or $(OUTDIR),.) -I$(or $(SRCDIR),.))
KM_CFLAGS   ?= -O2 -g
KM_CXXFLAGS ?= -O2 -g

define inc_subdir
srcdir := $(filter-out .,$(1))
objdir := $(OUTDIR)$$(srcdir)
include $(KMAKEDIR)process-subdir.mk
endef

# cpp and hdr lists based on Automake
cppexts := .c++ .cc .cpp .cxx .C
cpppats := $(addprefix %,$(cppexts))
hdrexts := .h .H .hxx .h++ .hh .hpp .inc
hdrpats := $(addprefix %,$(hdrexts))
objexts := .la .a .lo .o
objpats := $(addprefix %,$(objexts))

# reverses the list in $(1), using recursion
reverse = $(strip $(if $(word 2,$(1)),$(call reverse,$(wordlist 2,$(words $(1)),$(1)))) $(firstword $(1)))
# prepend $(dir $(1)) to $(2), except if it's './' or $(2) is an absolute path
addpath = $(patsubst $(dir $(1))/%,/%,$(addprefix $(filter-out ./,$(dir $(1))),$(2)))

varname = $(notdir $(1))

# call with $(1) = single src file, $(2) = target varname
# inserts the target varname between the path to the source file
# and its filename, and removes the extension
# e.g. $(1) = a/b/c.c $(2) = liba.a => a/b/liba.a-c
prefixtarget = $(call addpath,$(1),$(2)-$(basename $(call varname,$(1))))

getvar = $($(call varname,$(1))$(if $(2),-$(2))-y)
getprop = $($(call varname,$(1))-$(2))
# call with $(1) = target (incl. extension)
getdefsrc = $(patsubst ./%,%,$(if $(call getprop,$(1),suffix),$(basename $(1))$(call getprop,$(1),suffix)))
# Get the file list a target is made of, i.e. is $(<target>-y)
# If that list would be empty or contains just compiled files, then guess
# the single default source file.
# call with $(1) = target (incl. extension)
getysrc = $(or $(call addpath,$(call getprop,$(1),origin),$(filter-out $(objpats),$(call getvar,$(1)))),$(call getdefsrc,$(1)))
# call with $(1) = target (incl. extension)
getsrc = $(strip $(call getysrc,$(1)) $(patsubst ./%,%,$(filter-out $(objpats),$(call getvar,$(1),DEPS))))
# call with $(1) = target (incl. extension)
getsrc_c = $(strip $(filter-out $(hdrpats),$(call getsrc,$(1))))
# call with $(1) = target (incl. extension)
getdeps = $(call addpath,$(1),$(call getvar,$(1))) $(call getvar,$(1),DEPS)
# call with $(1) = target (incl. extension)
getobjdeps = $(filter $(objpats),$(call getdeps,$(1)))
# call with $(1) = target (incl. extension)
gethdrdeps = $(filter $(hdrpats),$(call getdeps,$(1)))
# call with $(1) = target (incl. extension)
getobjext = $(if $(filter %.la,$(1)),lo,o)
# call with $(1) = single src file, $(2) = target varname
getobjbase = $(call prefixtarget,$(1),$(2))
# call with $(1) = single src file, $(2) = target (incl. extension)
getobjfile = $(call getobjbase,$(1),$(call varname,$(2))).$(call getobjext,$(2))
# call with $(1) = target (incl. extension)
# Note this is returns empty if the target has no source files, since it is
# assumed the target already exists (allows to place scripts in $foo-y)
getobj = $(strip $(foreach src,$(call getsrc_c,$(1)),$(call getobjfile,$(src),$(1))) $(call getobjdeps,$(1)))
# call with $(1) = list of source files
is_cxx = $(filter $(cpppats),$(1))
# call with $(1) = target (incl. extension)
is_lib = $(filter %.la %.a,$(1))
# call with $(1) = target (incl. extension)
is_shlib = $(filter %.la %.so,$(1))
# call with $(1) = list of source files, $(2) = target (incl. extension)
# returns CXX if one or more C++ files are found, else CC
getcc = $(or $($(call varname,$(2))-compiler),$(if $(call is_cxx,$(1)),$(CXX),$(CC)))
# call with $(1) = target (incl. extension)
# returns the LTTAG flag, or CXX if one or more C++ files are found, else CC
getlttag = $(or $($(call varname,$(1))-libtooltag),$(if $(call is_cxx,$(call getsrc,$(1))),CXX),CC)
# call with $(1) = target (incl. extension)
getdepsdir = $(dir $(1)).deps/
# call with $(1) = target (incl. extension)
# Note this is returns empty if the target has no source files, since it is
# assumed the target already exists (allows to place scripts in $foo-y)
getoldcmdfile = $(call getdepsdir,$(1))$(notdir $(1)).oldcmd
getcmdfile = $(call getdepsdir,$(1))$(notdir $(1)).cmd
getdepfile = $(call getdepsdir,$(1))$(notdir $(1)).dep
getdepopt = -MD -MP -MF$(call getdepfile,$(1)) -MQ$(1)
# returns empty if $(1) and $(1) are the same
# works lists (strings containing spaces) as well
strneq = $(subst $(1),,$(2))$(subst $(2),,$(1))
# returns x if $(1) and $(1) are the same
streq = $(if $(call strneq,$(1),$(2)),,x)
# Remove duplicates without sorting
# https://stackoverflow.com/a/16151140/5126486
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))

# File locking between recipes...we do this because there is a bad
# issue in libtool, when doing link and install concurrently. Linking
# a library (.la) into another file fails if the library is installed
# (possibly with relinking) at the same time.
#
# It seems sufficient to use exclusive lock for install recipies,
# the link recipies can use shared locking and therefore run concurrently
# with respect to each other.
#
# The functions generate an flock command prefix for use within recipes,
# the remainer of the line will execute within the lock.
#
# The file list must be sorted to prevent potential deadlock between two
# recipies, also sort conviniently de-dups the list.
flock_s = $(foreach f,$(strip $(sort $(1))),flock -s $(f) )
flock_x = $(foreach f,$(strip $(sort $(1))),flock -x $(f) )

ALL_PROGS       = $(foreach v,$(prog_vars),$(all_$(v)))
ALL_LIBS        = $(foreach v,$(lib_vars),$(all_$(v)))
ALL_DATA        = $(foreach v,$(data_vars),$(all_$(v)))
ALL_GEN         = $(foreach v,$(gen_vars),$(all_$(v)))
ALL_GEN_DIRS    = $(sort $(dir $(ALL_GEN)))
ALL_TESTS       = $(foreach v,$(test_vars),$(all_$(v)))
ALL_PROGS_TESTS = $(call uniq,$(ALL_PROGS) $(ALL_TESTS))

# Prepend variable subdir-$(2)-$(1)-y and $(1)-y to $(3)-(1)-y
# e.g. prepend subdir-foo/bar-CFLAGS-y and CFLAGS-y to libfoo-CFLAGS-y
define _prepend_flags
$(3)-$(1)-y := $(subdir-$(2)-$(1)-y) $($(1)-y) $($(3)-$(1)-y)
endef
prepend_flags = $(eval $(call _prepend_flags,$(1),$(2),$(call varname,$(3))))

# inherit_{a}flags uses a $$(value ...) on purpose, so that you can
# reference $$(srcdir) in subdir-XXX-y to mean the $(srcdir) where the
# flag is effective instead of $(srcdir) of the subdir.mk where subdir-XXX-y
# is specified.
define inherit_flags
subdir-$(3)-$(1)-y := $$(value subdir-$(2)-$(1)-y) $$(value subdir-$(1)-y)
endef

define inherit_aflags
subdir-$(3)-$(1)-y := $$(value subdir-$(1)-y) $$(value subdir-$(2)-$(1)-y)
endef

# Append variable $(1)-y and subdir-$(2)-$(1)-y to $(3)-(1)-y
# e.g. append LIBS-y and subdir-foo/bar-LIBS-y to libfoo-LIBS-y
define _append_flags
$(3)-$(1)-y := $($(3)-$(1)-y) $($(1)-y) $(subdir-$(2)-$(1)-y)
endef
append_flags = $(eval $(call _append_flags,$(1),$(2),$(call varname,$(3))))

# https://stackoverflow.com/a/47927343/5126486: Insert a new-line in a Makefile $(foreach ) loop
define newline =


endef

define setvpath
$(if $(OUTDIR),$(foreach f,$(1),vpath $(f) $(OUTDIR)$(newline)))
endef

filter_partial = $(filter $(or $(addprefix $(2),$(addsuffix %,$(PARTDIR))),%),$(1))
filter_nobuild = $(foreach t,$(1),$(if $(call getsrc_c,$(t)),$(t)))
filter_noinst = $(foreach t,$(1),$(if $(filter-out noinst,$(call getprop,$(t),dir)),$(t)))

is_gen = $(strip $(filter $(ALL_GEN_DIRS),$(1)))
# Generate an -I<dir> pair for INCLUDES lists:
# -I(OUTDIR) if SRCDIR != OUTDIR *and* <dir> contains generated files
# -I(SRCDIR) always
makeinc = $(foreach d,$(1),$(and $(call strneq,$(OUTDIR),$(SRCDIR)),$(call is_gen,$(d)),-I$(OUTDIR)$(d)) -I$(SRCDIR)$(d))
getgendeps = $(foreach f,$(ALL_GEN),$(and $(filter $(dir $(f)),$(1)),$(f)))

# Call with $1: object file, $2: src file, $3: target that $1 is part of
define obj_rule
cleanfiles += $(OUTDIR)$(1)
cleanfiles += $(OUTDIR)$(call getdepfile,$(1))
cleanfiles += $(OUTDIR)$(call getcmdfile,$(1))
cleanfiles += $(OUTDIR)$(call getoldcmdfile,$(1))

$(OUTDIR)$(1): PRINTCMD = $(if $(call is_cxx,$(2)),CXX,CC)
$(OUTDIR)$(1): LTTAG = $(call getlttag,$(3))
$(OUTDIR)$(1): COMPILE = $(call getcc,$(2),$(3))
$(OUTDIR)$(1): ALL_FLAGS = $$($(3)-CPPFLAGS) $$(CPPFLAGS) $(if $(call is_cxx,$(2)),$$($(3)-CXXFLAGS) $$(CXXFLAGS),$$($(3)-CFLAGS) $(CFLAGS))
$(OUTDIR)$(1): CMD = $$(COMPILE) $$(ALL_FLAGS)
$(OUTDIR)$(1): PARTS = $(2)
$(OUTDIR)$(1): $(2)
$(OUTDIR)$(1): $(OUTDIR)$(call getcmdfile,$(1))
$(OUTDIR)$(1): | $$($(3)-oodeps)

$(call setvpath,$(1))
endef

define verify_rule
$(and $(filter-out %/,$(call getvar,$(1),INCLUDES)),$(error INCLUDES-y directories must end with a slash ($(call getprop,$(1),origin): $(filter-out %/,$(call getvar,$(1),INCLUDES)))))
endef

define prog_rule
# if a target has no objects, it is assumed to be a script that does
# not need to be built (as it cannot be built anyway)
cleanfiles += $(if $(call getobj,$(1)),$(OUTDIR)$(1))
cleanfiles += $(if $(call getobj,$(1)),$(OUTDIR)$(call getcmdfile,$(1)))
cleanfiles += $(if $(call getobj,$(1)),$(OUTDIR)$(call getoldcmdfile,$(1)))

$(OUTDIR)$(1): PRINTCMD = $(if $(call is_cxx,$(call getsrc,$(1))),CXXLD,CCLD)
$(OUTDIR)$(1): LTTAG = $(call getlttag,$(1))
$(OUTDIR)$(1): LINK = $(call getcc,$(call getsrc,$(1)),$(1))
# carefully set -rpath only for installable, shared libraries
$(OUTDIR)$(1): RPATH = $(and $(call is_shlib,$(1)),$(call filter_noinst,$(1)),-rpath $(call getprop,$(1),dir))
$(OUTDIR)$(1): ALL_FLAGS = $$(RPATH) $$($(1)-LDFLAGS) $$(LDFLAGS)
$(OUTDIR)$(1): CMD = $$(LINK) $$(ALL_FLAGS) -o $(1) $(call getobj,$(1)) $(call getvar,$(1),LIBS)
$(OUTDIR)$(1): PARTS = $(call getobj,$(1))
$(OUTDIR)$(1): $(call getobj,$(1))
$(OUTDIR)$(1): $(if $(call getobj,$(1)),$(OUTDIR)$(call getcmdfile,$(1)))

$(call varname,$(1))-obj += $(call getobj,$(1))

# Cache some per-target variables so that they don't have to be recomputed
# for each object file that make up the target.
$(1)-CPPFLAGS := $(call makeinc,$(dir $(call getprop,$(1),origin)))
$(1)-CPPFLAGS += $(KM_CPPFLAGS) $(KM_CPPFLAGS_$(if $(call is_shlib,$(1)),LIB,PROG)) $(call getvar,$(1),CPPFLAGS)
$(1)-CPPFLAGS += $(call makeinc,$(call getvar,$(1),INCLUDES))
$(1)-CFLAGS   := $(KM_CFLAGS)   $(KM_CFLAGS_$(if $(call is_shlib,$(1)),LIB,PROG))   $(call getvar,$(1),CFLAGS)
$(1)-CXXFLAGS := $(KM_CXXFLAGS) $(KM_CXXFLAGS_$(if $(call is_shlib,$(1)),LIB,PROG)) $(call getvar,$(1),CXXFLAGS)
$(1)-LDFLAGS  := $(KM_LDFLAGS)  $(KM_LDFLAGS_$(if $(call is_shlib,$(1)),LIB,PROG))  $(call getvar,$(1),LDFLAGS)
# Add headers specified via $var-y, as well as generated files that can
# be found in any of the target's source and INCLUDES directories, as order-only
# dep. This ensures the headers are genrated first (if generated anyway). If a
# .o really depends on it, a true dependency will be added by the .dep files.
$(1)-oodeps   := $(call gethdrdeps,$(1)) $(call getgendeps,$(dir $(call getprop,$(1),origin)) $(call getvar,$(1),INCLUDES))

$(foreach f,$(call getsrc_c,$(1)),$(call obj_rule,$(call getobjfile,$(f),$(1)),$(f),$(1))$(newline))
endef

define test_rule
run-test-$(call varname,$(1)): $(1)
run-test-$(call varname,$(1)): FORCE
endef

define byproduct_rule
$(OUTDIR)$(1): $(call getsrc,$(1))
endef
define byproduct_recipe
endef

define gen_rule
cleanfiles += $(addprefix $(OUTDIR),$(all_$(1)))
cleanfiles += $(addprefix $(OUTDIR),$(foreach f,$(all_$(1)),$(call getcmdfile,$(f))))
cleanfiles += $(addprefix $(OUTDIR),$(foreach f,$(all_$(1)),$(call getoldcmdfile,$(f))))

$(foreach f,$(all_$(1)),$(call $(1)_rule,$(f))$(newline))

$(call $(1)_recipe,$(all_$(1)))
endef

define inherit_props
$(foreach t,$(all_$(1)),$(foreach s,$(prop_names),$(if $($(1)-$(s)),$(call varname,$(t))-$(s) ?= $($(1)-$(s))$(newline))))
endef

define install_rule
install-$(1): $(1)
install-$(1): $(addprefix install-,$(call varname,$(call filter_noinst,$(call getobj,$(1)))))
install-$(call varname,$(1)): install-$(1)
endef

$(foreach dir,$(subdir-y),$(eval $(call inc_subdir,$(dir))))

$(foreach v,$(gen_vars) $(test_vars) $(prog_vars) $(lib_vars) $(data_vars),$(eval $(call inherit_props,$(v))))
$(foreach prog,$(call filter_nobuild,$(ALL_LIBS) $(ALL_PROGS_TESTS) $(ALL_DATA)),$(eval $(call verify_rule,$(prog))))
$(foreach prog,$(call filter_nobuild,$(ALL_LIBS) $(ALL_PROGS_TESTS)),$(eval $(call prog_rule,$(prog))))
$(foreach test,$(ALL_TESTS),$(eval $(call test_rule,$(test))))
$(foreach v,$(gen_vars),$(eval $(call gen_rule,$(v))))
$(foreach prog,$(call filter_noinst,$(ALL_LIBS) $(ALL_PROGS) $(ALL_DATA)),$(eval $(call install_rule,$(prog))))
$(foreach prog,$(ALL_LIBS) $(ALL_PROGS_TESTS) $(ALL_GEN),$(eval $(call setvpath,$(prog))))

$(eval $(call clearvars))
# replace the last value with an error indication
# when make runs recipes, srcdir would have the value of the last processed
# subdir.mk. Therefore, if a recipe is declared in a subdir.mk, the value
# of $(srcdir) is probably not what you'd expect
#
# store the current values of srcdir and objdir in target specific variables,
# e.g.
# $(objdir)myprog: SRC := $(srcdir)
# $(objdir)myprog: OBJ := $(objdir)
#    command -i $(SRC)in -o $(OBJ)out
srcdir := /do-not-use-srcdir-in-recipes/
objdir := /do-not-use-objdir-in-recipes/

changedir = $(if $(OUTDIR),cd $(OUTDIR))
stripwd = $(if $(STRIPWD),$(patsubst $(OUTDIR)%,%,$(1)),$(1))
printcmd = $(if $(Q),@printf "  %-8s%s\n" "$(1)" "$(call stripwd,$(2))")

# usually kmake targets should complete before any recursive make call:
# by definition kmake must have updated its targets before recursion
# so that those sub-Makefiles can depeend on kmake-created files
# However, the order reverses for clean targets because otherwise
# kmake would already delete files while sub-Makefiles still need them
sub_targets = all check install install-strip dist
sub_targets_pre = clean distclean

.PHONY: FORCE all libs progs data generated check clean
.PHONY: dist distclean
.PHONY: install install-progs install-libs install-data install-strip
.PHONY: submakes $(addprefix submakes-,$(sub_targets) $(sub_targets_pre))
.PHONY: postmakes $(addprefix postmakes-,$(sub_targets) $(sub_targets_pre))
.PHONY: km-all km-clean km-check km-install km-install-strip
.PHONY: km-dist km-distclean

run-test-%:
	$(Q)driver=$($(call varname,$*)-driver); name=$*; test=$<; $$driver $$test $(KM_CHECKFLAGS) ; \
	if [ $$? = 0 ]; then echo PASS: $$test; else echo FAIL: $$test; fi

# It's crucial that submakes-% depends on km-% if all_submake becomes
# empty due to the PARTDIR filter, otherwise all (etc.) has nothing to do
define submake_rule_dir
$(3)-$(1)-$(2): SUBMAKE = $$(dir $$(or $$(wildcard $(OUTDIR)$(2)Makefile),$(2)Makefile))

ifeq ($(1),dist)
$$(DISTDIR)$(2): ; $(Q)mkdir -p $$@

$(3)-dist-$(2): | $$(DISTDIR)$(2)
endif

.PHONY: $(3)-$(1)-$(2)
$(3)-$(1)-$(2):
	$(call printcmd,MAKE,$$(SUBMAKE) $(1))
	$(Q)$$(MAKE) -C $$(SUBMAKE) SRCDIR=$(abspath .)/ OUTDIR=$(abspath ./$$(OUTDIR)) SUBMAKE=$$(SUBMAKE) POSTMAKE=$$(SUBMAKE) DISTDIR=$$(DISTDIR)$(2) $(1)

endef

# all -> submakes-all -> submake-all-%
# (or all -> submakes-all if all_submake is empty)
# same for postmake
define submake_rule
.PHONY: submakes-$(1) postmakes-$(1)
$(1): submakes-$(1) km-$(1) postmakes-$(1)
submakes-$(1): $(addprefix submake-$(1)-,$(call filter_partial,$(all_submake)))
postmakes-$(1): $(addprefix postmake-$(1)-,$(call filter_partial,$(all_postmake)))

$(foreach d,$(all_submake),$(call submake_rule_dir,$(1),$(d),submake))
$(foreach d,$(all_postmake),$(call submake_rule_dir,$(1),$(d),postmake))

endef

# postmake-all-% -> km-all
define postmake_rule
$(foreach d,$(all_postmake),postmake-$(1)-$(d)): km-$(1)
endef

# km-clean -> postmakes-clean
define postmake_rule_pre
km-$(1): postmakes-$(1)
endef

# no $(newline) here!
$(foreach t,$(sub_targets) $(sub_targets_pre),$(eval $(call submake_rule,$(t))))
$(foreach t,$(sub_targets),$(eval $(call postmake_rule,$(t))))
$(foreach t,$(sub_targets_pre),$(eval $(call postmake_rule_pre,$(t))))

submakes: submakes-all
# filter_partial() restricts the selected targets to the given directories (partial build)
generated: $(call filter_partial,$(ALL_GEN))
libs: $(call filter_partial,$(ALL_LIBS))
progs: $(call filter_partial,$(ALL_PROGS))
data: $(call filter_partial,$(ALL_DATA))

km-all: generated libs progs data
km-check: generated $(addprefix run-test-,$(call varname,$(call filter_partial,$(ALL_TESTS))))
# filter_partial() restricts the deleted files to the given directories (partial build)
km-clean: cleanfiles := $(call filter_partial,$(cleanfiles),$(OUTDIR))
km-clean: all_clean := $(call filter_partial,$(all_clean))
km-clean:
	$(call printcmd,RM,$(filter-out %.dep %.cmd %.oldcmd,$(cleanfiles)) $(addprefix $(OUTDIR),$(all_clean)))
	$(Q)$(LIBTOOL_RM) $(filter-out %.dep %.cmd %.oldcmd,$(cleanfiles)) $(addprefix $(OUTDIR),$(all_clean))
	$(QQ)$(RM) $(filter %.dep %.cmd %.oldcmd,$(cleanfiles))

km-distclean: km-clean
	$(if $(all_distclean),$(call printcmd,RM,$(addprefix $(OUTDIR),$(all_distclean))))
	$(Q)$(LIBTOOL_RM) $(addprefix $(OUTDIR),$(all_distclean))

km-install: install-libs install-progs install-data
km-install-strip: LIBTOOL_INSTALL += $(STRIPOPT)
km-install-strip: install

install-libs: STRIPOPT = -s
install-libs: $(addprefix install-,$(call filter_noinst,$(call filter_partial,$(ALL_LIBS))))
install-progs: STRIPOPT = -s --strip-program=$(STRIP)
install-progs: INSTALL_PROGRAM += -m 0755
install-progs: $(addprefix install-,$(call filter_noinst,$(call filter_partial,$(ALL_PROGS))))
install-data: INSTALL_PROGRAM += -m 0644
install-data: $(addprefix install-,$(call filter_noinst,$(call filter_partial,$(ALL_DATA))))

# We have to use $(shell) for mkdir so that make executes it before other make
# (especially $(file)), as the recipe is mostly make functions.
#
# We must ensure .oldcmd is created it doesn't exist, even if any (or both) of
# CMD and OLDCMD is empty, so we write at least one character (; is appended).
# This also ensures OLDCMD is never empty unless it's not defined at all.
#
# Special handling for make -q because make functions execute regardless of -q.
$(filter %.cmd,$(cleanfiles)): $(OUTDIR)%.cmd: FORCE
ifeq ($(findstring q,$(MAKEFLAGS)),)
	$(eval L_OBJ := $(call addpath,$(subst .deps/$(notdir $*),,$*),$(notdir $*)))
	$(eval L_CMD := $(strip $(CMD));)
	$(AT)$(shell mkdir -p $(dir $@))
	$(QQ)$(if $(call strneq,$(OLDCMD),$(L_CMD)),$(file >$(OUTDIR)$*.oldcmd,$$(OUTDIR)$(L_OBJ): OLDCMD = $(L_CMD)))
	$(QQ)touch -r $(OUTDIR)$*.oldcmd $@
endif

# Filter $+/$^ by $(PARTS) since it's they are allowed to list extra files,
# e.g. via additional dependencies in make-style (e.g. "foo-bar.lo: foo.h")
# so the appropriate source file is not necessarily the first prerequisite.
# Likewise for linked binaries, the prerequisites may contain unexpected
# extra files (at least .cmd, but maybe a linker script too).
getparts = $(filter $(addprefix $(OUTDIR),$(1)) $(addprefix $(SRCDIR),$(1)),$(2))

# prevent %.o to become a fallback rule for any file
all_obj = $(filter %.o,$(cleanfiles))
$(all_obj): $(OUTDIR)%.o:
	$(call printcmd,$(PRINTCMD),$@)
	$(AT)mkdir -p $(dir $@)/.deps
	$(Q)$(COMPILE) $(call getdepopt,$@) $(ALL_FLAGS) -c -o $@ $(call getparts,$(PARTS),$^)

# prevent %.lo to become a fallback rule for any file
all_lobj = $(filter %.lo,$(cleanfiles))
$(all_lobj): $(OUTDIR)%.lo:
	$(call printcmd,$(PRINTCMD),$@)
	$(AT)mkdir -p $(dir $@)/.deps
	$(Q)$(LIBTOOL_COMPILE) $(call getdepopt,$@) $(ALL_FLAGS) -c -o $@ $(call getparts,$(PARTS),$^)

$(addprefix $(OUTDIR),$(filter %.la,$(ALL_LIBS))):
	$(call printcmd,$(PRINTCMD),$@)
	$(AT)mkdir -p $(dir $@)
	$(Q)$(call flock_s,$(filter %.la,$^))$(LIBTOOL_LINK) $(ALL_FLAGS) -o $@ $(call getparts,$(PARTS),$+) $(call getvar,$(@),LIBS)

$(addprefix $(OUTDIR),$(filter %.a,$(ALL_LIBS))):
	$(call printcmd,AR,$@)
	$(AT)mkdir -p $(dir $@)
	$(Q)$(AR) rcs $@ $(call getparts,$(PARTS),$+)

$(addprefix $(OUTDIR),$(call filter_nobuild,$(ALL_PROGS_TESTS))):
	$(call printcmd,$(PRINTCMD),$@)
	$(AT)mkdir -p $(dir $@)
	$(Q)$(call flock_s,$(filter %.la,$^))$(if $(filter %.la %.lo,$+),$(LIBTOOL_LINK),$(LINK)) $(ALL_FLAGS) -o $@ $(call getparts,$(PARTS),$+) $(call getvar,$(@),LIBS)

$(addprefix install-,$(call filter_noinst,$(ALL_LIBS) $(ALL_PROGS) $(ALL_DATA))):
	$(call printcmd,INSTALL,$<)
	$(AT)mkdir -p $(DESTDIR)$(call getprop,$<,dir)
	$(Q)$(call flock_x,$(filter %.la,$<))$(if $(filter %.la %.lo,$+),$(LIBTOOL_INSTALL),$(INSTALL_PROGRAM)) $< $(DESTDIR)$(call getprop,$<,dir)

.SUFFIXES: $(objexts) .mk .dep .cmd .oldcmd

# Gather all files list in any $var-y except if that's known to be generated
get_distfiles = $(filter-out $(ALL_GEN),$(foreach t,$(filter-out $(ALL_GEN),$(ALL_PROGS) $(ALL_LIBS) $(ALL_DATA) $(ALL_TESTS)) $(ALL_GEN),$(or $(call getysrc,$(t)),$(t))))

$(DISTDIR):
	$(Q)mkdir -p $@

# external files (outside of $(SRCDIR)) are not distributed, this
# also ensures make dist creates no filers outside of $(DISTDIR)
root := $(abspath $(or $(SRCDIR),.))
filter_external = $(foreach f,$(1),$(if $(findstring $(root),$(abspath $(f))),$(f)))

km-dist: $(filter-out $(all_nodist),$(call get_distfiles,$(i)) $(all_dist)) | $(DISTDIR)
	$(if $(Q),,$(AT)echo $(filter-out $(call filter_external,$^),$^) | xargs -r echo "skipped " >&2)
	$(call printcmd,CP,$(call filter_external,$^))
	$(Q)cp -p --parents -t $(DISTDIR) $(call filter_external,$^)


DIST_SUFFIXES := xz gz bz2
DIST_FOLDER   := $(notdir $(abspath $(DISTDIR)))

.SUFFIXES: $(addprefix .,$(DIST_SUFFIXES))

$(addprefix dist-,$(DIST_SUFFIXES)): dist-%: $(DIST_FOLDER).tar.%

$(DIST_FOLDER).tar.xz: COMP=J
$(DIST_FOLDER).tar.gz: COMP=z
$(DIST_FOLDER).tar.bz2: COMP=z
$(addprefix $(DIST_FOLDER).tar.,$(DIST_SUFFIXES)): dist
	$(call printcmd,TAR,$@)
	$(Q)rm -f $@
	$(Q)tar -c$(COMP) -f $@ $(DIST_FOLDER)

# http://make.mad-scientist.net/papers/advanced-auto-dependency-generation
# empty recipies for files that are included by make, to avoid
# re-exec make when they are updated.
$(filter %.dep,$(cleanfiles)): ;
$(filter %.oldcmd,$(cleanfiles)): ;
-include $(filter %.dep,$(cleanfiles))
-include $(filter %.oldcmd,$(cleanfiles))
