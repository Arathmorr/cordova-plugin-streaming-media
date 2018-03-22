#import "StreamingMedia.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface StreamingMedia()
- (void)parseOptions:(NSDictionary *) options type:(NSString *) type;
- (void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type;
- (void)setBackgroundColor:(NSString *)color;
- (void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType;
- (UIImage*)getImage: (NSString *)imageName;
- (void)startPlayer:(NSString*)uri;
- (void)moviePlayBackDidFinish:(NSNotification*)notification;
- (void)cleanup;
- (void)setHeaders:(NSString*)user sid:(NSString*)sid;


@end

@implementation StreamingMedia {
    NSString* callbackId;
    AVPlayerViewController *moviePlayer;
    //AVPlayer *avPlayer; //new
    BOOL shouldAutoClose;
    UIColor *backgroundColor;
    UIImageView *imageView;
    BOOL initFullscreen;
    NSString *user;
    NSString *sid;
}

NSString * const TYPE_VIDEO = @"VIDEO";
NSString * const TYPE_AUDIO = @"AUDIO";
NSString * const DEFAULT_IMAGE_SCALE = @"center";

-(void)parseOptions:(NSDictionary *)options type:(NSString *) type {
    // Common options
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"shouldAutoClose"]) {
        shouldAutoClose = [[options objectForKey:@"shouldAutoClose"] boolValue];
    } else {
        shouldAutoClose = YES;
    }
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
        [self setBackgroundColor:[options objectForKey:@"bgColor"]];
    } else {
        backgroundColor = [UIColor blackColor];
    }
    
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"initFullscreen"]) {
        initFullscreen = [[options objectForKey:@"initFullscreen"] boolValue];
    } else {
        initFullscreen = YES;
    }
    
    if ([type isEqualToString:TYPE_AUDIO]) {
        // bgImage
        // bgImageScale
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImage"]) {
            NSString *imageScale = DEFAULT_IMAGE_SCALE;
            if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImageScale"]) {
                imageScale = [options objectForKey:@"bgImageScale"];
            }
            [self setImage:[options objectForKey:@"bgImage"] withScaleType:imageScale];
        }
        // bgColor
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
            NSLog(@"Found option for bgColor");
            [self setBackgroundColor:[options objectForKey:@"bgColor"]];
        } else {
            backgroundColor = [UIColor blackColor];
        }
    }
    // No specific options for video yet
    
    // Set headers in container.
    
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"user"]) {
        user = [options objectForKey:@"user"];
        sid = [options objectForKey:@"sid"];
    }
}

-(void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    callbackId = command.callbackId;
    NSString *mediaUrl  = [command.arguments objectAtIndex:0];
    [self parseOptions:[command.arguments objectAtIndex:1] type:type];
    
    [self startPlayer:mediaUrl]; //todo add headers
}

-(void)stop:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    callbackId = command.callbackId;
    if (moviePlayer.player) {
        [moviePlayer.player pause];
    }
}

-(void)playVideo:(CDVInvokedUrlCommand *) command {
    [self play:command type:[NSString stringWithString:TYPE_VIDEO]];
}

-(void)playAudio:(CDVInvokedUrlCommand *) command {
    [self play:command type:[NSString stringWithString:TYPE_AUDIO]];
}

-(void)stopAudio:(CDVInvokedUrlCommand *) command {
    [self stop:command type:[NSString stringWithString:TYPE_AUDIO]];
}

-(void) setBackgroundColor:(NSString *)color {
    if ([color hasPrefix:@"#"]) {
        // HEX value
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:color];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        backgroundColor = [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
    } else {
        // Color name
        NSString *selectorString = [[color lowercaseString] stringByAppendingString:@"Color"];
        SEL selector = NSSelectorFromString(selectorString);
        UIColor *colorObj = [UIColor blackColor];
        if ([UIColor respondsToSelector:selector]) {
            colorObj = [UIColor performSelector:selector];
        }
        backgroundColor = colorObj;
    }
}

-(UIImage*)getImage: (NSString *)imageName {
    UIImage *image = nil;
    if (imageName != (id)[NSNull null]) {
        if ([imageName hasPrefix:@"http"]) {
            // Web image
            image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageName]]];
        } else if ([imageName hasPrefix:@"www/"]) {
            // Asset image
            image = [UIImage imageNamed:imageName];
        } else if ([imageName hasPrefix:@"file://"]) {
            // Stored image
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSURL URLWithString:imageName] path]]];
        } else if ([imageName hasPrefix:@"data:"]) {
            // base64 encoded string
            NSURL *imageURL = [NSURL URLWithString:imageName];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            image = [UIImage imageWithData:imageData];
        } else {
            // explicit path
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:imageName]];
        }
    }
    return image;
}

- (void)orientationChanged:(NSNotification *)notification {
    if (imageView != nil) {
        // adjust imageView for rotation
        // imageView.bounds = moviePlayer.backgroundView.bounds;
        // imageView.frame = moviePlayer.backgroundView.frame;
    }
}

-(void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType {
    imageView = [[UIImageView alloc] initWithFrame:self.viewController.view.bounds];
    if (imageScaleType == nil) {
        NSLog(@"imagescaletype was NIL");
        imageScaleType = DEFAULT_IMAGE_SCALE;
    }
    if ([imageScaleType isEqualToString:@"stretch"]){
        // Stretches image to fill all available background space, disregarding aspect ratio
        imageView.contentMode = UIViewContentModeScaleToFill;
        //moviePlayer.backgroundView.contentMode = UIViewContentModeScaleToFill;
    } else if ([imageScaleType isEqualToString:@"fit"]) {
        // Stretches image to fill all possible space while retaining aspect ratio
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        //moviePlayer.backgroundView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        // Places image in the center of the screen
        imageView.contentMode = UIViewContentModeCenter;
        //moviePlayer.backgroundView.contentMode = UIViewContentModeCenter;
    }
    
    [imageView setImage:[self getImage:imagePath]];
}

-(void)startPlayer:(NSString*)uri { //add headers

    NSString* theURLString = [NSString stringWithFormat:@"dfuzeProtocol://%@", uri];
    NSURL *url = [NSURL URLWithString:theURLString];
    AVPlayer *movie =  [AVPlayer playerWithURL:url];
    moviePlayer = [[AVPlayerViewController alloc] init];
    
    [moviePlayer setPlayer: movie];
    [moviePlayer setShowsPlaybackControls:YES];
    if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }

    [self.viewController presentViewController:moviePlayer animated:YES completion:^(void){
        [moviePlayer.player play];
    }];
    
    
    // Listen for playback finishing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];
    // Listen for errors
    [[NSNotificationCenter defaultCenter] addObserver: self
                                            selector:@selector(moviePlayBackDidFinish:)
                                                name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];
    // Listen for orientation change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    NSLog(@"Playback did finish with auto close being %d, and error message being %@", shouldAutoClose, notification.userInfo);
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSNumber *errorValue = [notificationUserInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSString *errorMsg;
    if (errorValue) {
        NSError *mediaPlayerError = [notificationUserInfo objectForKey:@"error"];
        if (mediaPlayerError) {
            errorMsg = [mediaPlayerError localizedDescription];
        } else {
            errorMsg = @"Unknown error.";
        }
        NSLog(@"Playback failed: %@", errorMsg);
    }
    
    if (shouldAutoClose || [errorMsg length] != 0) {
        [self cleanup];
        CDVPluginResult* pluginResult;
        if ([errorMsg length] != 0) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMsg];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }
}

- (void)cleanup {
    NSLog(@"Clean up");
    imageView = nil;
    initFullscreen = false;
    backgroundColor = nil;
    
    // Remove playback finished listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemDidPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove playback finished listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemFailedToPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove orientation change listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];
    
    if (moviePlayer) {
        [moviePlayer.player pause];
        [moviePlayer dismissViewControllerAnimated:YES completion:nil];
        moviePlayer = nil;
    }
}
@end

