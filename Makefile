include $(TOPDIR)/rules.mk

PKG_NAME:=4g-lte-keepalive
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=4G-LTE-KeepAlive contributors
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/4g-lte-keepalive
  SECTION:=net
  CATEGORY:=Network
  TITLE:=4G LTE KeepAlive - QMI/MBIM 4G Recovery Service
  DEPENDS:=+uqmi
  PKGARCH:=all
endef

define Package/4g-lte-keepalive/description
  Monitors 4G connection via QMI/MBIM and automatically revives
  the connection when ping loss exceeds 60%. Includes automatic
  router reboot after 3 failed recovery cycles.
endef

define Build/Compile
endef

define Package/4g-lte-keepalive/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./src/lte-keepalive.sh $(1)/usr/bin/lte-keepalive
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./src/lte-keepalive.init $(1)/etc/init.d/lte-keepalive
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./src/lte-keepalive.uci $(1)/etc/config/lte-keepalive
endef

define Package/4g-lte-keepalive/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	/etc/init.d/lte-keepalive enable
	/etc/init.d/lte-keepalive start
}
endef

$(eval $(call BuildPackage,4g-lte-keepalive))
