#!/bin/sh

#  build-script.sh
#  Munki Enrollment Client
#  Xcode build script for for creating the MEC installation package.

# Written by Gerrit DeWitt (gdewitt@gsu.edu)
# Project started 2015-06-15.  This file created 2015-08-11.
# 2016-01-05, 2017-01-04/9, 2017-04-10.
# Copyright Georgia State University.
# This script uses publicly-documented methods known to those skilled in the art.
# References: See top level Read Me.

declare -x PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# MARK: VARIABLES

# Control variable:
declare -i CLEANUP_WHEN_DONE=0

# General paths:
declare -x XCODE_PROJ_DIR=$(dirname "$PRODUCT_SETTINGS_PATH")

# Staging dir:
declare -x PROD_STAGING_PATH="$BUILD_DIR/staging" # no spaces in these paths or productbuild will fail to accept them as components!

# Paths to built app and agent:
declare -x BUILT_APP_PATH="$BUILD_DIR/Debug/$TARGET_NAME.app"
declare -x BUILT_AGENT_PATH="$BUILT_APP_PATH/Contents/Resources/launch-agent.plist"
# Relative installed paths for app and agent:
declare -x INSTALLED_APP_PATH="Applications/Munki Enrollment Client.app"
declare -x INSTALLED_AGENT_PATH="Library/LaunchAgents/edu.gsu.mec.plist"

# Variables for building the MEC with pkgbuild:
declare -x MEC_PACKAGE_IDENTIFIER="edu.gsu.mec"
declare -x MEC_PACKAGE_ROOT_DIR="$BUILD_DIR/mec-package-root"
declare -x MEC_PACKAGE_SCRIPTS_DIR="$BUILD_DIR/mec-package-scripts"
declare -x MEC_VERSION="$(defaults read "$BUILT_APP_PATH/Contents/Info.plist" CFBundleShortVersionString)"
declare -x MEC_PACKAGE_PATH="$PROD_STAGING_PATH/munki-enrollment-client-$MEC_VERSION.pkg" # no spaces in this name or productbuild will fail to accept it as a component!

# Variables for downloading the specified version of munkitools from munkibuilds.org:
declare -x MUNKI_VERSION="2.8.2.2855"
declare -x MUNKI_DOWNLOAD_URI="https://munkibuilds.org/$MUNKI_VERSION/munkitools-$MUNKI_VERSION.pkg"
declare -x MUNKI_DOWNLOAD_MD5="https://munkibuilds.org/$MUNKI_VERSION/MD5"
declare -x MUNKI_PRODUCT_PACKAGE_PATH="$BUILD_DIR/munkitools-$MUNKI_VERSION.pkg"
declare -x MUNKI_EXPANDED_PRODUCT_PATH="$BUILD_DIR/munkitools-expanded-product"

# Variables for building the overall product:
declare -x PROD_DISTRIBUTION_PATH="$PROD_STAGING_PATH/Distribution"
declare -x PROD_PACKAGE_PATH="$PROD_STAGING_PATH/Munki-Enrollment-Client.pkg" # no spaces in this name or productbuild will fail!
declare -x PROD_PACKAGE_FINAL_PATH="$BUILD_DIR/Munki_Enrollment_Client-$MEC_VERSION.pkg"
declare -x PROD_DIST_PACKAGES_ARG=""
declare -x PROD_BUILD_PACKAGES_ARG=""

# MARK: prepost_common_cleanup()
# Removes various temporary or intermediate directories and files used by the packaging process.
function prepost_common_cleanup(){
    if [ -d "$MEC_PACKAGE_ROOT_DIR" ]; then
        rm -rf "$MEC_PACKAGE_ROOT_DIR" && echo "Removed $MEC_PACKAGE_ROOT_DIR."
    fi
    if [ -f "$MUNKI_PRODUCT_PACKAGE_PATH" ]; then
        rm "$MUNKI_PRODUCT_PACKAGE_PATH" && echo "Removed $MUNKI_PRODUCT_PACKAGE_PATH."
    fi
    if [ -d "$MUNKI_EXPANDED_PRODUCT_PATH" ]; then
        rm -rf "$MUNKI_EXPANDED_PRODUCT_PATH" && echo "Removed $MUNKI_EXPANDED_PRODUCT_PATH."
    fi
    if [ -d "$PROD_STAGING_PATH" ]; then
        rm -rf "$PROD_STAGING_PATH" && echo "Removed $PROD_STAGING_PATH."
    fi
}

# MARK: build_mec_package()
# Builds the component pkg for the Munki Enrollment Client.
function build_mec_package(){
    # Create package scripts dir:
    mkdir -p "$MEC_PACKAGE_SCRIPTS_DIR" && echo "Created package scripts directory."
    # Copy postinstall to package scripts dir:
    cp "$XCODE_PROJ_DIR/postinstall" "$MEC_PACKAGE_SCRIPTS_DIR/postinstall"
    # Set permisions on package scripts dir:
    chmod -R 0755 "$MEC_PACKAGE_SCRIPTS_DIR" && echo "Set permissions on package scripts directory."
    # Create package root:
    mkdir -p "$MEC_PACKAGE_ROOT_DIR/Applications" && echo "Created Applications directory in package root."
    mkdir -p "$MEC_PACKAGE_ROOT_DIR/Library/LaunchAgents" && echo "Created LaunchAgents directory in package root."
    # Copy app into package root:
    cp -R "$BUILT_APP_PATH" "$MEC_PACKAGE_ROOT_DIR/$INSTALLED_APP_PATH" && echo "Copied app to Applications directory in package root."
    # Copy launch agent from app wrapper to LaunchAgents directory in package root:
    cp "$BUILT_AGENT_PATH" "$MEC_PACKAGE_ROOT_DIR/$INSTALLED_AGENT_PATH" && echo "Copied launch agent to LaunchAgents directory in package root."
    # Set permisions on package root:
    chmod -R 0755 "$MEC_PACKAGE_ROOT_DIR" && echo "Set permissions on package root."
    chmod 0644 "$MEC_PACKAGE_ROOT_DIR/$INSTALLED_AGENT_PATH" && echo "Set permissions on launch agent in package root."
    # Remove ._ files from package root:
    find "$MEC_PACKAGE_ROOT_DIR" -name ._\* -exec rm {} \;
    # Remove .DS_Store files from package root:
    find "$MEC_PACKAGE_ROOT_DIR" -name .DS_Store -exec rm {} \;
    # Build MEC package:
    pkgbuild --root "$MEC_PACKAGE_ROOT_DIR" --identifier "$MEC_PACKAGE_IDENTIFIER" --scripts "$MEC_PACKAGE_SCRIPTS_DIR" --version "$MEC_VERSION" "$MEC_PACKAGE_PATH" && echo "Built package for $TARGET_NAME."
    if [ ! -f "$MEC_PACKAGE_PATH" ]; then
        echo "Error: Failed to build package for Munki Enrollment Client."
        exit 1
    fi
    # Add MEC package to our product's list of components:
    PROD_DIST_PACKAGES_ARG="$PROD_DIST_PACKAGES_ARG --package $MEC_PACKAGE_PATH"
    PROD_BUILD_PACKAGES_ARG="$PROD_BUILD_PACKAGES_ARG --package-path $MEC_PACKAGE_PATH"
}

# MARK: download_munkitools()
# Downloads the munkitools product archive from the web.
function download_munkitools(){
    # Download:
    curl "$MUNKI_DOWNLOAD_URI" > "$MUNKI_PRODUCT_PACKAGE_PATH" && echo "Downloaded munkitools build $MUNKI_VERSION."
    if [ ! -f "$MUNKI_PRODUCT_PACKAGE_PATH" ]; then
        echo "Error: Failed to download munkitools from $MUNKI_DOWNLOAD_URI."
        exit 1
    fi
    # Checksum:
    MEASURED_MD5=$(md5 -q "$MUNKI_PRODUCT_PACKAGE_PATH") && echo "Downloaded munkitools - calculated checksum: $MEASURED_MD5"
    REFERENCE_MD5=$(curl "$MUNKI_DOWNLOAD_MD5")
    if [ -z $REFERENCE_MD5 ]; then
        echo "Error: Failed to download MD5 checksum for munkitools from $MUNKI_DOWNLOAD_MD5."
        exit 1
    fi
    echo "munkitools - expected checksum: $REFERENCE_MD5"
    if [ "$MEASURED_MD5" != "$REFERENCE_MD5" ]; then
        echo "Error: Checksum mismatch for $MUNKI_PRODUCT_PACKAGE_PATH."
        exit 1
    fi
}

# MARK: extract_munkitools_components()
# Calls pkgutil to expand the munkitools product archive, obtaining individual components packages therein.
function extract_munkitools_components(){
    # Call pkgutil:
    pkgutil --expand "$MUNKI_PRODUCT_PACKAGE_PATH" "$MUNKI_EXPANDED_PRODUCT_PATH"
    if [ ! -d "$MUNKI_EXPANDED_PRODUCT_PATH" ]; then
        echo "Error: Failed to expand the munkitools package with pkgutil."
        exit 1
    fi
    # Flatten component packages:
    mkdir -p "$PROD_STAGING_PATH"
    for the_component_package in $(ls -d "$MUNKI_EXPANDED_PRODUCT_PATH"/*pkg); do
        # Paths will be confusing.  Explicitly referencing paths and basenames in this loop.
        component_package_name=$(basename "$the_component_package")
        # Flatten the component package:
        pkgutil --flatten "$MUNKI_EXPANDED_PRODUCT_PATH/$component_package_name" "$PROD_STAGING_PATH/$component_package_name"
        # Add the component package to our product's list of components:
        PROD_DIST_PACKAGES_ARG="$PROD_DIST_PACKAGES_ARG --package $PROD_STAGING_PATH/$component_package_name "
        PROD_BUILD_PACKAGES_ARG="$PROD_BUILD_PACKAGES_ARG --package-path $PROD_STAGING_PATH/$component_package_name "
    done
}

# MARK: build_product()
# Calls productbuild to create an overall product package consisting of the MEC and munkitools components.
function build_product(){
    # Synthesize distribution file:
    productbuild --synthesize $(echo "$PROD_DIST_PACKAGES_ARG") "$PROD_DISTRIBUTION_PATH" && echo "Built distribution file at $PROD_DISTRIBUTION_PATH."
    if [ ! -f "$PROD_DISTRIBUTION_PATH" ]; then
        echo "Error: Failed to create distribution file for overall product."
        exit 1
    fi
    # Build overall product:
    cd "$PROD_STAGING_PATH" # have to do this because productbuild is incapable of understanding absolute paths passed to it. :(
    productbuild --distribution "$PROD_DISTRIBUTION_PATH" $(echo "$PROD_BUILD_PACKAGES_ARG") "$PROD_PACKAGE_PATH" && echo "Built product at $PROD_PACKAGE_PATH."
    if [ ! -f "$PROD_PACKAGE_PATH" ]; then
        echo "Error: Failed to build product package."
        exit 1
    fi
}

# MARK: pre_cleanup()
# Sets up packaging environment.
function pre_cleanup(){
    if [ -f "$PROD_PACKAGE_FINAL_PATH" ]; then
        rm "$PROD_PACKAGE_FINAL_PATH" && echo "Removed $PROD_PACKAGE_FINAL_PATH."
    fi
    prepost_common_cleanup
    mkdir -p "$PROD_STAGING_PATH"
}

# MARK: post_cleanup()
# Sets up packaging environment.
function post_cleanup(){
    mv "$PROD_PACKAGE_PATH" "$PROD_PACKAGE_FINAL_PATH" && echo "Final package at PROD_PACKAGE_FINAL_PATH."
    if [ "$CLEANUP_WHEN_DONE" -eq 1 ]; then
        prepost_common_cleanup
    fi
}

# MARK: main()
pre_cleanup
build_mec_package
download_munkitools
extract_munkitools_components
build_product
post_cleanup
