#!/usr/bin/env python

# munki.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.
# 2016-08-19, 2016-08-22, 2016-08-24, 2016-09-07.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import subprocess, time
# Load our modules:
import common

global MSU_BINARY
MSU_BINARY = "/usr/local/munki/managedsoftwareupdate"

def managedsoftwareupdate_check_in():
    '''Calls managedsoftwareupdate --checkonly.'''
    try:
        subprocess.check_call([MSU_BINARY,
                               '--munkistatusoutput',
                               '--checkonly'])
        time.sleep(5)
        return True
    except subprocess.CalledProcessError:
        return False

def managedsoftwareupdate_install():
    '''Calls managedsoftwareupdate --installonly.'''
    try:
        subprocess.check_call([MSU_BINARY,
                               '--munkistatusoutput',
                               '--installonly'])
        time.sleep(5)
        return True
    except subprocess.CalledProcessError:
        return False