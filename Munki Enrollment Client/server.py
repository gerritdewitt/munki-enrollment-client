#!/usr/bin/env python

# server.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2015-08-27.
# 2016-08-19,30.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import os, base64, plistlib, xml, tarfile, urllib, ssl, time
from OpenSSL import crypto
# Load our modules:
import common
# Import configuration:
import configuration
config_paths = configuration.Paths()
config_site = configuration.Site()

def process_response_as_archive(given_response):
    '''Retrieves an array of dictionaries representing file content and attributes from
        the server's response.  The expected response is a base64-encoded TAR archive.'''
    # Default:
    tar_file = None
    member_files_array = []
    # Config profile:
    member_file_meta_dict = {}
    member_file_meta_dict['archive_file_name'] = os.path.basename(config_paths.MEC_CONFIG_PROFILE_INSTALLED_FILE_PATH)
    member_file_meta_dict['file_path'] = config_paths.MEC_CONFIG_PROFILE_INSTALLED_FILE_PATH
    member_file_meta_dict['file_contents'] = None
    member_files_array.append(member_file_meta_dict)
    # Identity:
    member_file_meta_dict = {}
    member_file_meta_dict['archive_file_name'] = os.path.basename(config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH)
    member_file_meta_dict['file_path'] = config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH
    member_file_meta_dict['file_contents'] = None
    member_files_array.append(member_file_meta_dict)
    common.print_info("Processing response for file archive.")
    # Read response data and write it to a file:
    response_contents = base64.b64decode(given_response.read())
    tar_file = open(config_paths.RECEIVED_TAR_FILE_PATH,'w')
    tar_file.write(response_contents)
    tar_file.close()
    # Read the temporary archive as a tar file:
    try:
        tar_file = tarfile.open(config_paths.RECEIVED_TAR_FILE_PATH,'r')
    except tarfile.TarError:
        common.print_error("Failed to read archive file at %s." % config_paths.RECEIVED_TAR_FILE_PATH)
    # If we made the tarfile, try extracting files from it.
    if tar_file:
        # Extract member files and store their contents in the corresponding file dict of the array:
        for m in member_files_array:
            try:
                m['file_contents'] = tar_file.extractfile(m['archive_file_name']).read()
            except KeyError:
                common.print_error("%s not in archive archive." % m['archive_file_name'])
        # Close tar file:
        tar_file.close()
    # Remove temporary tar file:
    if os.path.exists(config_paths.RECEIVED_TAR_FILE_PATH):
        os.unlink(config_paths.RECEIVED_TAR_FILE_PATH)
    # Return:
    return member_files_array

def process_response_as_xml(given_server_response):
    '''Retrieves the main dictionary from given response.  If not possible, it 
        uses a blank dictionary.  Ensures that some essential keys are set in all cases.'''
    # Default:
    response_dict = {}
    # If response is not None:
    if given_server_response:
        common.print_info("Processing response for XML content.")
        try:
            response_dict = plistlib.readPlistFromString(given_server_response.read())
            common.print_info("Response is a valid XML property list.")
        except xml.parsers.expat.ExpatError, NameError:
            common.print_error("Response is not an XML property list!")
    # Return:
    return response_dict

def send_request(given_post_vars_dict):
    '''Sends given dict of POST vars to each server in the ENROLLMENT_SERVER_URIS_ARRAY.
        Response is like a file handle.  Returns response or None if something went wrong.'''
    # Default:
    server_response = None
    try_unverified_context = False
    # Encode post_vars_dict:
    encoded_post_vars = urllib.urlencode(given_post_vars_dict)
    # Iterate over members in ENROLLMENT_SERVER_URIS_ARRAY:
    for server_uri in config_site.ENROLLMENT_SERVER_URIS_ARRAY:
        common.print_info("Sending request to server %s..." % server_uri)
        # Try a "normal" TLS connection where we verify that the
        # server's certificate was signed by a trusted CA...
        try:
            server_response = urllib.urlopen(server_uri,encoded_post_vars)
        except IOError:
            try_unverified_context = True
        # ...but our CA won't be installed in the Trust Store
        # if this system isn't yet enrolled with munki.
        # And the point of this app is to bring unmanaged
        # systems into the fold, so we have to temporarily
        # not verify the server's certificate.
        if try_unverified_context:
            try:
                ssl_context = ssl.create_default_context()
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE
                server_response = urllib.urlopen(server_uri,encoded_post_vars,context=ssl_context)
            except IOError:
                common.print_info("Invalid or no response from %s." % server_uri)
        if server_response:
            break
    # Log no response from any server:
    if not server_response:
        common.print_error("No response from any of the enrollment servers.")
    # Return:
    return server_response

def send_request_expecting_xml(given_post_vars_dict,given_expected_attributes,retry_count):
    '''Wrapper for send_request(...) and process_response_as_xml(...)
        with a retry loop.  Returns a server response dict with at least minimal attributes.'''
    # Catch invalid retry counts:
    if retry_count < 1:
        retry_count = 1
    # Request/response parsing loop:
    for i in range(0,retry_count):
        response = send_request(given_post_vars_dict)
        response_dict = process_response_as_xml(response)
        # Verify keys exist:
        keys_exist = True
        for key in given_expected_attributes:
            try:
                test = response_dict[key]
            except KeyError:
                response_dict[key] = False
                keys_exist = False
        # Break loop:
        if keys_exist:
            break
        # Next try:
        common.print_error("Waiting for XML from server.  Delaying 15 seconds (try %(attempt)s of %(retries)s)." % {"attempt":str(i+1),"retries":str(retry_count)})
        time.sleep(15)
    # Return:
    return response_dict

def test_connections():
    '''Attempts a connection to each enrollment server. Returns true
        if it can connect to at least one, false otherwise.'''
    # Default:
    test_result = False
    # Retry counts:
    retry_count = 10
    # Iterate over members in ENROLLMENT_SERVER_URIS_ARRAY:
    for server_uri in config_site.ENROLLMENT_SERVER_URIS_ARRAY:
        if test_result:
            break
        common.print_info("Testing connection to server %s..." % server_uri)
        for i in range(0,retry_count):
            # Assume unverified context:
            try:
                ssl_context = ssl.create_default_context()
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE
                server_response = urllib.urlopen(server_uri,None,context=ssl_context)
                test_result = True
                break
            except IOError:
                # Next try:
                common.print_error("Could not contact %(server)s.  Delaying 5 seconds (try %(attempt)s of %(retries)s)." % {"server":server_uri,"attempt":str(i+1),"retries":str(retry_count)})
                time.sleep(5)
    # Return:
    return test_result