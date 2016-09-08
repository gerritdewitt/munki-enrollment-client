#!/usr/bin/env python

# security.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2015-08-27.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import os, base64, ssl
from OpenSSL import crypto
# Load our modules:
import common
# Import configuration:
import configuration
config_paths = configuration.Paths()

def certificate_get_pem(given_cert):
    '''Given a certificate object, get its contents as a PEM string.
        Returns the PEM or a blank string if something bad happened.'''
    try:
        cert_pem = crypto.dump_certificate(crypto.FILETYPE_PEM,given_cert)
    except crypto.Error:
        common.print_error("Could not produce PEM string from given certificate.")
        cert_pem = ''
    return cert_pem

def read_client_identity():
    '''Loads the private key and certificate objects as read
        from the client identity PEM file.  Returns a pair of objects
        (key,cert) or None if something bad happened.'''
    common.print_info("Loading identity file...")
    # Check for missing client identity:
    if not os.path.exists(config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH):
        common.print_error("No client identity file found at %s." % config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH)
        return None
    # Read and load PKI material from the client identity:
    file_object = open(config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH,'r')
    file_contents = file_object.read()
    file_object.close()
    try:
        cert = crypto.load_certificate(crypto.FILETYPE_PEM,file_contents)
    except crypto.Error:
        common.print_error("Could not read the certificate from %s." % config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH)
        cert = None
    try:
        key = crypto.load_privatekey(crypto.FILETYPE_PEM,file_contents)
    except crypto.Error:
        common.print_error("Could not read the private key from %s." % config_paths.CLIENT_IDENTITY_INSTALLED_FILE_PATH)
        key = None
    # Return PKI materials:
    return key,cert

def sign_message(given_message,given_key):
    '''Signs the (hash of the) given message with the given private key.
        Returns the base64 encoded signature or or a blank string if something bad happened.'''
    # Check for blank message:
    if not given_message:
        common.print_error("Cannot sign blank message.")
        return None
    # Sign the message by encrypting its hash with the private key:
    try:
        signature = crypto.sign(given_key,given_message,'sha512')
        signature = base64.b64encode(signature)
    except crypto.Error:
        common.print_error("Error signing message!")
        signature = ''
    # Return signature:
    return signature

def sign_message_and_get_cert_pem(given_message):
    '''Wrapper method that does the following given a message:
        1.  Calls read_client_identity() and certificate_get_pem() to get PKI materials.
        2.  Signs the given message with the private key.
        3.  Returns the signature and the certificate as a PEM string so that
            the recipient has all it needs to verify the message.'''
    # Defaults:
    client_key = None
    client_cert = None
    client_cert_pem = ''
    signature = ''
    # Load client PKI identity:
    try:
        client_key,client_cert = read_client_identity()
    except TypeError:
        pass
    if client_key and client_cert:
        client_cert_pem = certificate_get_pem(client_cert)
        # Sign message:
        signature = sign_message(given_message,client_key)
        client_key = None
    # Return:
    return signature,client_cert_pem