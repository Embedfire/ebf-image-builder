all:
ifeq ($(and $(DISTRIBUTION),$(DISTRIB_RELEASE),$(DISTRIB_TYPE),$(DISTRIB_ARCH),$(FIRE_BOARD),$(LINUX),$(UBOOT),$(INSTALL_TYPE)),)
	$(call help_message)
else
	@./scripts/create_image.sh
endif

define help_message
	@echo "You should setup environment first."
	@echo "Run 'source env/setenv.sh' to setup environment."
endef

kernel:
ifeq ($(and $(DISTRIBUTION),$(DISTRIB_RELEASE),$(DISTRIB_TYPE),$(DISTRIB_ARCH),$(FIRE_BOARD),$(LINUX),$(UBOOT),$(INSTALL_TYPE)),)
	$(call help_message)
else
	@./scripts/build.sh linux
endif

uboot:
ifeq ($(and $(DISTRIBUTION),$(DISTRIB_RELEASE),$(DISTRIB_TYPE),$(DISTRIB_ARCH),$(FIRE_BOARD),$(LINUX),$(UBOOT),$(INSTALL_TYPE)),)
	$(call help_message)
else
	@./scripts/build.sh u-boot
endif

kernel-deb:
ifeq ($(and $(DISTRIBUTION),$(DISTRIB_RELEASE),$(DISTRIB_TYPE),$(DISTRIB_ARCH),$(FIRE_BOARD),$(LINUX),$(UBOOT),$(INSTALL_TYPE)),)
	$(call help_message)
else
	@./scripts/build.sh linux-deb
endif

info:
	@echo ""
	@echo "Current environment:"
	@echo "==========================================="
	@echo
	@echo "#FIRE_BOARD=${FIRE_BOARD}"
	@echo "#LINUX=${LINUX}"
	@echo "#UBOOT=${UBOOT}"
	@echo "#DISTRIBUTION=${DISTRIBUTION}"
	@echo "#DISTRIB_RELEASE=${DISTRIB_RELEASE}"
	@echo "#DISTRIB_TYPE=${DISTRIB_TYPE}"
	@echo "#DISTRIB_ARCH=${DISTRIB_ARCH}"
	@echo "#INSTALL_TYPE=${INSTALL_TYPE}"
	@echo
	@echo "==========================================="
	@echo ""

help:
	@echo "fire scripts help messages:"
	@echo "  all               - Create image according to environment."
	@echo "  kernel            - Build linux kernel."
	@echo "  uboot             - Build u-boot."
	@echo "  info              - Display current environment."

