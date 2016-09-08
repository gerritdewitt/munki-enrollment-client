#!/usr/bin/env python

# transaction_b
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2016-08-24.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

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

def do_transaction(given_group_str,given_name_str):
    '''Performs these steps:
        1. Sets the names by calling scutil,
        2. Submits a request to join this computer's manifest to a group manifest,
        3. Submits a request to record the name in the metadata of this computer's manifest.'''
    common.print_info("Starting transaction B...")
    transaction_b_dict = {}
    # Set the computer's names:
    transaction_b_dict['set_local_names'] = osx.scutil_set_names(given_name_str)
    if not transaction_b_dict['set_local_names']:
        common.print_error("scutil_set_names() returned false; recording empty name string")
        given_name_str = ''
    # Overall result starts with this value:
    transaction_b_dict['result'] = transaction_b_dict['set_local_names']
    # Perform transaction B - this should be combined into one request/response with a coordinated change to the MES
    transaction_array = []
    transaction_array.append({"command":"join-manifest","message":given_group_str,"transaction_b_key":"joined_group"})
    transaction_array.append({"command":"set-name","message":given_name_str,"transaction_b_key":"recorded_name"})
    for transaction in transaction_array:
        # Get client PKI materials:
        common.print_info("Retrieving client PKI identity...")
        client_key,client_cert = security.read_client_identity()
        client_cert_pem = security.certificate_get_pem(client_cert)
        # Sign message:
        common.print_info("Signing request...")
        signature = security.sign_message(transaction['message'],client_key)# to do: handle blank signature
        client_key = None
        # POST dict:
        common.print_info("Assembling POST variables...")
        post_vars_dict = {}
        post_vars_dict['command'] = transaction['command']
        post_vars_dict['message'] = transaction['message']
        post_vars_dict['signature'] = signature
        post_vars_dict['certificate'] = client_cert_pem
        # Expected keys in response:
        expected_response_keys = []
        # Request response:
        server_response_dict = server.send_request_expecting_xml(post_vars_dict,expected_response_keys,5)
        transaction_b_dict[transaction['transaction_b_key']] = server_response_dict['result']
        # Update truth of overall result:
        transaction_b_dict['result'] = transaction_b_dict['result'] and server_response_dict['result']
    # Add datestamp:
    transaction_b_dict['transaction_completed_date'] = datetime.utcnow()
    # Write transaction dict:
    plistlib.writePlist(transaction_b_dict, config_paths.RESULT_TRANSACTION_B_FILE_PATH)