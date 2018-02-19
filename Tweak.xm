#include <substrate.h>
#include <CoreFoundation/CoreFoundation.h>
#include <notify.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

#if __cplusplus
extern "C" {
#endif

	CFSetRef SBSCopyDisplayIdentifiers();
	NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);

#if __cplusplus
}
#endif

@interface AppWirelessDataUsageManager : NSObject {

	BOOL _showInternalDetails;
	BOOL _cancelled;
	NSArray* _managedBundleIDs;

}

@property (getter=isCancelled) BOOL cancelled;                          //@synthesize cancelled=_cancelled - In the implementation block
@property (nonatomic,readonly) NSArray * managedBundleIDs;              //@synthesize managedBundleIDs=_managedBundleIDs - In the implementation block
@property (nonatomic,readonly) BOOL showInternalDetails;                //@synthesize showInternalDetails=_showInternalDetails - In the implementation block
+(id)displayNameForAppProxy:(id)arg1 ;
+(NSString *)displayNameForBundleIdentifier:(NSString *)arg1 ;
+(id)coverBundleIdentifiersForBundleIdentifierDict;
+(id)displayNameForBundleIdentifiers:(id)arg1 ;
+(id)coverDisplayNameForAppProxy:(id)arg1 ;
+(id)dataUsageWorkspace;
+(id)forcedBundleIdentiferForBundleIdentifier:(id)arg1 ;
+(id)omittedBundleIdentifiers;
+(void)retrieveDataUsageWorkspaceInfo:(id)arg1 ;
+(void)setAppCellularDataEnabled:(id)arg1 forBundleIdentifier:(id)arg2 completionHandler:(/*^block*/id)arg3 ;
+(id)appCellularDataEnabledForBundleIdentifier:(id)arg1 modificationAllowed:(BOOL*)arg2 ;
+(void)setAppWirelessDataOption:(id)arg1 forBundleIdentifier:(id)arg2 completionHandler:(/*^block*/id)arg3 ;
+(id)appWirelessDataOptionForBundleIdentifier:(id)arg1 ;
-(id)init;
-(void)cancel;
-(void)dealloc;
-(BOOL)isCancelled;
-(void)setCancelled:(BOOL)arg1 ;
-(id)managedCellularDataBundleIdentifiers;
-(NSArray *)managedBundleIDs;
-(id)alwaysDisplayedBundleIdentifiers;
-(void)_categorizeApps:(id)arg1 callback:(/*^block*/id)arg2 ;
-(void)_handleDataUsageInfoChanged;
-(void)_handleSIMStatusReady;
-(void)calculateDataUsageWithWorkspace:(id)arg1 completionHandler:(/*^block*/id)arg2 ;
-(BOOL)showInternalDetails;
@end

NSString *useWifiFor;

@interface APNetworksController : PSListController
@property (nonatomic, retain) NSMutableDictionary *wifiUsage;
-(NSDictionary*)trimDataSource:(NSDictionary*)dataSource;
-(NSDictionary*)sortedDictionary:(NSDictionary*)dict;
@end

@interface APSettingsController : PSListController
@property (nonatomic, retain) NSMutableDictionary *wifiUsage;
-(NSDictionary*)trimDataSource:(NSDictionary*)dataSource;
-(NSDictionary*)sortedDictionary:(NSDictionary*)dict;
@end


%group Preferences
%hook APNetworksController
%property (nonatomic, retain) NSMutableDictionary *wifiUsage;

- (NSMutableArray *)specifiers {
    NSMutableArray *specifiers = %orig;

    NSArray *displayIdentifiers = [(__bridge NSSet *)SBSCopyDisplayIdentifiers() allObjects];

    NSMutableDictionary *apps = [NSMutableDictionary new];
    for (NSString *appIdentifier in displayIdentifiers) {
    	NSString *forcedBundleIdentifier = [NSClassFromString(@"AppWirelessDataUsageManager") forcedBundleIdentiferForBundleIdentifier:appIdentifier];
    	if (!forcedBundleIdentifier)
    		forcedBundleIdentifier = appIdentifier;
        NSString *appName = [NSClassFromString(@"AppWirelessDataUsageManager") displayNameForBundleIdentifier:forcedBundleIdentifier];
        if (appName) {
            [apps setObject:appName forKey:forcedBundleIdentifier];
        }
    }

  	NSDictionary *finalApps = [apps copy];
    finalApps = [self trimDataSource:finalApps];
    finalApps = [self sortedDictionary:finalApps];

    if (!useWifiFor) {
    	NSString *useCellularDataFor = [[NSBundle bundleWithIdentifier:@"com.apple.preferences-ui-framework"] localizedStringForKey:@"USE_CELLULAR_DATA" value:@"" table:@"Network"];
		NSString *cellularData = [[NSBundle bundleWithIdentifier:@"com.apple.preferences-ui-framework"] localizedStringForKey:@"MOBILE_DATA_SETTINGS" value:@"" table:@"Network"];
		NSString *wifi = [[NSBundle bundleWithIdentifier:@"com.apple.settings.airport"] localizedStringForKey:@"Wi-Fi" value:@"" table:@"AirPort"];
		useWifiFor = [useCellularDataFor stringByReplacingOccurrencesOfString:cellularData withString:wifi];
    }

    PSSpecifier *wifiLabel = [%c(PSSpecifier) preferenceSpecifierNamed:useWifiFor
					target:self
					   set:NULL
					   get:NULL
					detail:Nil
					  cell:PSGroupCell
					  edit:Nil];

  	[wifiLabel setProperty:useWifiFor forKey:@"label"];
  	[wifiLabel setProperty:@"wifi_label" forKey:@"id"];
  	[specifiers addObject:wifiLabel];
  
  	NSMutableArray *applicationSpecifiers = [NSMutableArray new];
  
  	for (NSString *displayIdentifier in finalApps.allKeys) {
        NSString *displayName = finalApps[displayIdentifier];
        PSSpecifier *specifier = [%c(PSSpecifier) preferenceSpecifierNamed:displayName target:self set:@selector(setWifiUsageValue:forSpecifier:) get:@selector(wifiUsageValueForSpecifier:) detail:nil cell:PSSwitchCell edit:nil];
        [specifier setProperty:displayIdentifier forKey:@"appIDForLazyIcon"];
        [specifier setProperty:@YES forKey:@"useLazyIcons"];
        [applicationSpecifiers addObject:specifier];

    }
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    [applicationSpecifiers sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    [specifiers addObjectsFromArray:applicationSpecifiers];
    return specifiers;
}

%new
- (void)setWifiUsageValue:(id)value forSpecifier:(PSSpecifier *)specifier {

	BOOL modAllowed = NO;
	NSNumber *cellularData = [NSClassFromString(@"AppWirelessDataUsageManager") appCellularDataEnabledForBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"] modificationAllowed:&modAllowed];

	BOOL cellularEnabled = [cellularData isEqual:@YES];

	if ([value isEqual:@YES]) {
		if (cellularEnabled) {
			[NSClassFromString(@"AppWirelessDataUsageManager") setAppWirelessDataOption:@3 forBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"] completionHandler:nil];
		} else {
			[NSClassFromString(@"AppWirelessDataUsageManager") setAppWirelessDataOption:@1 forBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"] completionHandler:nil];
		}
	} else {
		if (cellularEnabled) {
			[NSClassFromString(@"AppWirelessDataUsageManager") setAppWirelessDataOption:@2 forBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"] completionHandler:nil];
		} else {
			[NSClassFromString(@"AppWirelessDataUsageManager") setAppWirelessDataOption:@0 forBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"] completionHandler:nil];
		}
	}

}
%new
- (id)wifiUsageValueForSpecifier:(PSSpecifier *)specifier {


	NSNumber *wirelessOption = [NSClassFromString(@"AppWirelessDataUsageManager") appWirelessDataOptionForBundleIdentifier:[specifier propertyForKey:@"appIDForLazyIcon"]];

	if ([wirelessOption isEqual:@3] || [wirelessOption isEqual:@1]) {
		return @YES;
	} else {
		return @NO;
	}
}

%new
-(NSDictionary*)trimDataSource:(NSDictionary*)dataSource {
    NSMutableDictionary *mutableDict = [dataSource mutableCopy];
    
    NSArray *bannedIdentifiers = [[NSArray alloc] initWithObjects:
                                  @"com.apple.AdSheet",
                                  @"com.apple.AdSheetPhone",
                                  @"com.apple.AdSheetPad",
                                  @"com.apple.DataActivation",
                                  @"com.apple.DemoApp",
                                  @"com.apple.fieldtest",
                                  @"com.apple.iosdiagnostics",
                                  @"com.apple.iphoneos.iPodOut",
                                  @"com.apple.TrustMe",
                                  @"com.apple.WebSheet",
                                  @"com.apple.springboard",
                                  @"com.apple.purplebuddy",
                                  @"com.apple.datadetectors.DDActionsService",
                                  @"com.apple.FacebookAccountMigrationDialog",
                                  @"com.apple.iad.iAdOptOut",
                                  @"com.apple.ios.StoreKitUIService",
                                  @"com.apple.TextInput.kbd",
                                  @"com.apple.MailCompositionService",
                                  @"com.apple.mobilesms.compose",
                                  @"com.apple.quicklook.quicklookd",
                                  @"com.apple.ShoeboxUIService",
                                  @"com.apple.social.remoteui.SocialUIService",
                                  @"com.apple.WebViewService",
                                  @"com.apple.gamecenter.GameCenterUIService",
                                  @"com.apple.appleaccount.AACredentialRecoveryDialog",
                                  @"com.apple.CompassCalibrationViewService",
                                  @"com.apple.WebContentFilter.remoteUI.WebContentAnalysisUI",
                                  @"com.apple.PassbookUIService",
                                  @"com.apple.uikit.PrintStatus",
                                  @"com.apple.Copilot",
                                  @"com.apple.MusicUIService",
                                  @"com.apple.AccountAuthenticationDialog",
                                  @"com.apple.MobileReplayer",
                                  @"com.apple.SiriViewService",
                                  @"com.apple.TencentWeiboAccountMigrationDialog",
                                  @"com.apple.AskPermissionUI",
                                  @"com.apple.Diagnostics",
                                  @"com.apple.GameController",
                                  @"com.apple.HealthPrivacyService",
                                  @"com.apple.InCallService",
                                  @"com.apple.mobilesms.notification",
                                  @"com.apple.PhotosViewService",
                                  @"com.apple.PreBoard",
                                  @"com.apple.PrintKit.Print-Center",
                                  @"com.apple.SharedWebCredentialViewService",
                                  @"com.apple.share",
                                  @"com.apple.CoreAuthUI",
                                  @"com.apple.webapp",
                                  @"com.apple.webapp1",
                                  @"com.apple.family",
                                  nil];
    for (NSString *key in bannedIdentifiers) {
        [mutableDict removeObjectForKey:key];
    }
    
    return [mutableDict copy];
}

%new
-(NSDictionary*)sortedDictionary:(NSDictionary*)dict {
    NSArray *sortedValues;
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];
    
    sortedValues = [[dict allValues] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    for (NSString *value in sortedValues) {
        // Get key for value.
        NSString *key = [[dict allKeysForObject:value] objectAtIndex:0];
        
        [mutableDict setObject:value forKey:key];
    }
    
    return [mutableDict copy];
}
%end

%hook WFAirportViewController
- (BOOL)_isChinaDevice {
  return TRUE;
}
%end
%end

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	if ([((__bridge NSDictionary *)userInfo)[NSLoadedClasses] containsObject:@"APNetworksController"]) { // The Network Bundle is Loaded
		%init(Preferences);
	}
}

%ctor {
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.Preferences"]) {
		CFNotificationCenterAddObserver(
			CFNotificationCenterGetLocalCenter(), NULL,
			notificationCallback,
			(CFStringRef)NSBundleDidLoadNotification,
			NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
	%init;
}











