ARCHS = armv7
TARGET = iphone:clang:6.1:5.1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iPad1MailBox

iPad1MailBox_FILES = \
	main.m \
	Classes/IMBAppDelegate.m \
	Classes/IMBAccount.m \
	Classes/IMBAccountStore.m \
	Classes/IMBAccountSetupViewController.m \
	Classes/IMBInboxViewController.m \
	Classes/IMBComposeViewController.m \
	Classes/IMBIMAPClient.m \
	Classes/IMBMessageListViewController.m \
	Classes/IMBTLSDiagnostics.m

iPad1MailBox_FRAMEWORKS = UIKit Foundation Security CFNetwork
iPad1MailBox_CFLAGS = -fno-objc-arc -Wall
iPad1MailBox_RESOURCE_DIRS = Resources
iPad1MailBox_INSTALL_PATH = /Applications
iPad1MailBox_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall iPad1MailBox 2>/dev/null || true"
