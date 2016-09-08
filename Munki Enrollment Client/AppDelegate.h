//
//  AppDelegate.h
//  Munki Enrollment Client
//
//  Created by Gerrit E Dewitt on 8/3/15.
//  Copyright (c) 2015 Georgia State University.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    ERROR_TYPE_STOP = 1 << 0,
    ERROR_TYPE_WARNING = 1 << 1,
    ERROR_TYPE_START_OVER = 1 << 2
} errorTypes;
typedef enum {
    MUNKI_STATE_TOP_OF_LOOP = 1 << 0,
    MUNKI_STATE_CHECKING = 1 << 1,
    MUNKI_STATE_CHECK_FINISHED = 1 << 2,
    MUNKI_STATE_INSTALLING = 1 << 3,
    MUNKI_STATE_INSTALL_FINISHED = 1 << 4
} munkiStates;

@interface AppDelegate : NSObject <NSApplicationDelegate>{

    // UI:
    IBOutlet NSWindow *window;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTabViewItem *firstTab;
    IBOutlet NSTextField *firstTabLabel;
    IBOutlet NSTextField *firstTabDetails;
    IBOutlet NSProgressIndicator *firstTabIndeterminateBar;
    
    IBOutlet NSTabViewItem *peTab;
    IBOutlet NSTextField *peTabHeading;
    IBOutlet NSTextField *peTabSubheading;
    IBOutlet NSTextField *peTabActionLabel;
    IBOutlet NSTextField *peTabNameLabel;
    IBOutlet NSTextField *peTabNameDetails;
    IBOutlet NSTextField *peTabGroupLabel;
    IBOutlet NSButton *peTabChangeNameOrGroupButton;
    IBOutlet NSButton *peTabUseExistingNameAndGroupButton;
    
    IBOutlet NSTabViewItem *groupTab;
    IBOutlet NSTextField *groupTabHeading;
    IBOutlet NSTextField *groupTabSubheading;
    IBOutlet NSTextField *groupTabActionLabel;
    IBOutlet NSBox *groupTabBox;
    IBOutlet NSTextField *groupTabDescription;
    IBOutlet NSTextField *groupTabSearchField;
    IBOutlet NSTableView *groupTabTableView;
    IBOutlet NSButton *groupTabJoinButton;
    IBOutlet NSArrayController *groupTabArrayController;
    
    IBOutlet NSTabViewItem *nameTab;
    IBOutlet NSTextField *nameTabHeading;
    IBOutlet NSTextField *nameTabSubheading;
    IBOutlet NSTextField *nameTabActionLabel;
    IBOutlet NSTextField *nameTabDetails2;
    IBOutlet NSBox *nameTabComputerNameBox;
    IBOutlet NSTextField *nameTabComputerNameField;
    IBOutlet NSButton *nameTabContinueButton;
    IBOutlet NSBox *confirmationTabBox;
    
    IBOutlet NSTabViewItem *confirmationTab;
    IBOutlet NSTextField *confirmationTabHeading;
    IBOutlet NSTextField *confirmationTabSubheading;
    IBOutlet NSTextField *confirmationTabActionLabel;
    IBOutlet NSTextField *confirmationTabNameLabel;
    IBOutlet NSTextField *confirmationTabGroupLabel;
    IBOutlet NSButton *confirmationTabChangeNameOrGroupButton;
    IBOutlet NSButton *confirmationTabAcceptNameAndGroupButton;
    IBOutlet NSProgressIndicator *confirmationTabIndeterminateBar;
    
    IBOutlet NSTabViewItem *munkiTab;
    IBOutlet NSImageView *munkiTabIcon;
    IBOutlet NSTextField *munkiTabLabel;
    IBOutlet NSTextField *munkiTabDetails;
    IBOutlet NSProgressIndicator *munkiTabMeteredBar;
    IBOutlet NSProgressIndicator *munkiTabIndeterminateBar;
   
    IBOutlet NSTabViewItem *lastTab;
    IBOutlet NSImageView *lastTabIcon;
    IBOutlet NSTextField *lastTabLabel;
    IBOutlet NSTextField *lastTabDetails;
    IBOutlet NSButton *lastTabRestartButton;

    IBOutlet NSTabViewItem *errorTab;
    IBOutlet NSTextField *errorTabLabel;
    IBOutlet NSTextField *errorTabDetails;
    IBOutlet NSImageView *errorTabIcon;
    IBOutlet NSButton *errorTabStartOverButton;
    IBOutlet NSButton *errorTabIgnoreWarningButton;
    IBOutlet NSButton *errorTabStopButton;
}

//@property (weak) IBOutlet NSWindow *window;
// Shared variables:
@property NSArray *groupsDictArray;
@property NSArray *groupsDictFilteredArray;
@property NSMutableDictionary *selectedGroupDict;
@property NSString *selectedGroupName;
@property NSString *selectedGroupDisplayName;
@property NSString *selectedGroupDescription;
@property NSString *selectedGroupComputerNamePrefix;
@property NSString *computerNameSuffix;
@property NSString *computerName;
@property NSString *enrollmentScriptPath;

// Workflow logic:
@property BOOL startAtBeginning;
// Munki state, messages, loop logic:
@property BOOL rebootImminent;
@property BOOL munkiIsRunning;
@property munkiStates munkiState;
@property NSInteger munkiLoopCounter;
@property NSInteger munkiLoopCounterMaximum;
@property NSInteger munkiNotificationPercent;
@property NSString *munkiNotificationMessage;
@property NSString *munkiNotificationDetail;
@property NSString *munkiNotificationCommand;
// Error controls:
@property NSString *errorDetailStr;
@property NSString *errorLabelStr;
@property errorTypes errorType;
// File paths:
@property NSString *resultPreEnrollmentPath;
@property NSString *receivedTarFilePath;
@property NSString *transactionAFilePath;
@property NSString *transactionBFilePath;
@property NSString *resultPostEnrollmentPath;
@property NSString *munkiCheckAndInstallSemaphorePath;
// Icon filesystem paths:
@property NSString *appleWarningIconPath;
@property NSString *appleStopIconPath;
@property NSString *munkiIconPath;

// Core Procedural:
- (void)rebootSystem;
- (void)runPreEnrollment;
- (void)finishedPreEnrollment:(NSNotification *)aNotification;
- (void)runTransactionA;
- (void)finishedTransactionA:(NSNotification *)aNotification;
- (void)runTransactionB;
- (void)finishedTransactionB:(NSNotification *)aNotification;
- (void)runLastSteps;
- (void)finishedLastSteps:(NSNotification *)aNotification;

// Munki:
- (void)registerForMunkiNotifications;
- (void)munkiDidStart:(NSNotification *)aNotification;
- (void)munkiDidEnd:(NSNotification *)aNotification;
- (void)munkiDidPostStatus:(NSNotification *)aNotification;
- (void)doMunkiLoop;
- (void)runMunkiCheck;
- (void)runMunkiInstall;
- (void)finishedMunkiCheck:(NSNotification *)aNotification;
- (void)finishedMunkiInstall:(NSNotification *)aNotification;

// UI Refresh:
- (void)showFirstTab;
- (void)showFirstTabProcessing;
- (void)showPETab;
- (void)showGroupTab;
- (void)showNameTab;
- (void)showConfirmationTab;
- (void)showConfirmationTabProcessing;
- (void)showMunkiTab;
- (void)showErrorTab;
- (void)showLastTab;
- (void)loadIcons;
- (void)hideAllMunkiBars;
- (void)showMunkiIndeterminateBar;
- (void)showMunkiMeteredBar;
// Actions specific to name tab:
- (void)formatComputerNameField:(NSNotification *)aNotification;

// UI Actions:
// Button actions:
- (IBAction)clickedAcceptNameAndGroupButton:(id)sender;
- (IBAction)clickedChangeNameOrGroupButton:(id)sender;
- (IBAction)clickedUseExistingNameAndGroupButton:(id)sender;
- (IBAction)clickedJoinGroupButton:(id)sender;
- (IBAction)clickedSetNameButton:(id)sender;
- (IBAction)clickedStartOverButton:(id)sender;
- (IBAction)clickedIgnoreWarningButton:(id)sender;
- (IBAction)clickedStopButton:(id)sender;
- (IBAction)clickedQuitButton:(id)sender;
- (IBAction)clickedRestartButton:(id)sender;

// Actions specific to groups tab:
- (IBAction)filterGroupsDictArray:(id)sender;
- (IBAction)selectedGroupFromTable:(id)sender;


@end

