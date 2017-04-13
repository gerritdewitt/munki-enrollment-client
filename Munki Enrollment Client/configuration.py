#!/usr/bin/env python

# configuration.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2015-08-27.
# 2016-08-25, 2017-04-10.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import os

class Site(object):
    '''Object containing site specific configuration.'''
    def __init__(self):
        self.ORGANIZATION_NAME = "Your Organization"
        self.ORGANIZATION_ID_PREFIX = "org.your" # reverse DNS identifier for your organization

        self.TIME_ZONE = "America/New_York" # time zone set on first boot
        self.NTP_SERVER = "ntp.example.com" # address of NTP server
        self.NETWORK_IP_SEARCH_STR = "10.0." # first octet or octets common to your site

        self.MIN_MACOS_VERS = "10.11"

        self.ENROLLMENT_SERVER_URIS_ARRAY = []  # array of servers to try, in this order
        self.ENROLLMENT_SERVER_URIS_ARRAY.append("https://enrollment-server.example.com:8443/enroll")

        self.MEC_CONFIG_PROFILE_IDENTIFIER = "edu.gsu.config.profile.munki-enrollment"

class Paths(object):
    '''Object containing filesystem paths used by this configuration.'''
    def __init__(self):
        # Temporary files:
        self.RESULT_PREENROLLMENT_FILE_PATH = "/private/tmp/edu.gsu.mec.result.preenrollment.plist"
        self.RECEIVED_TAR_FILE_PATH = "/private/var/root/edu.gsu.mec.enrollment.materials.tar"
        self.RESULT_TRANSACTION_A_FILE_PATH = "/Library/Preferences/edu.gsu.mec.result.transaction.a.plist"
        self.RESULT_TRANSACTION_B_FILE_PATH = "/Library/Preferences/edu.gsu.mec.result.transaction.b.plist"

        # Paths referenced by the package postinstall script.
        # Used to re-enable auto login types if appropriate.
        self.AUTO_LOGIN_PASSWORD_FILE = "/private/etc/kcpasswd"
        self.AUTO_LOGIN_PASSWORD_FILE_MOVED = "/private/etc/kcpasswd.moved"
        self.LOGIN_WINDOW_PREFS_FILE = "/Library/Preferences/com.apple.loginwindow"

        # Installed paths for app and agent:
        self.THIS_APP_PATH = "/Applications/Munki Enrollment Client.app"
        self.THIS_LAUNCH_AGENT_PATH = "/Library/LaunchAgents/edu.gsu.mec.plist"

        # Profile installed by enrollment:
        # IMPORTANT:  Do not change CLIENT_IDENTITY_INSTALLED_FILE_PATH unless you make
        # server-side adjustments to ClientKeyPath and ClientCertificatePath keys written
        # to the com.apple.ManagedClient.preferences payload for ManagedInstalls in the
        # config profile!
        self.MEC_CONFIG_PROFILE_INSTALLED_FILE_PATH = "/private/var/root/client-enrollment.mobileconfig"
        # Persistent and required for munki; path referenced by ManagedInstalls:
        self.CLIENT_IDENTITY_INSTALLED_FILE_PATH = "/private/var/root/client-identity.pem"
        
        # Munki paths:
        self.MUNKI_MANAGED_INSTALLS_DIR = "/Library/Managed Installs"
        self.MUNKI_REPORT_PLIST_PATH = os.path.join(self.MUNKI_MANAGED_INSTALLS_DIR,'ManagedInstallReport.plist')
        self.MUNKI_TRIGGER_FILE = "/Users/Shared/.com.googlecode.munki.checkandinstallatstartup"

        # File list for removal when when running pre-enrollment or last steps.
        self.CLEANUP_FILES_ARRAY = []
        self.CLEANUP_FILES_ARRAY.append(self.RESULT_PREENROLLMENT_FILE_PATH)
        self.CLEANUP_FILES_ARRAY.append(self.RECEIVED_TAR_FILE_PATH)
        self.CLEANUP_FILES_ARRAY.append(self.RESULT_TRANSACTION_A_FILE_PATH)
        self.CLEANUP_FILES_ARRAY.append(self.RESULT_TRANSACTION_B_FILE_PATH)
        self.CLEANUP_FILES_ARRAY.append(self.MUNKI_TRIGGER_FILE)

