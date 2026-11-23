#import "PermissionHandlerPlugin.h"


@implementation PermissionHandlerPlugin {
    PermissionManager *_Nonnull _permissionManager;
    _Nullable FlutterResult _methodResult;
}

- (instancetype)initWithPermissionManager:(PermissionManager *)permissionManager {
    self = [super init];
    if (self) {
        _permissionManager = permissionManager;
    }
    
    return self;
}

+ (void)registerWithRegistrar:(NSObject <FlutterPluginRegistrar> *)registrar {
    // Log when the macros pinned in Package.swift differ from the app's Info.plist.
#ifndef PERMISSION_LOCATION_WHENINUSE
#define PERMISSION_LOCATION_WHENINUSE 0
#endif
#define PH_MACRO(m) @[@#m, @(m)]
    NSDictionary<NSString *, NSArray *> *macros = @{
        @"NSCalendarsUsageDescription": PH_MACRO(PERMISSION_EVENTS),
        @"NSCalendarsFullAccessUsageDescription": PH_MACRO(PERMISSION_EVENTS_FULL_ACCESS),
        @"NSRemindersUsageDescription": PH_MACRO(PERMISSION_REMINDERS),
        @"NSContactsUsageDescription": PH_MACRO(PERMISSION_CONTACTS),
        @"NSCameraUsageDescription": PH_MACRO(PERMISSION_CAMERA),
        @"NSMicrophoneUsageDescription": PH_MACRO(PERMISSION_MICROPHONE),
        @"NSSpeechRecognitionUsageDescription": PH_MACRO(PERMISSION_SPEECH_RECOGNIZER),
        @"NSPhotoLibraryUsageDescription": PH_MACRO(PERMISSION_PHOTOS),
        @"NSLocationAlwaysAndWhenInUseUsageDescription": PH_MACRO(PERMISSION_LOCATION),
        @"NSLocationWhenInUseUsageDescription": PH_MACRO(PERMISSION_LOCATION_WHENINUSE),
        @"NSAppleMusicUsageDescription": PH_MACRO(PERMISSION_MEDIA_LIBRARY),
        @"NSMotionUsageDescription": PH_MACRO(PERMISSION_SENSORS),
        @"NSBluetoothAlwaysUsageDescription": PH_MACRO(PERMISSION_BLUETOOTH),
        @"NSUserTrackingUsageDescription": PH_MACRO(PERMISSION_APP_TRACKING_TRANSPARENCY),
        @"NSSiriUsageDescription": PH_MACRO(PERMISSION_ASSISTANT),
    };
#undef PH_MACRO
    [macros enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSArray *macro, BOOL *stop) {
        BOOL declared = [[NSBundle mainBundle] objectForInfoDictionaryKey:key] != nil;
        if (declared != [macro[1] boolValue]) {
            NSLog(@"[permission_handler_apple] warning: Info.plist %@ %@, but %@=%@ in Package.swift.",
                  declared ? @"declares" : @"lacks", key, macro[0], macro[1]);
        }
    }];

    FlutterMethodChannel *channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter.baseflow.com/permissions/methods"
                                     binaryMessenger:[registrar messenger]];
    PermissionManager *permissionManager = [[PermissionManager alloc] initWithStrategyInstances];
    PermissionHandlerPlugin *instance = [[PermissionHandlerPlugin alloc] initWithPermissionManager:permissionManager];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"checkPermissionStatus" isEqualToString:call.method]) {
        PermissionGroup permission = [Codec decodePermissionGroupFrom:call.arguments];
        [PermissionManager checkPermissionStatus:permission result:result];
    } else if ([@"checkServiceStatus" isEqualToString:call.method]) {
        PermissionGroup permission = [Codec decodePermissionGroupFrom:call.arguments];
        [PermissionManager checkServiceStatus:permission result:result];
    } else if ([@"requestPermissions" isEqualToString:call.method]) {
        if (_methodResult != nil) {
            result([FlutterError errorWithCode:@"ERROR_ALREADY_REQUESTING_PERMISSIONS" message:@"A request for permissions is already running, please wait for it to finish before doing another request (note that you can request multiple permissions at the same time)." details:nil]);
            return;
        }
        
        _methodResult = result;
        NSArray *permissions = [Codec decodePermissionGroupsFrom:call.arguments];
        
        [_permissionManager
         requestPermissions:permissions completion:^(NSDictionary *permissionRequestResults) {
             if (self->_methodResult != nil) {
                 self->_methodResult(permissionRequestResults);
             }
             
             self->_methodResult = nil;
        } errorHandler:^(NSString *errorCode, NSString *errorDescription) {
            self->_methodResult([FlutterError errorWithCode:errorCode message:errorDescription details:nil]);
            self->_methodResult = nil;
        }
];
        
    } else if ([@"shouldShowRequestPermissionRationale" isEqualToString:call.method]) {
        result(@false);
    } else if ([@"openAppSettings" isEqualToString:call.method]) {
        [PermissionManager openAppSettings:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
