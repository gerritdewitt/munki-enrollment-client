#!/usr/bin/env python

# osx.py
# Munki Enrollment Client

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file separated 2015-08-27.
# 2016-08-19, 2017-01-09.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

import plistlib, xml, subprocess, platform, pwd, time
# Load our modules:
import common

def defaults_delete(given_key, given_plist):
    '''Deletes given key from given plist by calling defaults
        Useful for binary plists.'''
    try:
        subprocess.check_call(['/usr/bin/defaults',
                               'delete',
                               given_plist,
                               given_key])
        common.print_info("Deleted %(k)s from %(p)s." % {"k":given_key,"p":given_plist})
        return True
    except subprocess.CalledProcessError:
        common.print_error("Error clearing key %(k)s from %(p)s." % {"k":given_key,"p":given_plist})
        return False

def ntpdate(given_server):
    '''Updates clock via NTP.'''
    try:
        subprocess.check_call(['/usr/sbin/ntpdate',
                               '-u',
                               given_server])
        common.print_info("Ran ntpdate to update the clock: %s" % given_server)
        return True
    except subprocess.CalledProcessError:
        common.print_error("Error while running ntpdate to update the clock.")
        return False

def systemsetup_set_time_zone(given_locale):
    '''Sets the time zone to the given locale using /usr/sbin/systemsetup.'''
    try:
        subprocess.check_call(['/usr/sbin/systemsetup',
                           '-settimezone',
                           given_locale])
        common.print_info("Ran systemsetup to set the time zone: %s" % given_locale)
        return True
    except subprocess.CalledProcessError:
        common.print_error("Error while running systemsetup to set the time zone.")
        return False

def networksetup_detect_network_hardware():
    '''Detects network hardware via /usr/sbin/networksetup.'''
    try:
        subprocess.check_call(['/usr/sbin/networksetup',
                               '-detectnewhardware'])
        common.print_info("Ran networksetup to detect network hardware.")
        time.sleep(10) # Let the system get IP addresses...
        return True
    except subprocess.CalledProcessError:
        common.print_error("Error while running networksetup to detect network hardware.")
        return False

def caffeinate_system():
    '''Prohibits system sleep by starting /usr/bin/caffeinate.'''
    try:
        subprocess.Popen(['/usr/bin/caffeinate',
                               '-d',
                               '-i',
                               '-m',
                               '-s'])
        common.print_info("Started caffeination.")
        return True
    except subprocess.CalledProcessError:
        common.print_error("Could not start caffeination.")
        return False

def reboot_system():
    '''Reboots the Mac by running /sbin/shutdown -r now.'''
    try:
        subprocess.Popen(['/sbin/shutdown',
                               '-r',
                               'now'])
        return True
    except subprocess.CalledProcessError:
        common.print_error("Could not run: /sbin/shutdown -r now")
        return False

def platform_get_system_version():
    '''Returns major and minor versions: 10.major.minor.'''
    version_str = platform.mac_ver()[0]
    version_list = version_str.split('.')
    try:
        return int(version_list[1]), int(version_list[2])
    except IndexError:
        return 0,0

def nonsystem_users_exist():
    '''Returns true if non-system accounts have been created.'''
    users_exist = False
    all_users_array = pwd.getpwall()
    for the_user in all_users_array:
        if int(the_user.pw_uid) > 500:
            users_exist = True
            break
    return users_exist

def dseditgroup_make_admin_user(given_account_dict):
    '''Calls dseditgroup to add the given user to the local admin group.'''
    # Catch missing attributes:
    try:
        test = given_account_dict['RecordName']
    except KeyError:
        common.print_error("Missing RecordName for user account.")
        return False
    # Try to add:
    try:
        subprocess.check_call(['/usr/sbin/dseditgroup',
                               '-o',
                               'edit',
                               '-a',
                               given_account_dict['RecordName'],
                               '-t',
                               'user',
                               'admin'])
        common.print_info("Added %s to the admin group." % given_account_dict['RecordName'])
        return True
    except subprocess.CalledProcessError:
        common.print_error("Could not add %s to the admin group." % given_account_dict['RecordName'])
        return False

def dscl_create_account(given_account_dict):
    '''Creates a user account with the given attributes by calling dscl.'''
    # Catch missing attributes:
    try:
        test = given_account_dict['RecordName']
        test = given_account_dict['Password']
        test = given_account_dict['UniqueID']
        test = given_account_dict['PrimaryGroupID']
        test = given_account_dict['NFSHomeDirectory']
    except KeyError:
        common.print_error("Missing essential attributes for a user account.")
        return False
    # Run dscl to create the "path":
    try:
        common.print_info("Creating %s via dscl..." % given_account_dict['RecordName'])
        subprocess.check_call(['/usr/bin/dscl',
                               '/Local/Default',
                               'create',
                               '/Users/%s' % given_account_dict['RecordName']])
    except subprocess.CalledProcessError:
        common.print_error("Could not create %s via dscl." % given_account_dict['RecordName'])
        return False
    # Run dscl to set the password:
    try:
        common.print_info("Setting password for %s..." % given_account_dict['RecordName'])
        subprocess.check_call(['/usr/bin/dscl',
                               '/Local/Default',
                               'passwd',
                               '/Users/%s' % given_account_dict['RecordName'],
                               given_account_dict['Password']])
    except subprocess.CalledProcessError:
        common.print_error("Could not set password for %s." % given_account_dict['RecordName'])
        return False
    # Add other attributes:
    for attribute,value in given_account_dict.iteritems():
        if attribute not in ['RecordName','Password']:
            try:
                common.print_info("Setting %(attribute)s to %(value)s..." % {'attribute':attribute,'value':value})
                subprocess.check_call(['/usr/bin/dscl',
                                       '/Local/Default',
                                       'create',
                                       '/Users/%s' % given_account_dict['RecordName'],
                                       attribute,
                                       value])
            except subprocess.CalledProcessError:
                common.print_error("Could not set %s." % attribute)
                return False
                break
    # Return:
    return True

def scutil_set_names(given_name_str):
    '''Calls scutil to set the various system names.'''
    # Sanity checks:
    if not given_name_str:
        common.print_error("No name supplied!")
        return False
    if len(given_name_str) > 15:
        common.print_error("Given name is longer than 15 characters: %s" % given_name_str)
        return False
    # Run scutil:
    for name_type in ['ComputerName','LocalHostName','HostName']:
        try:
            common.print_info("Setting the %s via scutil..." % name_type)
            subprocess.check_call(['/usr/sbin/scutil',
                                              '--set',
                                              name_type,
                                              given_name_str])
        except subprocess.CalledProcessError:
            common.print_error("Could not set the %s via scutil." % name_type)
            return False
            break
    # Return:
    return True

def profiles_install(given_mobileconfig_path):
    '''Calls profiles to install a given config profile in the system scope.
        Returns true if profiles exited 0, false otherwise.'''
    try:
        subprocess.check_call(['/usr/bin/profiles',
                                      '-I',
                                      '-F',
                                      given_mobileconfig_path])
        return True
    except subprocess.CalledProcessError:
        common.print_error("Could not install the configuration profile at %s." % given_mobileconfig_path)
        return False

def profiles_remove(given_mobileconfig_identifier):
    '''Calls profiles to remove a given config profile in the system scope.
        Returns true if profiles exited 0, false otherwise.'''
    try:
        subprocess.check_call(['/usr/bin/profiles',
                               '-R',
                               '-p',
                               given_mobileconfig_identifier])
        return True
    except subprocess.CalledProcessError:
        common.print_error("Could not remove the configuration profile with identifier %s." % given_mobileconfig_identifier)
        return False

def system_profiler_fetch_serial():
    '''Calls System Profiler to get the computer's hardware serial number.
        Returns an empty string if something bad happened.'''
    # Run command:
    try:
        output = subprocess.check_output(['/usr/sbin/system_profiler',
                                      'SPHardwareDataType',
                                      '-xml'])
    except subprocess.CalledProcessError:
        output = None
    # Try to get serial_number key:
    if output:
        try:
            output_dict = plistlib.readPlistFromString(output)
        except xml.parsers.expat.ExpatError:
            output_dict = {}
    if output_dict:
        try:
            serial_number = output_dict[0]['_items'][0]['serial_number']
        except KeyError:
            serial_number = ''
    # Log bad serial:
    if not serial_number:
        common.print_error("Failed to get the computer's hardware serial number.")
    # Return:
    return serial_number

def system_profiler_get_ethernets():
    '''Calls System Profiler to make an array of Ethernet interfaces with IPs.'''
    # Run command:
    try:
        output = subprocess.check_output(['/usr/sbin/system_profiler',
                                          'SPNetworkDataType',
                                          '-xml'])
    except subprocess.CalledProcessError:
        output = None
    # Try to get keys:
    if output:
        try:
            output_dict = plistlib.readPlistFromString(output)
        except xml.parsers.expat.ExpatError:
            output_dict = {}
    if output_dict:
        try:
            network_interfaces_list = output_dict[0]['_items']
        except KeyError:
            network_interfaces_list = []
    # Make list of Ethernet interfaces with IPs:
    ethernet_interfaces_with_ip_addresses = []
    for interface_dict in network_interfaces_list:
        try:
            interface_identifier = interface_dict['interface'].lower()
        except KeyError:
            interface_identifier = ''
        try:
            interface_type = interface_dict['type'].lower()
        except KeyError:
            interface_type = ''
        try:
            interface_ip_addresses = interface_dict['ip_address']
        except KeyError:
            interface_ip_addresses = []
        try:
            interface_media = interface_dict['Ethernet']['MediaSubType'].lower()
        except KeyError:
            interface_media = ''
        if interface_identifier and (interface_type == 'ethernet') and (len(interface_ip_addresses) > 0):
            ethernet_dict = {}
            ethernet_dict['identifier'] = interface_identifier
            ethernet_dict['media'] = interface_media
            ethernet_dict['ip_addresses'] = interface_ip_addresses
            ethernet_interfaces_with_ip_addresses.append(ethernet_dict)
    # Log empty Ethernet interfaces:
    if not ethernet_interfaces_with_ip_addresses:
        common.print_error("No Ethernet interfaces appear to be active.")
    # Return:
    return ethernet_interfaces_with_ip_addresses
