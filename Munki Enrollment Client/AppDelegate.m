//
//  AppDelegate.m
//  Munki Enrollment Client
//
//  Created by Gerrit E Dewitt on 8/3/15.
//  Copyright (c) 2015 Georgia State University.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification{
    // Populate these variables:
    self.resultPreEnrollmentPath = @"/private/tmp/edu.gsu.mec.result.preenrollment.plist";
    self.receivedTarFilePath = @"/private/var/root/edu.gsu.mec.enrollment.materials.tar";
    self.transactionAFilePath = @"/Library/Preferences/edu.gsu.mec.result.transaction.a.plist";
    self.transactionBFilePath = @"/Library/Preferences/edu.gsu.mec.result.transaction.b.plist";
    self.resultPostEnrollmentPath = @"/private/tmp/edu.gsu.mec.result.postenrollment.plist";
    self.munkiCheckAndInstallSemaphorePath = @"/Users/Shared/.com.googlecode.munki.checkandinstallatstartup";
    self.enrollmentScriptPath = [[NSBundle mainBundle] pathForResource:@"enrollment-client" ofType:@"py"];
    // Some pretties:
    self.appleWarningIconPath = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns";
    self.appleStopIconPath = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns";
    self.munkiIconPath = @"/Applications/Managed Software Center.app/Contents/Resources/Managed Software Center.icns";
    [self loadIcons];
    // Workflow logic:
    self.rebootImminent = NO;
    self.munkiIsRunning = NO;
    self.startAtBeginning = YES; // Assume we start at the pre-enrollment.
    self.munkiLoopCounter = 0;
    self.munkiLoopCounterMaximum = 2;
    self.munkiState = 0x00;
    self.munkiState |= MUNKI_STATE_TOP_OF_LOOP;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    [self showFirstTab];

    // Set the main window to be visable in the Login Window context:
    [self->window setCanBecomeVisibleWithoutLogin:YES];
    
    // Progress on the first tab:
    [self showFirstTabProcessing];
    
    // Draw window:
    [self->window makeKeyAndOrderFront:self];
    
    // Start listening for Munki distributed notifications:
    [self registerForMunkiNotifications];
    
    // Check for and read the timestamp in the transaction B file.
    @try {
        NSMutableDictionary *transactionBDict;
        transactionBDict = [NSMutableDictionary dictionaryWithContentsOfFile:self.transactionBFilePath];
        BOOL completedTransactionB = [[transactionBDict objectForKey:@"result"] boolValue];
        NSDate *transactionBCompletedDate = [transactionBDict objectForKey:@"transaction_completed_date"];
        NSTimeInterval timeSinceTransactionB = [transactionBCompletedDate timeIntervalSinceNow];
        // Finished transaction anytime within the last 24 hours (and the transaction result file exists):
        // we can be reasonably sure we're still enrolling (especially since the transaction result file exists).
        if ((completedTransactionB == YES) && (fabs(timeSinceTransactionB) > 0) && (fabs(timeSinceTransactionB) <= 86400)){
            self.startAtBeginning = NO;
        }
    } @catch (NSException *exception) {
        // Do nothing.  This exception happens if the file cannot be read (doesn't exist, etc.).
        // We default to starting at the beginning in this case.
    }
    
    if (geteuid() != 0){
        // Catch not root: Ask to log out so this app can run via its agent
        // in the login window context.  An area for future improvement, this is.
        self.errorType = 0x00;
        self.errorType |= ERROR_TYPE_STOP;
        self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_NOT_ROOT", nil);
        self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_NOT_ROOT", nil);
        [self showErrorTab];
    }else{
        // What to do next:
        if (self.startAtBeginning == YES){
            [self runPreEnrollment];
        }else{
            // ...We are probably coming back after a reboot:
            [self showMunkiTab];
            [self doMunkiLoop];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)rebootSystem {
    // Runs "/sbin/shutdown -r now"
    
    NSString *shutdownPath = @"/sbin/shutdown";
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:shutdownPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"-r", @"now", nil];
    [task setArguments:args];
    
    NSPipe *outPipe;
    outPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    NSFileHandle *outFile;
    outFile = [outPipe fileHandleForReading];
    
    [task launch];
}

- (void)runPreEnrollment {
    // Runs "enrollment-client.py do-pre-enrollment"
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"do-pre-enrollment", nil];
    [task setArguments:args];
    
    NSPipe *outPipe;
    outPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    NSFileHandle *outFile;
    outFile = [outPipe fileHandleForReading];
   
    [task launch];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedPreEnrollment:) name:NSTaskDidTerminateNotification object:task];
}

- (void)finishedPreEnrollment:(NSNotification *)aNotification {

    @try {
        // Read pre-enrollment result output file.
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:self.resultPreEnrollmentPath];
        BOOL result = [[dict objectForKey:@"result"] boolValue];
        BOOL clientSerialValid = [[dict objectForKey:@"client_serial_valid"] boolValue];
        
        NSMutableDictionary *networkStatusDict = [dict objectForKey:@"network_status"];
        BOOL networkAvailable = [[networkStatusDict objectForKey:@"network_available"] boolValue];
        BOOL gigabitAvailable = [[networkStatusDict objectForKey:@"gigabit_available"] boolValue];

        NSMutableDictionary *osVersionDict = [dict objectForKey:@"os_version"];
        //NSNumber *currOSVers = [osVersionDict objectForKey:@"current_macos"];
        //NSNumber *minOSVers = [osVersionDict objectForKey:@"min_macos"];
        BOOL supportedOsVersion = [[osVersionDict objectForKey:@"valid"] boolValue];
        
        if (result == YES){
            // Read computer name suffix provided by the pre-enrollment script.
            self.computerNameSuffix = [dict objectForKey:@"computer_name_suffix"];
            if (gigabitAvailable == NO){
                // Warn if no gigabit:
                self.errorType = 0x00;
                self.errorType |= ERROR_TYPE_WARNING;
                self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_PRE_ENROLLMENT_WARN_GIGABIT", nil);
                self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_WARN_GIGABIT", nil);
                [self showErrorTab];
            } else{
                // Move onto the enrollment script with the "transaction-a" verb:
                [self runTransactionA];
            }
        } else if (networkAvailable == NO){
            // Catch not on network:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_PRE_ENROLLMENT_NO_NETWORK", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_NO_NETWORK", nil);
            [self showErrorTab];
        } else if (clientSerialValid == NO){
            // Catch invalid serials:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_PRE_ENROLLMENT_INVALID_SERIAL", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_INVALID_SERIAL", nil);
            [self showErrorTab];
        } else if (supportedOsVersion == NO){
            // Catch unsupported macOS:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_STOP;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_PRE_ENROLLMENT_UNSUPPORTED_OS", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_UNSUPPORTED_OS", nil);
            [self showErrorTab];
        } else {
            // Catch other errors:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_PRE_ENROLLMENT_FAILED", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_FAILED", nil);
            [self showErrorTab];
        }
    }
    @catch (NSException *exception) {
        // Catch other errors:
        self.errorType = 0x00;
        self.errorType |= ERROR_TYPE_START_OVER;
        self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_UNCAUGHT_EXCEPTION", nil);
        self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_PRE_ENROLLMENT_UNCAUGHT_EXCEPTION", nil);
        [self showErrorTab];
    }
}

- (void)runTransactionA {
    // Runs "enrollment-client.py transaction-a"

    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"transaction-a", nil];
    [task setArguments:args];
    
    NSPipe *outPipe;
    outPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    NSFileHandle *outFile;
    outFile = [outPipe fileHandleForReading];
    
    [task launch];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedTransactionA:) name:NSTaskDidTerminateNotification object:task];
}

- (void)finishedTransactionA:(NSNotification *)aNotification {
    @try {
        // Read transaction A dict:
        NSMutableDictionary *transactionADict = [NSMutableDictionary dictionaryWithContentsOfFile:self.transactionAFilePath];

        // Enrollment result:
        NSMutableDictionary *enrollmentStatusDict = [transactionADict objectForKey:@"enrollment_status"];
        BOOL enrollmentResult = [[enrollmentStatusDict objectForKey:@"result"] boolValue];
        // Transaction result:
        BOOL result = [[transactionADict objectForKey:@"result"] boolValue];

        // Load groups:
        BOOL groupsManifestsAvailable = [[transactionADict objectForKey:@"group_manifests_available"] boolValue];
        if (groupsManifestsAvailable){
            self.groupsDictArray = [transactionADict objectForKey:@"group_manifests_array"];
            self.groupsDictFilteredArray = self.groupsDictArray;
        } else {
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_NO_GROUPS", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_NO_GROUPS", nil);
            [self showErrorTab];
        }
        
        if (enrollmentResult && result){
            // Read the computer_manifest dict from the transactionA dict to figure out what the
            // next step should be:  previously enrolled tab or group selection tab.
            NSMutableDictionary *computerManifest;
            computerManifest = [transactionADict objectForKey:@"computer_manifest"];
            BOOL computerManifestExists = [[computerManifest objectForKey:@"exists"] boolValue];
            BOOL computerManifestHasNameAndGroup = [[computerManifest objectForKey:@"has_name_and_group"] boolValue];
            self.computerName = [computerManifest objectForKey:@"name"];
            self.selectedGroupName = [computerManifest objectForKey:@"group"];
            self.selectedGroupDisplayName = [computerManifest objectForKey:@"group_display_name"];
            if (computerManifestExists && computerManifestHasNameAndGroup){
                // Go to the previously enrolled tab:
                [self showPETab];
            } else {
                // Go to the group tab:
                [self showGroupTab];
            }
        } else if (!enrollmentResult){
            // Failed enrollment - catch this one first because it's the necessary condition:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_TRANSACTION_A_FAILED_ENROLLMENT", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_A_FAILED_ENROLLMENT", nil);
            [self showErrorTab];
        } else if (!result){
            // Error - transaction:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_TRANSACTION_A_FAILED_TRANSACTION", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_A_FAILED_TRANSACTION", nil);
            [self showErrorTab];
        }
    }
    @catch (NSException *exception) {
        // Catch other errors:
        self.errorType = 0x00;
        self.errorType |= ERROR_TYPE_START_OVER;
        self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_UNCAUGHT_EXCEPTION", nil);
        self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_A_UNCAUGHT_EXCEPTION", nil);
        [self showErrorTab];
    }
}

- (void)runTransactionB {
    // Runs "enrollment-client.py transaction-b"
    
    // args strs:
    NSString *nameArg = [NSString stringWithFormat:@"name=%@",self.computerName];
    NSString *groupArg = [NSString stringWithFormat:@"group=%@",self.selectedGroupName];
   
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"transaction-b", nameArg, groupArg, nil];
    [task setArguments:args];
    
    NSPipe *outPipe;
    outPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    NSFileHandle *outFile;
    outFile = [outPipe fileHandleForReading];
    
    [task launch];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedTransactionB:) name:NSTaskDidTerminateNotification object:task];
}

- (void)finishedTransactionB:(NSNotification *)aNotification{
    @try {
        // Read transaction B dict:
        NSMutableDictionary *transactionBDict = [NSMutableDictionary dictionaryWithContentsOfFile:self.transactionBFilePath];
        // Transaction results:
        BOOL transactionResult = [[transactionBDict objectForKey:@"result"] boolValue];
        BOOL joinedGroup = [[transactionBDict objectForKey:@"joined_group"] boolValue];
        BOOL recordedName = [[transactionBDict objectForKey:@"recorded_name"] boolValue];
        BOOL setLocalNames = [[transactionBDict objectForKey:@"set_local_names"] boolValue];

        if (transactionResult) {
            // Switch UI to the munki step and run the post script:
            [self showMunkiTab];
            [self doMunkiLoop];
        } else if (!setLocalNames){
            // Failed to set the name:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_TRANSACTION_B_FAILED_SETTING_NAMES", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_B_FAILED_SETTING_NAMES", nil);
            [self showErrorTab];
        } else if (!joinedGroup){
            // Failed to join the group:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_TRANSACTION_B_FAILED_GROUP_JOIN", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_B_FAILED_GROUP_JOIN", nil);
            [self showErrorTab];
        } else if (!recordedName){
            // Failed to set the name:
            self.errorType = 0x00;
            self.errorType |= ERROR_TYPE_START_OVER;
            self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_TRANSACTION_B_FAILED_NAME_RECORDING", nil);
            self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_B_FAILED_NAME_RECORDING", nil);
            [self showErrorTab];
        }
    }
    @catch (NSException *exception) {
        // Catch other errors:
        self.errorType = 0x00;
        self.errorType |= ERROR_TYPE_START_OVER;
        self.errorLabelStr = NSLocalizedString(@"ERROR_TAB_LABEL_UNCAUGHT_EXCEPTION", nil);
        self.errorDetailStr = NSLocalizedString(@"ERROR_TAB_DETAILS_TRANSACTION_B_UNCAUGHT_EXCEPTION", nil);
        [self showErrorTab];
    }
}

- (void) doMunkiLoop {
    // Workflow logic when running Munki.
    
    // Loop count:
    NSInteger loopCounterPlusOne = self.munkiLoopCounter +1;
    NSString *loopStr = [NSString stringWithFormat:@"doMunkiLoop: loop %ld of %ld", (long)loopCounterPlusOne, (long)self.munkiLoopCounterMaximum];
    NSLog(@"%@", loopStr);
    
    // Debug:
    if (self.munkiState & MUNKI_STATE_TOP_OF_LOOP){
        NSLog(@"doMunkiLoop: munkiState: top of loop");
    }else if (self.munkiState & MUNKI_STATE_CHECKING){
        NSLog(@"doMunkiLoop: munkiState: checking");
    }else if (self.munkiState & MUNKI_STATE_CHECK_FINISHED){
        NSLog(@"doMunkiLoop: munkiState: check finished");
    }else if (self.munkiState & MUNKI_STATE_INSTALLING){
        NSLog(@"doMunkiLoop: munkiState: installing");
    }else if (self.munkiState & MUNKI_STATE_INSTALL_FINISHED){
        NSLog(@"doMunkiLoop: munkiState: install finished");
    }

    // Pick a str for munkiTabLabel:
    NSString *uiMunkiLabel = NSLocalizedString(@"MUNKI_TAB_LABEL_DEFAULT", nil);
    if (self.munkiNotificationMessage != nil){
        uiMunkiLabel = self.munkiNotificationMessage;
    }else{
        if (self.munkiState & MUNKI_STATE_CHECKING){
            uiMunkiLabel = NSLocalizedString(@"MUNKI_TAB_LABEL_MUNKI_STATE_CHECKING", nil);
        }else if (self.munkiState & MUNKI_STATE_CHECK_FINISHED){
            uiMunkiLabel = NSLocalizedString(@"MUNKI_TAB_LABEL_MUNKI_STATE_CHECK_FINISHED", nil);
        }else if (self.munkiState & MUNKI_STATE_INSTALLING){
            uiMunkiLabel = NSLocalizedString(@"MUNKI_TAB_LABEL_MUNKI_STATE_INSTALLING", nil);
        }else if (self.munkiState & MUNKI_STATE_INSTALL_FINISHED){
            uiMunkiLabel = NSLocalizedString(@"MUNKI_TAB_LABEL_MUNKI_STATE_INSTALL_FINISHED", nil);
        }
    }
    // Update munkiTabLabel unless we have said we're restarting:
    if (!self.rebootImminent){
        self->munkiTabLabel.stringValue = uiMunkiLabel;
    }
    
    // munkiTabDetails:
    NSString *uiMunkiDetails = NSLocalizedString(@"MUNKI_TAB_DETAILS_DEFAULT", nil); // default
    // Update munkiTabDetails unless we have said we're restarting:
    if (!self.rebootImminent){
        // No details and not showing default: show default:
        if ( (self.munkiNotificationDetail == nil) && (self->munkiTabDetails.stringValue != NSLocalizedString(@"MUNKI_TAB_DETAILS_DEFAULT", nil)) ){
            self->munkiTabDetails.stringValue = uiMunkiDetails;
        }
        // Show details:
        if (self.munkiNotificationDetail != nil){
            uiMunkiDetails = self.munkiNotificationDetail;
            self->munkiTabDetails.stringValue = uiMunkiDetails;
        }
    }
    
    // Progress bar:
    if ((self.munkiNotificationPercent > 0) && (self.munkiNotificationPercent <= 100)){
        self->munkiTabMeteredBar.doubleValue = self.munkiNotificationPercent;
        [self showMunkiMeteredBar];
        NSLog(@"doMunkiLoop: showing metered progress bar");
    }else{
        [self showMunkiIndeterminateBar];
        NSLog(@"doMunkiLoop: showing indeterminate progress bar");
    }
    
    // Catch a request to reboot:
    if ([self.munkiNotificationCommand isEqual: @"showRestartAlert"]){
        NSLog(@"doMunkiLoop: Munki requests a reboot");
        self->munkiTabLabel.stringValue = NSLocalizedString(@"MUNKI_TAB_LABEL_REBOOTING", nil);
        self->munkiTabDetails.stringValue = NSLocalizedString(@"MUNKI_TAB_DETAILS_REBOOTING", nil);
        self.rebootImminent = YES;
        [self rebootSystem];
    }

    // Increment munki loop and go back to top if install finished:
    if (self.munkiState & MUNKI_STATE_INSTALL_FINISHED){
        self.munkiLoopCounter++;
        self.munkiState = 0x00;
        self.munkiState |= MUNKI_STATE_TOP_OF_LOOP;
        NSLog(@"doMunkiLoop: incremented munki loop counter");
    }
    
    // Loop:
    if (self.munkiLoopCounter >= self.munkiLoopCounterMaximum){
        [self showLastTab];  // break
        NSLog(@"doMunkiLoop: munkiLoopCounter at max; showing last tab");
    }else{
        if (self.munkiState & MUNKI_STATE_TOP_OF_LOOP){
            [self runMunkiCheck];
            NSLog(@"doMunkiLoop: munkiState was top of loop; calling runMunkiCheck()");
        }else if (self.munkiState & MUNKI_STATE_CHECK_FINISHED){
            [self runMunkiInstall];
            NSLog(@"doMunkiLoop: munkiState was checks finished; calling runMunkiInstall()");
        }
    }

}

- (void)finishedMunkiCheck:(NSNotification *)aNotification {
    self.munkiState = 0x00;
    self.munkiState |= MUNKI_STATE_CHECK_FINISHED;
    [self doMunkiLoop];
}

- (void)finishedMunkiInstall:(NSNotification *)aNotification {
    self.munkiState = 0x00;
    self.munkiState |= MUNKI_STATE_INSTALL_FINISHED;
    [self doMunkiLoop];
}

- (void) runMunkiCheck {
    // Runs "enrollment-client.py run-munki-check"

    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"run-munki-check", nil];
    [task setArguments:args];

    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedMunkiCheck:) name:NSTaskDidTerminateNotification object:task];

    self.munkiIsRunning = YES;
    self.munkiState = 0x00;
    self.munkiState |= MUNKI_STATE_CHECKING;
    [self doMunkiLoop];
    [task launch];
}

- (void) runMunkiInstall {
    // Runs "enrollment-client.py run-munki-install"
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"run-munki-install", nil];
    [task setArguments:args];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedMunkiInstall:) name:NSTaskDidTerminateNotification object:task];

    self.munkiIsRunning = YES;
    self.munkiState = 0x00;
    self.munkiState |= MUNKI_STATE_INSTALLING;
    [self doMunkiLoop];
    [task launch];
}

- (void)runLastSteps {
    // Runs "enrollment-client.py last-steps"
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:self.enrollmentScriptPath];
    NSArray *args;
    args = [NSArray arrayWithObjects:@"last-steps", nil];
    [task setArguments:args];
    
    NSPipe *outPipe;
    outPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outPipe];
    NSFileHandle *outFile;
    outFile = [outPipe fileHandleForReading];
    
    [task launch];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(finishedLastSteps:) name:NSTaskDidTerminateNotification object:task];
}

- (void)finishedLastSteps:(NSNotification *)aNotification {
    // Read post-enrollment result output file.
    NSMutableDictionary *dict;
    dict = [NSMutableDictionary dictionaryWithContentsOfFile:self.resultPostEnrollmentPath];
    BOOL result;
    result = [[dict objectForKey:@"result"] boolValue];
    
    // The system reboots.
}

// PRAGMA MARK: Misc UI Update Methods
- (void)loadIcons {
    self->lastTabIcon.image = [[NSImage alloc] initWithContentsOfFile:self.munkiIconPath];
    self->munkiTabIcon.image = [[NSImage alloc] initWithContentsOfFile:self.munkiIconPath];
}

- (void)formatComputerNameField:(NSNotification *)aNotification {
    // Truncates computer name if necessary.
    NSString *testStr;
    testStr = self->nameTabComputerNameField.stringValue;
    if (testStr.length > 15){ // Truncate:
        self->nameTabComputerNameField.stringValue = [testStr substringToIndex:15];
    }
}

- (void)hideAllMunkiBars {
    [self->munkiTabMeteredBar stopAnimation:self];
    self->munkiTabMeteredBar.hidden = YES;
    [self->munkiTabIndeterminateBar stopAnimation:self];
    self->munkiTabIndeterminateBar.hidden = YES;
}
- (void)showMunkiIndeterminateBar {
    [self->munkiTabMeteredBar stopAnimation:self];
    self->munkiTabMeteredBar.hidden = YES;
    [self->munkiTabIndeterminateBar startAnimation:self];
    self->munkiTabIndeterminateBar.hidden = NO;
}
- (void)showMunkiMeteredBar {
    [self->munkiTabIndeterminateBar stopAnimation:self];
    self->munkiTabIndeterminateBar.hidden = YES;
    [self->munkiTabMeteredBar startAnimation:self];
    self->munkiTabMeteredBar.hidden = NO;
}

// PRAGMA MARK: Tab Controls
- (void)showFirstTab {
    // Updates and switches to the first tab.
    // Update elements:
    self->firstTabIndeterminateBar.hidden = YES;
    [self->firstTabIndeterminateBar stopAnimation:self];
    self->firstTabLabel.stringValue = NSLocalizedString(@"FIRST_TAB_LABEL", nil);
    self->firstTabDetails.stringValue = NSLocalizedString(@"FIRST_TAB_DETAILS", nil);
     // Reveal tab:   
    [self->tabView selectTabViewItem:self->firstTab];
}

- (void)showFirstTabProcessing {
    // Updates elements in the first tab to indicate actions are in progress.
    self->firstTabLabel.stringValue = NSLocalizedString(@"FIRST_TAB_LABEL_IN_PROGRESS", nil);
    self->groupTabSubheading.stringValue = NSLocalizedString(@"FIRST_TAB_DETAILS_IN_PROGRESS", nil);
    
    [self->firstTabIndeterminateBar startAnimation:self];
    self->firstTabIndeterminateBar.hidden = NO;
}

- (void)showPETab {
    // Updates and switches to the "previously enrolled" tab.
    // Update elements:
    self->peTabHeading.stringValue = NSLocalizedString(@"PE_TAB_HEADING", nil);
    self->peTabSubheading.stringValue = NSLocalizedString(@"PE_TAB_DETAILS_1", nil);
    self->peTabActionLabel.stringValue = NSLocalizedString(@"PE_TAB_ACTION_LABEL", nil);
    NSString *nameLabel = [@"Name: " stringByAppendingString:self.computerName];
    self->peTabNameLabel.stringValue = nameLabel;
    self->peTabNameDetails.stringValue = NSLocalizedString(@"PE_TAB_NAME_DETAILS", nil);
    NSString *groupLabel = [@"Group: " stringByAppendingString:self.selectedGroupDisplayName];
    self->peTabGroupLabel.stringValue = groupLabel;
    // Reveal tab:
    [self->tabView selectTabViewItem:self->peTab];
}

- (void)showGroupTab {
    // Updates and switches to the group tab.
    // Update elements:    
    self->groupTabJoinButton.hidden = NO;
    self->groupTabJoinButton.enabled = NO;
    self->groupTabBox.hidden = NO;
    self->groupTabHeading.stringValue = NSLocalizedString(@"GROUP_TAB_HEADING", nil);
    self->groupTabSubheading.stringValue = NSLocalizedString(@"GROUP_TAB_SUBHEADING", nil);
    self->groupTabActionLabel.stringValue = NSLocalizedString(@"GROUP_TAB_ACTION_LABEL", nil);
    self->groupTabDescription.stringValue  = @"";
    // Reveal tab:
    [self->tabView selectTabViewItem:self->groupTab];
 }

- (void)showNameTab {
    // Update elements:
    self->nameTabContinueButton.hidden = NO;
    self->nameTabComputerNameBox.hidden = NO;
    self->nameTabHeading.stringValue = NSLocalizedString(@"NAME_TAB_HEADING", nil);
    self->nameTabSubheading.stringValue = NSLocalizedString(@"NAME_TAB_SUBHEADING", nil);
    self->nameTabActionLabel.stringValue = NSLocalizedString(@"NAME_TAB_ACTION_LABEL", nil);
    self->nameTabDetails2.stringValue = NSLocalizedString(@"NAME_TAB_DETAILS_2", nil);
    // Show a name suggestion:
    self.computerName = [self.selectedGroupComputerNamePrefix stringByAppendingString:self.computerNameSuffix];
    self->nameTabComputerNameField.stringValue = self.computerName;
    // Add observer:
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(formatComputerNameField:) name:NSControlTextDidChangeNotification object:self->nameTabComputerNameField];
    // Reveal tab:
    [self->tabView selectTabViewItem:self->nameTab];
}

- (void)showConfirmationTab {
    // Update elements:
    self->confirmationTabChangeNameOrGroupButton.hidden = NO;
    self->confirmationTabAcceptNameAndGroupButton.hidden = NO;
    self->confirmationTabIndeterminateBar.hidden = YES;
    [self->confirmationTabIndeterminateBar stopAnimation:self];
    self->confirmationTabHeading.stringValue = NSLocalizedString(@"CONFIRMATION_TAB_HEADING", nil);
    self->confirmationTabSubheading.hidden = NO;
    self->confirmationTabSubheading.stringValue = NSLocalizedString(@"CONFIRMATION_TAB_SUBHEADING", nil);
    self->confirmationTabActionLabel.hidden = NO;
    self->confirmationTabBox.hidden = NO;
    self->confirmationTabActionLabel.stringValue = NSLocalizedString(@"CONFIRMATION_TAB_ACTION_LABEL", nil);
    self->confirmationTabGroupLabel.stringValue = [NSString stringWithFormat:@"Group: %@", self.selectedGroupDisplayName];
    self->confirmationTabNameLabel.stringValue = [NSString stringWithFormat:@"Name: %@", self.computerName];
    // Reveal tab:
    [self->tabView selectTabViewItem:self->confirmationTab];
}

- (void)showConfirmationTabProcessing {
    // Update elements:
    self->confirmationTabChangeNameOrGroupButton.hidden = YES;
    self->confirmationTabAcceptNameAndGroupButton.hidden = YES;
    [self->confirmationTabIndeterminateBar startAnimation:self];
    self->confirmationTabIndeterminateBar.hidden = NO;
    self->confirmationTabHeading.stringValue = NSLocalizedString(@"CONFIRMATION_TAB_LABEL_IN_PROGRESS", nil);
    self->confirmationTabSubheading.hidden = YES;
    self->confirmationTabActionLabel.hidden = YES;
    self->confirmationTabBox.hidden = YES;
    // Reveal tab:
    [self->tabView selectTabViewItem:self->confirmationTab];
}

- (void)showMunkiTab {
    // Update elements:
    self->munkiTabLabel.stringValue = NSLocalizedString(@"MUNKI_TAB_LABEL", nil);
    self->munkiTabDetails.stringValue = NSLocalizedString(@"MUNKI_TAB_DETAILS", nil);
    // Reveal tab:
    [self->tabView selectTabViewItem:self->munkiTab];
}

- (void)showLastTab {
    // Update elements:
    self->lastTabLabel.stringValue = NSLocalizedString(@"LAST_TAB_LABEL", nil);
    self->lastTabDetails.stringValue = NSLocalizedString(@"LAST_TAB_DETAILS", nil);
    // Reveal tab:
    [self->tabView selectTabViewItem:self->lastTab];
}
- (void)showErrorTab {
    // Update elements:
    self->errorTabLabel.stringValue = self.errorLabelStr;
    self->errorTabDetails.stringValue = self.errorDetailStr;
    // Hide/show appropriate elements:
    self->errorTabIcon.image = [[NSImage alloc] initWithContentsOfFile:self.appleStopIconPath]; // stop is default
    self->errorTabStartOverButton.hidden = YES;
    self->errorTabIgnoreWarningButton.hidden = YES;
    self->errorTabStopButton.hidden = YES;
    if (self.errorType & ERROR_TYPE_START_OVER){
        self->errorTabStartOverButton.hidden = NO;
    } else if (self.errorType & ERROR_TYPE_WARNING){
        self->errorTabIgnoreWarningButton.hidden = NO;
        self->errorTabIcon.image = [[NSImage alloc] initWithContentsOfFile:self.appleWarningIconPath];
    } else if (self.errorType & ERROR_TYPE_STOP){
        self->errorTabStopButton.hidden = NO;
    }
    // Reveal tab:
    [self->tabView selectTabViewItem:self->errorTab];
}


// PRAGMA MARK: MUNKI NOTIFICATIONS

- (void)registerForMunkiNotifications {
    // Adds observers for distributed notifications coming from Munki:
    [self hideAllMunkiBars];
    self.munkiNotificationPercent = 0;
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(munkiDidStart:) name:@"com.googlecode.munki.managedsoftwareupdate.started" object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(munkiDidEnd:) name:@"com.googlecode.munki.managedsoftwareupdate.ended" object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(munkiDidPostStatus:) name:@"com.googlecode.munki.managedsoftwareupdate.statusUpdate" object:nil];
}
- (void)munkiDidStart:(NSNotification *)aNotification {
    self.munkiIsRunning = YES;
    NSLog(@"munkiDidStart called per com.googlecode.munki.managedsoftwareupdate.started");
}
- (void)munkiDidEnd:(NSNotification *)aNotification {
    self.munkiIsRunning = NO;
    self.munkiNotificationPercent = 0;
    NSLog(@"munkiDidEnd called per com.googlecode.munki.managedsoftwareupdate.ended");
}
- (void)munkiDidPostStatus:(NSNotification *)aNotification {
    NSLog(@"munkiDidPostStatus");
    self.munkiIsRunning = YES;
    NSDictionary *infoDict = aNotification.userInfo;
    self.munkiNotificationPercent = [[infoDict valueForKey:@"percent"] integerValue];
    self.munkiNotificationMessage = [infoDict valueForKey:@"message"];
    self.munkiNotificationDetail = [infoDict valueForKey:@"detail"];
    self.munkiNotificationCommand = [infoDict valueForKey:@"command"];
    [self doMunkiLoop];
}

// PRAGMA MARK: UI Update Methods From UI (IBActions)

- (IBAction)filterGroupsDictArray:(id)sender{
    // Blank the description:
    self->groupTabDescription.stringValue = @"";
    self->groupTabDescription.hidden = YES;
    // Disable the "join group" button:
    self->groupTabJoinButton.enabled = NO;
    // Void group table selection:
    [self->groupTabTableView deselectAll:self->groupTabTableView];
    
    NSString *searchStr;
    searchStr = self->groupTabSearchField.stringValue;
    if ([searchStr isEqual: @""]){ // Show all groups if no filter:
        self.groupsDictFilteredArray = self.groupsDictArray;
    }else{ // Filter groups otherwise:
        NSPredicate *searchQuery;
        searchQuery = [NSPredicate predicateWithFormat:@"display_name CONTAINS[cd] %@",searchStr];
        self.groupsDictFilteredArray = [self.groupsDictArray filteredArrayUsingPredicate:searchQuery];
    }
}

- (IBAction)selectedGroupFromTable:(id)sender {
    // Called when a row in the group table is highlighted.
    // Determines the selected group and populates some shared variables with
    // relevant attributes of the selected group, including its name and computer name prefix.
    // Enables or disables the "join" button as required.

    // Blank the description:
    self->groupTabDescription.stringValue = @"";
    self->groupTabDescription.hidden = YES;
    // Disable the "join group" button:
    self->groupTabJoinButton.enabled = NO;
    
    NSInteger selectedTableRowIndex;
    selectedTableRowIndex = self->groupTabTableView.selectedRow;
    
 //   NSInteger index;
    if (selectedTableRowIndex >= 0) {
        self.selectedGroupDict = [self.groupsDictFilteredArray objectAtIndex:selectedTableRowIndex];
        self.selectedGroupName =  [self.selectedGroupDict valueForKey:@"name"];
        self.selectedGroupDisplayName = [self.selectedGroupDict valueForKey:@"display_name"];
        self.selectedGroupDescription = [self.selectedGroupDict valueForKey:@"description"];
        self.selectedGroupComputerNamePrefix = [self.selectedGroupDict valueForKey:@"computer_name_prefix"];
        // Add "-" to the computer name prefix if not supplied:
        if (![self.selectedGroupComputerNamePrefix hasSuffix:@"-"]){
            self.selectedGroupComputerNamePrefix = [self.selectedGroupComputerNamePrefix stringByAppendingString:@"-"];
        }
        if (self->groupTabSearchField.isHighlighted == NO) { //Prevents goofy text being drawn if searching is in progress.
            // Show its description:
            self->groupTabDescription.stringValue = self.selectedGroupDescription;
            self->groupTabDescription.hidden = NO;
            // Enable the "join group" button:
            self->groupTabJoinButton.enabled = YES;
        }
    }
    

}

- (IBAction)clickedChangeNameOrGroupButton:(id)sender {
    // Handles these cases:
    // peTab "change name or group" button
    // confirmationTab "go back" button
    [self showGroupTab];
}
- (IBAction)clickedUseExistingNameAndGroupButton:(id)sender {
    // Handles this case:
    // peTab "use existing" button
    [self showConfirmationTabProcessing];
    [self runTransactionB];
}
- (IBAction)clickedAcceptNameAndGroupButton:(id)sender {
    // Handles this case:
    // confirmationTab "proceed" button
    [self showConfirmationTabProcessing];
    [self runTransactionB];
}
- (IBAction)clickedJoinGroupButton:(id)sender {
    // Called when the "join group" button is clicked.
    // selectedGroupName was chosen per selectedGroupFromTable()
    // Go to the name tab.
    [self showNameTab];
}
- (IBAction)clickedSetNameButton:(id)sender {
    // Called when the "set name" button is clicked.
    // Capture the name:
    self.computerName = self->nameTabComputerNameField.stringValue;
    // Go to the confirmation tab.
    [self showConfirmationTab];
}
- (IBAction)clickedStartOverButton:(id)sender {
    // Start from the top and replay that logic:
    [self applicationDidFinishLaunching:nil];
}
- (IBAction)clickedIgnoreWarningButton:(id)sender {
    // Ignore the error and continue:
    // For now, this is the only option - Move onto the enrollment script with the "transaction-a" verb:
    [self showFirstTab];
    [self showFirstTabProcessing];
    [self runTransactionA];
}
- (IBAction)clickedStopButton:(id)sender {
    // Stop running the enrollment client.
    [NSApp terminate:self];
}
- (IBAction)clickedQuitButton:(id)sender {
    // Quits the app.
    [NSApp terminate:self];
}
- (IBAction)clickedRestartButton:(id)sender {
    // Handles click from the restart button on the last tab.
    self->lastTabRestartButton.title = @"Restarting...";
    self->lastTabRestartButton.enabled = NO;
    [self runLastSteps];
}

@end
