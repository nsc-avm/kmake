.DEFAULT_GOAL := all

CC = cc
CXX = c++
AR = ar
LD = cc
LIBTOOL_CC = libtool $(LIBTOOL_SILENT) --mode=compile --tag CC $(CC)
LIBTOOL_CXX = libtool $(LIBTOOL_SILENT) --mode=compile --tag CC $(CXX)
LIBTOOL_LD = libtool $(LIBTOOL_SILENT) --mode=link --tag CC $(CC)

S = @
ifneq ($(V),1)
Q = @
LIBTOOL_SILENT = --silent
endif

ifneq ($(O),)
OUTDIR := $(O)
endif

ifneq ($(OUTDIR),)
OUTDIR := $(OUTDIR)/
endif


empty :=
space := $(empty) $(empty)

subdir-y  := a/ b/ c/ s/
all_dirs  :=
all_libs  :=
all_progs :=
#define reset_vars =
#LOCAL_SRC :=
#LOCAL_CFLAGS :=
#LOCAL_LDFLAGS :=
#LOCAL_LDLIBS :=
#endef                  g

ALL_CPPFLAGS = -I.

define inc_subdir
src := $(1)
include process-subdir.mk
endef

varname = $(notdir $(basename $(1)))

getobjext = $(if $(filter %.la,$(1)),.lo,.o)
getvar = $($(call varname,$(1))-$(2))
getobj = $(or $(addprefix $(dir $(1)),$($(call varname,$(1))-y:.c=$(call getobjext,$(1)))),$(addsuffix $(call getobjext,$(1)),$(basename $(1))))
getdep = $($(call varname,$(1))-deps-y:.c=.o)
# use libtool if building a shared library
getcc = $(if $(filter %.cpp,$($(call varname,$(1))-y)),$(CXX),$(CC))
getcompile = $(if $(filter %.la,$(1)),libtool compile --tag CC $(call getcc,$(1)),$(call getcc,$(1)))

# Prepend variable $(2)-y to $(1)-(2)
# e.g. prepend CFLAGS-y to libfoo-CFLAGS
define prepend_flags
$(1)-$(2) := $($(2)-y) $($(1)-$(2))
endef

define prog_rule
cleanfiles += $(addprefix $(OUTDIR),$(call getobj,$(1)))
cleanfiles += $(OUTDIR)$(1)
$(OUTDIR)$(1): CPPFLAGS = $(call getvar,$(1),CPPFLAGS)
$(OUTDIR)$(1): CFLAGS = $(call getvar,$(1),CFLAGS)
$(OUTDIR)$(1): CXXFLAGS = $(call getvar,$(1),CXXFLAGS)
$(OUTDIR)$(1): LDFLAGS = $(call getvar,$(1),LDFLAGS)
$(OUTDIR)$(1): $(addprefix $(OUTDIR),$(call getobj,$(1)))
$(OUTDIR)$(1): $(addprefix $(OUTDIR),$(call getdep,$(1)))
endef

$(foreach dir,$(subdir-y),$(eval $(call inc_subdir,$(dir))))
$(foreach prog,$(all_progs),$(eval $(call prog_rule,$(prog))))
$(foreach lib,$(all_libs),$(eval $(call prog_rule,$(lib))))

changedir = $(if $(OUTDIR),cd $(OUTDIR))
printcmd = $(if $(Q),@printf "  %-7s%s\n" "$(1)" "$(2)")

.PHONY: all clean
all: $(addprefix $(OUTDIR),$(all_libs)) $(addprefix $(OUTDIR),$(all_progs)) ;

clean:
	for i in $(cleanfiles); do echo $$i; done | xargs rm -f

$(OUTDIR)%.o: %.c
	$(call printcmd,CC,$^)
	$(S)mkdir -p $(dir $@)
	$(Q)$(CC) $(ALL_CPPFLAGS) $(CPPFLAGS) $(ALL_CFLAGS) $(CFLAGS) -c -o $@ $^

$(OUTDIR)%.lo: %.c
	$(call printcmd,CC,$^)
	$(S)mkdir -p $(dir $@)
	$(Q)$(LIBTOOL_CC) $(ALL_CPPFLAGS) $(CPPFLAGS) $(ALL_CFLAGS) $(CLAGS) -c -o $@ $^

$(OUTDIR)%.o: %.cpp
	$(call printcmd,CC,$^)
	$(S)mkdir -p $(dir $@)
	$(Q)$(CXX) $(ALL_CPPFLAGS) $(CPPFLAGS) $(ALL_CXXFLAGS) $(CXXFLAGS) -c -o $@ $^

$(OUTDIR)%.o: %.cpp
	$(call printcmd,CC,$^)
	$(S)mkdir -p $(dir $@)
	$(Q)$(LIBTOOL_CXX) $(ALL_CPPFLAGS) $(CPPFLAGS) $(ALL_CXXFLAGS) $(CXXFLAGS) -c -o $@ $^

$(OUTDIR)%.la:
	$(call printcmd,AR,$@)
	$(S)mkdir -p $(dir $@)
	$(Q)$(LIBTOOL_LD)  -rpath /usr/lib $(ALL_LDFLAGS) $(LDFLAGS) -o $@ $^

$(OUTDIR)%.a:
	$(call printcmd,AR,$@)
	$(S)mkdir -p $(dir $@)
	$(Q)$(AR) rcs $@ $^

$(OUTDIR)%:
	$(call printcmd,LD,$@)
	$(S)mkdir -p $(dir $@)
	$(Q)$(LIBTOOL_LD) $(ALL_LDFLAGS) $(LDFLAGS) -o $@ $^

