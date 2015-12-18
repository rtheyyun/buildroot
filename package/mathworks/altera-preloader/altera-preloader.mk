################################################################################
#
# altera preloader
#
################################################################################

ALTERA_PRELOADER_VERSION = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_EDS_VERSION))
ALTERA_PRELOADER_BOARD_NAME = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_BOARDNAME))
ALTERA_PRELOADER_LICENSE = GPLv2+
ALTERA_PRELOADER_EDS_DIR = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_EDS_INSTALLATION))
ALTERA_PRELOADER_UBOOT_CUSTOM_TARBALL = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_UBOOT_CUSTOM_TARBALL))
ifeq ($(ALTERA_PRELOADER_UBOOT_CUSTOM_TARBALL),)
ALTERA_PRELOADER_TARBALL = $(ALTERA_PRELOADER_EDS_DIR)/host_tools/altera/preloader/uboot-socfpga.tar.gz
else
ALTERA_PRELOADER_TARBALL = $(ALTERA_PRELOADER_UBOOT_CUSTOM_TARBALL)
endif
ALTERA_PRELOADER_SITE = $(dir $(ALTERA_PRELOADER_TARBALL))
ALTERA_PRELOADER_SOURCE = $(notdir $(ALTERA_PRELOADER_TARBALL))
ALTERA_PRELOADER_SITE_METHOD = file
ALTERA_PRELOADER_SRC_DIR := $(patsubst %.tar.gz,%,$(ALTERA_PRELOADER_SOURCE))
ALTERA_PRELOADER_LICENSE_FILES = COPYING

ALTERA_PRELOADER_INSTALL_TARGET = NO
ALTERA_PRELOADER_INSTALL_IMAGES = YES
ALTERA_PRELOADER_INSTALL_STAGING = YES

ALTERA_PRELOADER_STATING_TARGET = usr/share/altera-preloader

ALTERA_PRELOADER_ARCH = $(KERNEL_ARCH)

ALTERA_PRELOADER_MAKE_OPTS += \
	CROSS_COMPILE="$(CCACHE) $(TARGET_CROSS)" \
	ARCH=$(ALTERA_PRELOADER_ARCH)


ALTERA_PRELOADER_MAKE_TGT = spl/u-boot-spl.bin
ALTERA_PRELOADER_SPL_BIN = $(ALTERA_PRELOADER_SRC_DIR)/$(ALTERA_PRELOADER_MAKE_TGT)
ALTERA_PRELOADER_PRELOADER_BIN = $(ALTERA_PRELOADER_SRC_DIR)/preloader-mkpimage.bin
ALTERA_PRELOADER_MKPIMAGE = $(ALTERA_PRELOADER_EDS_DIR)/host_tools/altera/mkpimage/mkpimage
ALTERA_PRELOADER_BSP_TOOLS = $(ALTERA_PRELOADER_EDS_DIR)/host_tools/altera/preloadergen
ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR))
ALTERA_PRELOADER_BSP_OPTIONS = $(call qstrip,$(BR2_PACKAGE_ALTERA_PRELOADER_BSP_OPTIONS))

define ALTERA_PRELOADER_EXTRACT_CMDS
    rm -rf $(@D)/$(ALTERA_PRELOADER_SRC_DIR)
    tar -C $(@D) -xf $(DL_DIR)/$(ALTERA_PRELOADER_SOURCE)
    chmod -R 755 $(@D)/$(ALTERA_PRELOADER_SRC_DIR)
endef

# Generate the BSP based on the handoff files
define ALTERA_PRELOADER_GENERATE_BSP
     $(ALTERA_PRELOADER_BSP_TOOLS)/bsp-create-settings \
        --type spl --bsp-dir $(@D)/bsp \
        --settings $(@D)/bsp/settings.bsp \
        --preloader-settings-dir $(ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR) \
        $(ALTERA_PRELOADER_BSP_OPTIONS)
endef

define ALTERA_PRELOADER_UPDATE_FILES
    @echo ">>> Copying handoff files from $(ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR)"
    cp -R -f $(ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR)/* $(@D)/$(ALTERA_PRELOADER_SRC_DIR)/board/altera/socfpga/sdram

    @echo ">>> Copying generated files from $(ALTERA_PRELOADER_EDS_GENERATED_DIR)"
    cp -R -f $(@D)/bsp/generated/* $(@D)/$(ALTERA_PRELOADER_SRC_DIR)/board/altera/socfpga
endef

#ALTERA_PRELOADER_PRE_CONFIGURE_HOOKS += ALTERA_PRELOADER_GENERATE_BSP

define ALTERA_PRELOADER_CONFIGURE_CMDS
    $(ALTERA_PRELOADER_GENERATE_BSP)
    $(ALTERA_PRELOADER_UPDATE_FILES)
	$(TARGET_CONFIGURE_OPTS) 	\
		$(MAKE) -C $(@D)/$(ALTERA_PRELOADER_SRC_DIR) $(ALTERA_PRELOADER_MAKE_OPTS)		\
		$(ALTERA_PRELOADER_BOARD_NAME)_config
endef

define ALTERA_PRELOADER_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) 	\
		$(MAKE) -C $(@D)/$(ALTERA_PRELOADER_SRC_DIR) $(ALTERA_PRELOADER_MAKE_OPTS) 		\
		$(ALTERA_PRELOADER_MAKE_TGT)
    $(ALTERA_PRELOADER_MKPIMAGE) --header-version 0 \
        -o $(@D)/$(ALTERA_PRELOADER_PRELOADER_BIN) $(@D)/$(ALTERA_PRELOADER_SPL_BIN) \
        $(@D)/$(ALTERA_PRELOADER_SPL_BIN) $(@D)/$(ALTERA_PRELOADER_SPL_BIN) \
        $(@D)/$(ALTERA_PRELOADER_SPL_BIN)

endef

define ALTERA_PRELOADER_INSTALL_STAGING_CMDS
    mkdir -p $(STAGING_DIR)/$(ALTERA_PRELOADER_STATING_TARGET)
	cp -Rf $(@D)/bsp/generated $(STAGING_DIR)/$(ALTERA_PRELOADER_STATING_TARGET)/
    mkdir -p $(STAGING_DIR)/$(ALTERA_PRELOADER_STATING_TARGET)/handoff
    cp -Rf $(ALTERA_PRELOADER_QUARTUS_HANDOFF_DIR)/* $(STAGING_DIR)/$(ALTERA_PRELOADER_STATING_TARGET)/handoff
endef

define ALTERA_PRELOADER_INSTALL_IMAGES_CMDS
	cp -dpf $(@D)/$(ALTERA_PRELOADER_PRELOADER_BIN) $(BINARIES_DIR)/
endef

$(eval $(generic-package))
