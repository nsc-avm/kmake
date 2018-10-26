subdir-y :=

# SRCDIR points to the root directory (where kmake.mk is) if including
# kmake.mk in a build-directory makefile (not using O=$builddir).
# srcdir points to the directory of each subdir.mk and is relative
# SRCDIR.
include $(SRCDIR)$(srcdir)subdir.mk

# remember custom vars for installation
prog_vars   := $(sort $(prog_vars) $(extra-progs))
lib_vars    := $(sort $(lib_vars) $(extra-libs))
data_vars   := $(sort $(data_vars) $(extra-data))
test_vars   := $(sort $(test_vars) $(extra-tests))
gen_vars    := $(sort $(gen_vars) $(extra-gen))
flag_names  := $(sort $(flag_names) $(extra-flags))
aflag_names := $(sort $(aflag_names) $(extra-append-flags))

# There is only a single tests variable, and the programs need not be installed
$(foreach v,$(prog_vars) $(lib_vars) $(data_vars) $(gen_vars) $(test_vars) clean submake,\
	$(if $($(v)-y),$(eval all_$(v) += $(addprefix $(srcdir),$($(v)-y)))))
$(foreach v,$(prog_vars) $(lib_vars) $(data_vars),\
	$(if $($(v)-dir),,$(error Must specify $(v)-dir in $(srcdir)subdir.mk)))

# inherit $t-$property from vars unless explicitly set
$(foreach s,$(prop_names),\
	$(foreach v,$(gen_vars) $(test_vars) $(prog_vars) $(lib_vars) $(data_vars),\
		$(foreach t,$($(v)-y),$(if $($(v)-$(s)),$(eval $(t)-$(s) ?= $($(v)-$(s)))))))

# prepends CFLAGS-y to $(bin)-CFLAGS-y (and friends)
$(foreach flag,$(flag_names),\
	$(foreach v,$(prog_vars) $(lib_vars) $(gen_vars) $(test_vars),\
		$(foreach bin,$($(v)-y),$(call prepend_flags,$(bin),$(flag)))))

# Like above, except DEPS and LIBS should be appended
# per-directory -l options should occur last (as LIBS usually holds
# system libraries). Likewise, DEPS must occur before LIBS.
$(foreach flag,$(aflag_names),\
	$(foreach v,$(prog_vars) $(lib_vars) $(gen_vars) $(test_vars),\
		$(foreach bin,$($(v)-y),$(call append_flags,$(bin),$(flag)))))

$(eval $(call clearvars))

$(foreach dir,$(addprefix $(srcdir),$(subdir-y)),$(eval $(call inc_subdir,$(dir))))
