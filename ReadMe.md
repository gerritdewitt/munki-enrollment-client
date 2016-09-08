About
----------
The Munki Enrollment Client (MEC) is an OS X app written in Objective-C with included scripts writtin in Python and bash. Working with the Munki Enrollment Server (MES), it enrolls the computer with a Munki repository, creating a computer manifest, private key, and certificate for per-device authentication.  It joins the computer's manifest to an appropriate group manifest (via the _included_manifests_ key in the computer's manifest), and it performs various “first boot” setup.  Communication between the MEC and the MES is encrypted in transit with HTTPS.

The MEC is delivered to a client system via an installer package.  Its package may be installed to enroll a Mac ad-hoc (without erasing and re-imaging it), and it may be installed at the end of an imaging procedure (such as a DeployStudio workflow).  The installer package distributes these items:
   * **/Applications/Munki Enrollment Client.app**, the app including its embedded scripts, and
   * **/Library/LaunchAgents/edu.gsu.mec.plist**, the launch agent responsible for loading the MEC in the the Login Window context.

Besides installing the MEC, its installer package executes a _postinstall_ script that does the following:
   * It touches _/private/var/db/.AppleSetupDone_ on the installation target's volume to prevent the OS X Setup Assistant from appearing.  This is primarily for the “just imaged” case where a system may have had an image restored and the MEC should perform first boot setup.
   * It moves _/private/etc/kcpasswd_ on the installation target's volume to a different path to temporarily disable automatic login.  Automatic login is restored after the MEC completes its tasks.
   * It sets the _DisableFDEAutoLogin_ key to true in the _com.apple.loginwindow_ preference for the system domain.  This temporarily disables FileVault's ability to bypass the login window after a disk is unlocked at boot.  FileVault's ability to bypass the login window is restored after the MEC completes its tasks.
FDE automatic login (by setting the DisableFDEAutoLogin key to true in the com.apple.loginwindow domain on the installation target's volume).

Building
----------
This repository holds a single Xcode project which builds an Apple installer package for the MEC.  The _build-script.sh_ file may be adjusted as necessary.  It is called at the end of the Xcode build sequence and is responsible for creating the installer package.  The installer package for the MEC is actually a distribution product archive with a component package for the MEC and the component packages from the Munki tools.  The Munki tools are downloaded from _munkibuilds.org_.  Change the _MUNKI_VERSION_ variable to specify what version of Munki tools should be included in the MEC package.

You'll also need to make some changes specific to your environment.  This can be done before or after building, as configuration is stored in the Site class of the _configuration.py_ module.  This holds a number of configuration parameters such as your organization name, the URL for the Munki Enrollment Server, etc.
   * To edit before building, edit _configuration.py_ in the Xcode project.
   * It is also possible to edit this file after building by modifying _Contents/Resources/configuration.py_ inside the app wrapper and re-packaging the product.  This is not recommended, but illustrates that the configuration is not compiled.

Authors
----------
   * The MEC and MES were created by Gerrit DeWitt (gdewitt@gsu.edu), but the overall idea for the project is not novel.  For example, a project called “Munki Manifest Selector” (noted in Sources) captures the overall design goal.
   * MEC relies heavily on publicly disclosed methods and open source items.  For license terms, authors, and references, refer to the Sources section.

Sources
----------
### Notes and How-To ###
1. Conceptual Inspiration:
   * Munki Manifest Selector: https://denisonmac.wordpress.com/2013/02/09/munki-manifest-selector
   * Munki Manifest Selector: https://github.com/buffalo/Munki-Manifest-Selector
   * Discussion About Manifest Selector: https://groups.google.com/forum/#!topic/munki-dev/kd0xL-TtiGA
2. Munki manifest format:  https://github.com/munki/munki/wiki/Manifests
3. Apple Serial Numbers:  http://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
4. Local User & Group Manipulation:
   * http://linuxtoosx.blogspot.com/2011/06/create-user-account-from-os-x-command.html
   * http://serverfault.com/questions/20702/how-do-i-create-user-accounts-from-the-terminal-in-mac-os-x-10-5
5. String Manipulation: http://www.tldp.org/LDP/abs/html/string-manipulation.html
6. FileVault Automatic Login: https://support.apple.com/en-us/HT202842
7. Package Creation: http://thegreyblog.blogspot.com/2014/06/os-x-creating-packages-from-command_2.html
8. Manual Pages:
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/caffeinate.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/system_profiler.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/networksetup.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/systemsetup.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/ntpdate.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/scutil.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/profiles.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/dscl.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/dseditgroup.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/defaults.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man8/PlistBuddy.8.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/pkgbuild.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/productbuild.1.html#//apple_ref/doc/man/1/productbuild
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/pkgutil.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/md5.1.html
   * https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/curl.1.html
9. Python:
   * classes: https://learnpythonthehardway.org/book/ex40.html
   * https://docs.python.org/2/library/platform.html
   * https://docs.python.org/2/library/pwd.html
   * https://docs.python.org/2/library/plistlib.html
   * https://docs.python.org/2/library/xml.etree.elementtree.html
   * https://docs.python.org/2/library/os.html
   * https://docs.python.org/2/library/sys.html
   * https://docs.python.org/2/library/shutil.html
   * https://docs.python.org/2/library/logging.html
   * https://docs.python.org/2/library/base64.html
   * https://docs.python.org/2/library/hashlib.html
   * https://docs.python.org/2/library/shutil.html
   * https://docs.python.org/2/library/time.html
   * https://docs.python.org/2/library/datetime.html
      * https://pymotw.com/2/datetime/
   * https://docs.python.org/2/library/urllib.html
      * http://pymotw.com/2/urllib/
      * http://stackoverflow.com/questions/27835619/ssl-certificate-verify-failed-error
   * https://docs.python.org/2/library/ssl.html
   * https://github.com/pyca/pyopenssl
      * http://stackoverflow.com/questions/27986797/sign-a-message-with-dsa-with-library-pyopenssl
   * https://docs.python.org/2/library/subprocess.html
      * http://pymotw.com/2/subprocess/
      * http://stackoverflow.com/questions/1196074/how-to-start-a-background-process-in-python
   * https://docs.python.org/2/library/tarfile.html
      * http://pymotw.com/2/tarfile/
      * http://stackoverflow.com/questions/2018512/reading-tar-file-contents-without-untarring-it-in-python-script
10. Objective-C Reference:
      * NSBundle: https://developer.apple.com/library/ios/documentation/CoreFoundation/Conceptual/CFBundles/AccessingaBundlesContents/AccessingaBundlesContents.html
      * NSTask: http://borkware.com/quickies/one?topic=NSTask
      * NSTask: http://www.raywenderlich.com/36537/nstask-tutorial
      * NSTask: http://stackoverflow.com/questions/17788267/get-notification-of-task-progress-from-nstask
      * NSMutableDictionary from plist: http://stackoverflow.com/questions/7631261/reading-a-plist-file-in-cocoa:
      * Binding NSPopupButton to NSArrayController: https://discussions.apple.com/thread/1534797?start=0&tstart=0
      * Binding NSPopupButton to NSArrayController: http://stackoverflow.com/questions/10885137/how-to-setup-bindings-for-nspopupbutton
      * NSPopupButton Example - Getting Index of Selection: http://stackoverflow.com/questions/12075195/how-to-get-nspopupbutton-selected-object
      * Cocoa Bindings Tutorial: http://web.stanford.edu/class/cs193e/Downloads/CocoaBindingsTutorial.pdf
      * NSString - Checking Final Character: http://stackoverflow.com/questions/3244996/how-to-check-the-last-char-of-an-nsstring
      * NSString - Substring with Range: http://stackoverflow.com/questions/6052223/extracting-a-string-with-substringwithrange-gives-index-out-of-bounds
      * Try-Catch: http://stackoverflow.com/questions/741555/in-what-circumstances-is-finally-non-redundant-in-cocoas-try-catch-finally-exc
      * Predicates: https://www.cocoanetics.com/2010/03/filtering-fun-with-predicates/
      * TableView Bindings: http://telliott99.blogspot.com/2009/09/cocoa-tableview-bindings-simplest.html
      * NSArrayController & View-Based NSTableView Binding: http://stackoverflow.com/questions/19757983/nsarraycontroller-view-based-nstableview-binding-to-nstextfield
      * Binding NSDictionary in NSArray into TableViewCell: http://www.cocoabuilder.com/archive/cocoa/327445-binding-nsdictionary-in-nsarray-into-table-view-cell.html
      * TableViewPlayground Sample Code: https://developer.apple.com/library/mac/samplecode/TableViewPlayground
      * Populating a Table View Using Cocoa Bindings: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/TableView/PopulatingViewTablesWithBindings/PopulatingView-TablesWithBindings.html
      * Time Interval Since Now: http://stackoverflow.com/questions/6144966/measuring-time-interval-since-now
      * Comparisons with NSNumber: http://stackoverflow.com/questions/2428165/compare-a-nsnumber-with-a-fixed-value
      * Bit Masking:  http://stackoverflow.com/questions/12339833/bitmasking-in-objective-c
      * Bit Masking:  https://www.bignerdranch.com/blog/smooth-bitwise-operator/
      * Integer Casting Dictionary Values:  http://stackoverflow.com/questions/18614124/how-to-get-an-integer-value-from-nsdictionary
      * String Casting of NSInteger: http://stackoverflow.com/questions/9404201/casting-nsinteger-into-nsstring
11. Getting Notifications from Munki: NSDistributedNotificationCenter
      * http://stackoverflow.com/questions/1933107/how-do-you-listen-to-notifications-from-itunes-on-a-mac-using-the-nsdistributed
      * http://telliott99.blogspot.com/2011/01/nsnotifications.html
      * https://bitbucket.org/ronaldoussoren/pyobjc/src/tip/pyobjc-core/Examples/Scripts/autoreadme.py?at=default&fileviewer=file-view-default
      * https://github.com/munki/munki/blob/3a3dfc60dd169ed7f056a14da8dd6f8df4996146/code/apps/MunkiStatus/MunkiStatus/MSUStatusWindowController.py
      * http://stackoverflow.com/questions/9858112/how-to-pass-parameters-between-cocoa-applications
12. Misc:
      * Checking EUID in C: http://stackoverflow.com/questions/4159910/check-if-user-is-root-in-c