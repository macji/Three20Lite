//
// Copyright 2009-2011 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TTURLJSONResponse.h"

// extJSON
#import "TTErrorCodes.h"
#import "JSONKit.h"
//#ifdef EXTJSON_SBJSON
//#import "extThree20JSON/SBJson.h"
//#import "extThree20JSON/NSString+SBJSON.h"
//#elif defined(EXTJSON_YAJL)
//#import "extThree20JSON/NSObject+YAJL.h"
//#endif

// Core
#import "TTCorePreprocessorMacros.h"
#import "TTDebug.h"

#define kJSONKitErrorDomain @"three20.network.jsonkit"
#define kJSONKitErrorCodeInvalidJSON 10010


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TTURLJSONResponse

@synthesize rootObject  = _rootObject;


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  TT_RELEASE_SAFELY(_rootObject);

  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTURLResponse


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSError*)request:(TTURLRequest*)request processResponse:(NSHTTPURLResponse*)response
               data:(id)data {
  // This response is designed for NSData objects, so if we get anything else it's probably a
  // mistake.
  TTDASSERT([data isKindOfClass:[NSData class]]);
  TTDASSERT(nil == _rootObject);
  NSError* err = nil;
  if ([data isKindOfClass:[NSData class]]) {
    NSString* json = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    // When there are newline characters in the JSON string, 
    // the error "Unescaped control character '0x9'" will be thrown. This removes those characters.
    json =  [json stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    _rootObject = [[json objectFromJSONString] retain];
    if (!_rootObject) {
      err = [NSError errorWithDomain:kJSONKitErrorDomain
                                code:kJSONKitErrorCodeInvalidJSON
                            userInfo:nil];
    }
  }

  return err;
}


@end

