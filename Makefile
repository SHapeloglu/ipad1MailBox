ARCHS = armv7
TARGET = iphone:clang:6.1:5.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iPad1MailBox

MBEDTLS_DIR = Vendor/mbedtls
MBEDTLS_SOURCES = $(wildcard $(MBEDTLS_DIR)/library/*.c)

iPad1MailBox_FILES = \
	main.m \
	Classes/IMBAppDelegate.m \
	Classes/IMBAccount.m \
	Classes/IMBAccountStore.m \
	Classes/IMBAccountSetupViewController.m \
	Classes/IMBInboxViewController.m \
	Classes/IMBComposeViewController.m \
	Classes/IMBIMAPClient.m \
	Classes/IMBMBEDTLSTransport.m \
	Classes/IMBMessageListViewController.m \
	Classes/IMBTLSDiagnostics.m \
	Classes/IMBModernTLSProbe.m \
	Classes/IMBMBEDTLSPlatform.c \
	$(MBEDTLS_SOURCES)

iPad1MailBox_FRAMEWORKS = UIKit Foundation Security CFNetwork
iPad1MailBox_CFLAGS = -fno-objc-arc -Wall -I$(MBEDTLS_DIR)/include -I$(MBEDTLS_DIR)/library
iPad1MailBox_RESOURCE_DIRS = Resources
iPad1MailBox_INSTALL_PATH = /Applications
iPad1MailBox_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

bootstrap::
	@bash scripts/bootstrap_mbedtls.sh

after-install::
	install.exec "killall iPad1MailBox 2>/dev/null || true"
