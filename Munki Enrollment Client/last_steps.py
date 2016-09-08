#!/usr/bin/env python

# last_steps.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2016-08-30.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import os, shutil
# Load our modules:
import common, osx
# Import configuration:
import configuration
config_paths = configuration.Paths()

def do_last_steps():
    '''Runs last steps'''
    common.print_info("Starting last steps...")
    # Restore automatic logins if our package postinstall script disabled them:
    if os.path.exists(config_paths.AUTO_LOGIN_PASSWORD_FILE_MOVED):
        try:
            os.rename(config_paths.AUTO_LOGIN_PASSWORD_FILE_MOVED,config_paths.AUTO_LOGIN_PASSWORD_FILE)
        except OSError:
            common.print_error("Could not restore automatic login by moving %s." % config_paths.AUTO_LOGIN_PASSWORD_FILE_MOVED)
    # Remove preference key that disabled FileVault automatic logins.
    # Use defaults since the plist is probably binary.
    osx.defaults_delete('DisableFDEAutoLogin', config_paths.LOGIN_WINDOW_PREFS_FILE)
    # Cleanup files:
    paths_list = config_paths.CLEANUP_FILES_ARRAY
    paths_list.append(config_paths.THIS_LAUNCH_AGENT_PATH)
    common.delete_files_by_path(paths_list)
    if os.path.exists(config_paths.THIS_APP_PATH):
        try:
            shutil.rmtree(config_paths.THIS_APP_PATH)
        except shutil.Error:
            pass
    common.print_info("Completed last steps. Rebooting...")
    # Reboot:
    osx.reboot_system()