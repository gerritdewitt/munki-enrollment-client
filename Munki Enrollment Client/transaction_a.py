#!/usr/bin/env python

# transaction_a
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2016-08-24.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import os, plistlib, xml, shutil
import plistlib, xml
from datetime import datetime
# Load our module:
import common
import osx
import security
import server
# Import configuration:
import configuration
config_paths = configuration.Paths()
config_site = configuration.Site()

def enroll_only():
    '''Sends request to server, receives and installs materials.
        Returns true or false.'''
    common.print_info("enroll_only(): Starting...")
    # Get the serial number:
    client_serial = osx.system_profiler_fetch_serial()
    common.print_info("enroll_only(): Hardware serial number is %s." % client_serial)
    # Send enrollment request:
    common.print_info("enroll_only(): Assembling POST variables...")
    post_vars_dict = {}
    post_vars_dict['command'] = "request-enrollment"
    post_vars_dict['message'] = client_serial
    server_response = server.send_request(post_vars_dict)
    server_response_files_array = server.process_response_as_archive(server_response)
    # Write files to disk:
    files_written = False
    writes_result_array = []
    for file_meta_dict in server_response_files_array:
        write_result = common.write_file_to_disk(file_meta_dict)
        writes_result_array.append(write_result)
    if ((len(server_response_files_array) > 0) and (len(writes_result_array) > 0) and not (False in writes_result_array)):
        files_written = True
    # Remove previous munki config profile:
    common.print_info("enroll_only(): Removing config profile if necessary...")
    osx.profiles_remove(config_site.MEC_CONFIG_PROFILE_IDENTIFIER)
    # Install config profile:
    common.print_info("enroll_only(): Installing config profile...")
    profile_installed = osx.profiles_install(config_paths.MEC_CONFIG_PROFILE_INSTALLED_FILE_PATH)
    # Clear previous Munki Managed Installs directory:
    if os.path.exists(config_paths.MUNKI_MANAGED_INSTALLS_DIR) and profile_installed and files_written:
        common.print_info("enroll_only(): Removing previous Munki Managed Installs directory...")
        shutil.rmtree(config_paths.MUNKI_MANAGED_INSTALLS_DIR)
    # Assemble result.
    enrollment_completed = profile_installed and files_written
    common.print_info("enroll_only(): Completed.")
    return enrollment_completed

def do_transaction_only():
    '''Main transaction method.
        Returns dictionary describing results.'''
    common.print_info("do_transaction_only(): Starting...")
    # Create result dict:
    result_dict = {}
    # Message:
    message = "transaction-a"
    # Get signature and cert:
    signature,client_cert_pem = security.sign_message_and_get_cert_pem(message)
    # Catch blank signature and cert; fail transaction A:
    if not (signature and client_cert_pem):
        result_dict['result'] = False
        common.print_error("do_transaction_only(): Could not sign message for transaction A.")
        return result_dict
    # POST dict:
    common.print_info("do_transaction_only(): Assembling POST variables...")
    post_vars_dict = {}
    post_vars_dict['command'] = message
    post_vars_dict['message'] = message
    post_vars_dict['signature'] = signature
    post_vars_dict['certificate'] = client_cert_pem
    # Expected keys in response:
    expected_response_keys = ['computer_manifest','group_manifests_array']
    # Request response:
    server_response_dict = server.send_request_expecting_xml(post_vars_dict,expected_response_keys,2)
    common.print_info("do_transaction_only(): Received server response.")
    # COMPUTER DETAILS:
    # Catch false type; expect dict:
    if not server_response_dict['computer_manifest']:
        common.print_error("do_transaction_only(): Server did not return any computer manifest details for this system!")
        server_response_dict['computer_manifest'] = {}
    # Catch missing keys:
    try:
        test = server_response_dict['computer_manifest']['exists']
    except KeyError:
        server_response_dict['computer_manifest']['exists'] = False
    try:
        test = server_response_dict['computer_manifest']['name']
    except KeyError:
        server_response_dict['computer_manifest']['name'] = ''
    try:
        test = server_response_dict['computer_manifest']['group']
    except KeyError:
        server_response_dict['computer_manifest']['group'] = ''
    # If the computer manifest exists, check to see if it has a non-blank name and a non-blank group.
    # This is used by the UI to give the tech the opportunity to use the same name and group.
    # Future improvement: Make sure the group exists!  In other words, if a group is deleted, we don't want people
    # joining it thinking it's valid.
    # Assume false.
    server_response_dict['computer_manifest']['has_name_and_group'] = False
    if server_response_dict['computer_manifest']['exists'] and server_response_dict['computer_manifest']['name'] and server_response_dict['computer_manifest']['group']:
        server_response_dict['computer_manifest']['has_name_and_group'] = True
    # Print:
    if not server_response_dict['computer_manifest']['exists']:
        common.print_info("do_transaction_only(): This appears to be a new enrollment.")
    else:
        common.print_info("do_transaction_only(): A manifest for this Mac already exists on the server.")
        common.print_info("      Computer Name: %s" % server_response_dict['computer_manifest']['name'])
        common.print_info("     Assigned Group: %s" % server_response_dict['computer_manifest']['group'])
    # Add to result:
    result_dict['computer_manifest'] = server_response_dict['computer_manifest']
    # GROUP MANIFEST LISTING:
    # List manifests; assume false:
    group_manifests_available = False
    # Catch false type; swap with empty array:
    if not server_response_dict['group_manifests_array']:
        common.print_error("do_transaction_only()(): Server did not return any group manifest data!")
        server_response_dict['group_manifests_array'] = []
    if len(server_response_dict['group_manifests_array']) > 0:
        common.print_info("The following computer groups are available:")
        group_manifests_available = True
        for group_details_dict in server_response_dict['group_manifests_array']:
            # Look up the group display name for any existing computer manifest's group.
            # Used by the UI later on.  The ['computer_manifest']['group'] key is not the display name.
            if server_response_dict['computer_manifest']['group']  == group_details_dict['name']:
                server_response_dict['computer_manifest']['group_display_name'] = group_details_dict['display_name']
            # Print groups:
            common.print_info("      Group Name: %s" % group_details_dict['name'])
            common.print_info("          Display Name: %s" % group_details_dict['display_name'])
            common.print_info("          Description: %s" % group_details_dict['description'])
    # Add to result:
    result_dict['group_manifests_available'] = group_manifests_available
    result_dict['group_manifests_array'] = server_response_dict['group_manifests_array']
    # Overall:
    result_dict['result'] = group_manifests_available and server_response_dict['computer_manifest']['exists']
    common.print_info("do_transaction_only(): Completed.")
    return result_dict

def do_transaction():
    '''Wrapping method.
    Try just transaction A; if that fails, then enroll and
    then do transaction A again.'''
    enrollment_required = False
    enrollment_completed = False
    transaction_a_result_dict = do_transaction_only()
    if not transaction_a_result_dict['result']:
        enrollment_required = True
        enrollment_completed = enroll_only()
        transaction_a_result_dict = do_transaction_only()
    # Add enrollment_status dict to transaction A dict:
    transaction_a_result_dict['enrollment_status'] = {"required":enrollment_required,
                                                    "completed":enrollment_completed,
                                                    "result":(not enrollment_required) or enrollment_completed}
    transaction_a_result_dict['transaction_completed_date'] = datetime.utcnow()
    # Write result:
    plistlib.writePlist(transaction_a_result_dict, config_paths.RESULT_TRANSACTION_A_FILE_PATH)
