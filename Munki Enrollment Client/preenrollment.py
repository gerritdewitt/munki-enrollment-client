#!/usr/bin/env python

# preenrollment.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2016-08-24.
# 2017-04-10.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import plistlib, xml
from distutils.version import LooseVersion
# Load our modules:
import common
import osx
import server
# Import configuration:
import configuration
config_paths = configuration.Paths()
config_site = configuration.Site()

def do_preenrollment():
    '''Runs various "pre-enrollment" tasks.'''
    common.print_info("Starting pre-enrollment...")
    # Create result dict:
    result_dict = {}
    result_dict['result'] = False
    result_dict['os_version'] = {"min_macos":config_site.MIN_MACOS_VERS, "valid":False}
    result_dict['network_status'] = {"network_available":False, "gigabit_available":False, "ethernet_interfaces":[], "gigabit_ethernet_interfaces":[]}
    result_dict['client_serial_valid'] = False
    result_dict['computer_name_suffix'] = ""
    # Start fresh:
    common.delete_files_by_path(config_paths.CLEANUP_FILES_ARRAY)
    # macOS version check:
    result_dict['os_version']['current_macos'] = osx.platform_get_system_version()
    if LooseVersion(result_dict['os_version']['current_macos']) >= LooseVersion(result_dict['os_version']['min_macos']):
        result_dict['os_version']['valid'] = True
    # Detect network hardware:
    osx.networksetup_detect_network_hardware()
    # Get list of Ethernet interfaces:
    ethernet_interfaces = osx.system_profiler_get_ethernets()
    # Test network connection:
    if ethernet_interfaces and server.test_connections():
        result_dict['network_status']['ethernet_interfaces'] = ethernet_interfaces
        result_dict['network_status']['network_available'] = True
    # Get list of gigabit Ethernet interfaces:
    for eth_dict in ethernet_interfaces:
        if '1000' in eth_dict['media']: # If gigabit...
            for ip_address in eth_dict['ip_addresses']:
                if config_site.NETWORK_IP_SEARCH_STR in ip_address: # ...and on our network:
                    result_dict['network_status']['gigabit_ethernet_interfaces'].append(eth_dict['identifier'])
                    break
    if result_dict['network_status']['gigabit_ethernet_interfaces']:
        result_dict['network_status']['gigabit_available'] = True
    # Get the serial number:
    client_serial = osx.system_profiler_fetch_serial()
    # New style serial:
    if len(client_serial) == 12:
        # Use digits [4,8] (4 through 8), counting from 1, inclusive;
        # digits [3,7] counting from zero, inclusive;
        # [3,8) in left-sided Python range:
        result_dict['computer_name_suffix'] = client_serial[3:8]
        result_dict['client_serial_valid'] = True
    # Old style serial:
    elif len(client_serial) == 11:
        # Use digits [3,7] (3 through 7), counting from 1, inclusive;
        # digits [2,6] counting from zero, inclusive;
        # [2,7) in left-sided Python range:
        result_dict['computer_name_suffix'] = client_serial[2:7]
        result_dict['client_serial_valid'] = True
    # Compute result:
    if result_dict['os_version']['valid'] and result_dict['client_serial_valid'] and result_dict['network_status']['network_available']:
        result_dict['result'] = True
    plistlib.writePlist(result_dict, config_paths.RESULT_PREENROLLMENT_FILE_PATH)
    # Make adjustments only if it is likely we can proceed:
    if result_dict['result']:
        # Set time:
        osx.systemsetup_set_time_zone(config_site.TIME_ZONE)
        osx.ntpdate(config_site.NTP_SERVER)
        # Prevent sleep starting now:
        osx.caffeinate_system()
    common.print_info("Completed pre-enrollment.")
