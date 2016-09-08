#!/usr/bin/env python

# common.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2015-08-27.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import logging, os

def print_info(given_message):
    logging.info(given_message)

def print_error(given_message):
    logging.error(given_message)

def delete_files_by_path(given_paths_list):
    '''Given a list of file paths, delete them.'''
    for p in given_paths_list:
        if os.path.exists(p):
            try:
                os.unlink(p)
                print_info("Removed %s." % p)
            except OSError:
                print_error("Cannot remove %s." % p)

def write_file_to_disk(given_file_dict):
    '''Given a dictionary containing at least the file path and content, write the content
        to the path.  Files written by this method have POSIX permissions
        set as follows: owner - root, group - wheel, permission bits - 0440.
        Returns true if the file was written successfully, false otherwise.'''
    # Sanity checks:
    if not given_file_dict['file_path']:
        print_error("Missing file_path attribute.")
        return False
    if not given_file_dict['file_contents']:
        print_error("Missing file_contents attribute.")
        return False
    # Write data:
    try:
        print_info("Writing %s..." % given_file_dict['archive_file_name'])
        file_object = open(given_file_dict['file_path'],'w')
        file_object.write(given_file_dict['file_contents'])
        file_object.close()
    except IOError:
        print_error("IO Error while writing %s." % given_file_dict['file_path'])
        return False
    # Set permissions:
    try:
        print_info("Setting ownership for %s..." % given_file_dict['archive_file_name'])
        os.chown(given_file_dict['file_path'],0,0)
    except OSError:
        print_error("Cannot execute chown on %s." % given_file_dict['file_path'])
        return False
    try:
        print_info("Setting POSIX mode for %s..." % given_file_dict['archive_file_name'])
        os.chmod(given_file_dict['file_path'],0440)
    except OSError:
        print_error("Cannot execute chmod on %s." % given_file_dict['file_path'])
        return False
    # Successful if we got this far:
    return True