//
//  LoopMeIdentityProvider.h
//  LoopMeSDK
//
//  Created by Dmitriy Lihachov on 11/11/13.
//  Copyright (c) 2013 LoopMe. All rights reserved.
//

@interface LoopMeIdentityProvider : NSObject

+ (BOOL)advertisingTrackingEnabled;
+ (NSString *)advertisingTrackingDeviceIdentifier;
+ (NSString *)deviceModel;
+ (NSString *)deviceType;
+ (NSString *)phoneName;

@end
