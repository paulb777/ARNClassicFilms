//
//  ARNArchiveController.h
//  classicFilms
//
//  Created by Stefan Arn on 12/10/15.
//  Copyright © 2015 Stefan Arn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPSessionManager.h"

@interface ARNArchiveController : NSObject

+ (ARNArchiveController *)sharedInstance;
- (void)fetchMovieArchiveForCollection:(NSString *)collection withManager:(AFHTTPSessionManager *)manager;

@end
