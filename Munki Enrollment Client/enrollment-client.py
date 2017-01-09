#!/usr/bin/env python

# Munki Enrollment Client
# A client side script for enrolling Mac systems for management via Munki.
# Designed for use in conjunction with the enrollment server web app.

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.
# 2016-08-24,30, 2017-01-04/9.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import sys
# Load our modules:
import common
import osx
import security
import server
import munki
import preenrollment
import transaction_a
import transaction_b
import last_steps

def main():
    '''Main method.'''
    # Output mode:
    global COMMAND_LINE_MODE
    COMMAND_LINE_MODE = False
    should_show_help = True

    # Verbose mode?
    if "--verbose" in sys.argv:
        COMMAND_LINE_MODE = True
        common.print_info("Verbose mode enabled.")
    # PE action:
    if "do-pre-enrollment" in sys.argv:
        should_show_help = False
        preenrollment.do_preenrollment()
    # Last steps action:
    elif "last-steps" in sys.argv:
        should_show_help = False
        last_steps.do_last_steps()
    # Transaction A (this performs enrollment if necessary):
    elif "transaction-a" in sys.argv:
        should_show_help = False
        transaction_a.do_transaction()
   # Run Munki check-in:
    elif "run-munki-check" in sys.argv:
        should_show_help = False
        munki.managedsoftwareupdate_check_in()
    # Run Munki install:
    elif "run-munki-install" in sys.argv:
        should_show_help = False
        munki.managedsoftwareupdate_install()
    # Transaction B (group join and naming):
    else:
        found_transaction_arg = False
        desired_group = None
        desired_name = None
        for given_arg in sys.argv:
            if "transaction-b" in given_arg:
                found_transaction_arg = True
            if "group=" in given_arg:
                try:
                    desired_group = given_arg.split('=')[1]
                except IndexError:
                    pass
            if "name=" in given_arg:
                try:
                    desired_name = given_arg.split('=')[1]
                except IndexError:
                    pass
        if found_transaction_arg and desired_group and desired_name:
            should_show_help = False
            transaction_b.do_transaction(desired_group,desired_name)
    # Help?
    if should_show_help:
        show_help()

def show_help():
    print '''Munki Enrollment Client
USAGE: enrollment-client.py [--verbose] command
    where command is one of:
    * do-pre-enrollment: Performs a set of first boot configuration and basic status checks.
    * last-steps: Performs a set of final steps, including removing the Munki Enrollment Client and its launch agent.
    * run-munki-check: Runs managedsoftwareupdate in its check-only mode.
    * run-munki-install: Runs managedsoftwareupdate in its install-only mode.
    * transaction-a: Attempts to interrogate the Munki Enrollment Server for details about this computer's manifest, authenticating with existing PKI identity materials if present.  If communication was successful and a computer manifest for this system (as identified by its serial number) is present on the server, this tool provides details from the manifest.  (These details include the computer's previously used name and group, which is how the Cocoa app is able to offer the technician the opportunity to use those details again.)  If a valid computer manifest cannot be found or if authentication failed, this tool assumes the system is not enrolled:  In this case, it sends an enrollment request to the Munki Enrollment Server to create a manifest and PKI identity for this computer. The PKI identity and a configuration profile for Munki are returned and processed, and transaction A is run a second time (so that details about the computer's manifest may be obtained).
    * transaction-b: Sets the computer's names with scutil, then records the group and name selections with the MES.
    Requires the name and group be specified like this:
       enrollment-client.py transaction-b name=Name group=Group
    The MES records the name in the computer's manifest metadata, and it adds the chosen group to the list
    of included manifests in the computer's manifest.

    This program must be run as root.'''


# Launch:
if __name__ == "__main__":
    try:
        main()
    except:
        common.print_error("Generic error.  Could not complete the enrollment request.")
