
#import "RNCloudFs.h"
#import <UIKit/UIKit.h>
#if __has_include(<React/RCTBridgeModule.h>)
  #import <React/RCTBridgeModule.h>
#else
  #import "RCTBridgeModule.h"
#endif
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <React/RCTLog.h>

@implementation RNCloudFs

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("RNCloudFs.queue", DISPATCH_QUEUE_SERIAL);
}

RCT_EXPORT_MODULE()

//see https://developer.apple.com/library/content/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html

RCT_EXPORT_METHOD(createFile:(NSDictionary *) options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *content = [options objectForKey:@"content"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];

    NSError *error;
    [content writeToFile:tempFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if(error) {
        return reject(@"error", error.description, nil);
    }

    [self moveToICloudDirectory:documentsFolder :tempFile :destinationPath :resolve :reject];
}

RCT_EXPORT_METHOD(fileExists:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSURL *ubiquityURL = documentsFolder ? [self icloudDocumentsDirectory] : [self icloudDirectory];

    if (ubiquityURL) {
        NSURL* dir = [ubiquityURL URLByAppendingPathComponent:destinationPath];
        NSString* dirPath = [dir.path stringByStandardizingPath];

        bool exists = [fileManager fileExistsAtPath:dirPath];

        return resolve(@(exists));
    } else {
        RCTLogTrace(@"Could not retrieve a ubiquityURL");
        return reject(@"error", [NSString stringWithFormat:@"could access iCloud drive '%@'", destinationPath], nil);
    }
}

RCT_EXPORT_METHOD(statusOfFileInCloud:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSURL *ubiquityURL = documentsFolder ? [self icloudDocumentsDirectory] : [self icloudDirectory];

    if (!ubiquityURL) {
       RCTLogTrace(@"Could not retrieve a ubiquityURL");
       return reject(@"error", [NSString stringWithFormat:@"Could not retrieve a ubiquityURL '%@'", destinationPath], nil);
    }

    NSURL* fileURL = [ubiquityURL URLByAppendingPathComponent:destinationPath];
    NSError *error;
    NSNumber *isUbiquitous;
    NSString *uploadingStatus = nil;
    NSString *uploadedStatus = nil;
    NSString *uploadingError = nil;
    NSString *downloadingStatus = nil;
    NSString *downloadingError = nil;
    
    [fileURL getResourceValue:&uploadingStatus forKey:NSURLUbiquitousItemIsUploadingKey error:&error];
    if (error) {
       RCTLogTrace(@"Error checking iCloud uploading status: %@", error);
       return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud uploading status: %@", error.localizedDescription], nil);
    }
    
    [fileURL getResourceValue:&uploadedStatus forKey:NSURLUbiquitousItemIsUploadedKey error:&error];
    if (error) {
       RCTLogTrace(@"Error checking iCloud uploaded status: %@", error);
       return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud uploaded status: %@", error.localizedDescription], nil);
    }
    
    [fileURL getResourceValue:&uploadingError forKey:NSURLUbiquitousItemUploadingErrorKey error:&error];
    if (error) {
       RCTLogTrace(@"Error checking iCloud uploading error: %@", error);
       return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud uploading error: %@", error.localizedDescription], nil);
    }
    
    [fileURL getResourceValue:&downloadingStatus forKey:NSURLUbiquitousItemDownloadingStatusKey error:&error];
    if (error) {
       RCTLogTrace(@"Error checking iCloud downloading status: %@", error);
       return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud downloading status: %@", error.localizedDescription], nil);
    }
    
    [fileURL getResourceValue:&downloadingError forKey:NSURLUbiquitousItemDownloadingErrorKey error:&error];
    if (error) {
       RCTLogTrace(@"Error checking iCloud downloading error: %@", error);
       return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud downloading error: %@", error.localizedDescription], nil);
    }
    
    [fileURL getResourceValue:&isUbiquitous forKey:NSURLIsUbiquitousItemKey error:&error];
    if (error) {
        RCTLogTrace(@"Error checking iCloud isUbiquitous: %@", error);
        return reject(@"error", [NSString stringWithFormat:@"Error checking iCloud isUbiquitous: %@", error.localizedDescription], nil);
    }
    
    RCTLogTrace(@">>> %@ %@ %@ %@", isUbiquitous, uploadingStatus, uploadedStatus, downloadingStatus);
    
    NSDictionary *dictRes = @{
                    @"isUbiquitous":isUbiquitous ? isUbiquitous : @"",
                    @"uploadingStatus":uploadingStatus ? uploadingStatus : @"",
                    @"uploadedStatus":uploadedStatus ? uploadedStatus : @"",
                    @"uploadingError": uploadingError ? uploadingError : @"",
                    @"downloadingStatus":downloadingStatus ? downloadingStatus : @"",
                    @"downloadingError":downloadingError ? downloadingError : @"",
                    };
    
    return resolve(dictRes);
}

RCT_EXPORT_METHOD(getFilePath:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSURL *ubiquityURL = documentsFolder ? [self icloudDocumentsDirectory] : [self icloudDirectory];

    if (ubiquityURL) {
        NSURL* dir = [ubiquityURL URLByAppendingPathComponent:destinationPath];
        NSString* dirPath = [dir.path stringByStandardizingPath];

        bool exists = [fileManager fileExistsAtPath:dirPath];
        if (exists) {
            resolve(dirPath);
        } else {
            return resolve(@(exists));
        }

    } else {
        RCTLogTrace(@"Could not retrieve a ubiquityURL");
        return reject(@"error", [NSString stringWithFormat:@"could access iCloud drive '%@'", destinationPath], nil);
    }
}

RCT_EXPORT_METHOD(listFiles:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];

    NSURL *ubiquityURL = documentsFolder ? [self icloudDocumentsDirectory] : [self icloudDirectory];

    if (ubiquityURL) {
        NSURL* target = [ubiquityURL URLByAppendingPathComponent:destinationPath];

        NSMutableArray<NSDictionary *> *fileData = [NSMutableArray new];

        NSError *error = nil;

        BOOL isDirectory;
        [fileManager fileExistsAtPath:[target path] isDirectory:&isDirectory];

        NSURL *dirPath;
        NSArray *contents;
        if(isDirectory) {
            contents = [fileManager contentsOfDirectoryAtPath:[target path] error:&error];
            dirPath = target;
        } else {
            contents = @[[target lastPathComponent]];
            dirPath = [target URLByDeletingLastPathComponent];
        }

        if(error) {
            return reject(@"error", error.description, nil);
        }

        [contents enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
            NSURL *fileUrl = [dirPath URLByAppendingPathComponent:object];

            NSError *error;
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:[fileUrl path] error:&error];
            if(error) {
                RCTLogTrace(@"problem getting attributes for %@", [fileUrl path]);
                //skip this one
                return;
            }

            NSFileAttributeType type = [attributes objectForKey:NSFileType];

            bool isDir = type == NSFileTypeDirectory;
            bool isFile = type == NSFileTypeRegular;

            if(!isDir && !isFile)
                return;

            NSDate* modDate = [attributes objectForKey:NSFileModificationDate];

            NSURL *shareUrl = [fileManager URLForPublishingUbiquitousItemAtURL:fileUrl expirationDate:nil error:&error];

            [fileData addObject:@{
                                  @"name": object,
                                  @"path": [fileUrl path],
                                  @"uri": shareUrl ? [shareUrl absoluteString] : [NSNull null],
                                  @"size": [attributes objectForKey:NSFileSize],
                                  @"lastModified": [dateFormatter stringFromDate:modDate],
                                  @"isDirectory": @(isDir),
                                  @"isFile": @(isFile)
                                  }];
        }];

        if (error) {
            return reject(@"error", [NSString stringWithFormat:@"could not copy to iCloud drive '%@'", destinationPath], error);
        }

        NSString *relativePath = [[dirPath path] stringByReplacingOccurrencesOfString:[ubiquityURL path] withString:@"."];

        return resolve(@{
                         @"files": fileData,
                         @"path": relativePath
                         });

    } else {
        NSLog(@"Could not retrieve a ubiquityURL");
        return reject(@"error", [NSString stringWithFormat:@"could not copy to iCloud drive '%@'", destinationPath], nil);
    }
}

RCT_EXPORT_METHOD(copyToCloud:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    // mimeType is ignored for iOS
    NSDictionary *source = [options objectForKey:@"sourcePath"];
    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;

    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSString *sourceUri = [source objectForKey:@"uri"];
    if(!sourceUri) {
        sourceUri = [source objectForKey:@"path"];
    }

    if([sourceUri hasPrefix:@"assets-library"]){
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];

        [library assetForURL:[NSURL URLWithString:sourceUri] resultBlock:^(ALAsset *asset) {

            ALAssetRepresentation *rep = [asset defaultRepresentation];

            Byte *buffer = (Byte*)malloc(rep.size);
            NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
            NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];

            if (data) {
                NSString *filename = [sourceUri lastPathComponent];
                NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
                [data writeToFile:tempFile atomically:YES];
                [self moveToICloudDirectory:documentsFolder :tempFile :destinationPath :resolve :reject];
            } else {
                RCTLogTrace(@"source file does not exist %@", sourceUri);
                return reject(@"error", [NSString stringWithFormat:@"failed to copy asset '%@'", sourceUri], nil);
            }
        } failureBlock:^(NSError *error) {
            RCTLogTrace(@"source file does not exist %@", sourceUri);
            return reject(@"error", error.description, nil);
        }];
    } else if ([sourceUri hasPrefix:@"file:/"] || [sourceUri hasPrefix:@"/"]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^file:/+" options:NSRegularExpressionCaseInsensitive error:nil];
        NSString *modifiedSourceUri = [regex stringByReplacingMatchesInString:sourceUri options:0 range:NSMakeRange(0, [sourceUri length]) withTemplate:@"/"];

        if ([fileManager fileExistsAtPath:modifiedSourceUri isDirectory:nil]) {
            NSURL *sourceURL = [NSURL fileURLWithPath:modifiedSourceUri];

            // todo: figure out how to *copy* to icloud drive
            // ...setUbiquitous will move the file instead of copying it, so as a work around lets copy it to a tmp file first
            NSString *filename = [sourceUri lastPathComponent];
            NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

            NSError *error;
            [fileManager copyItemAtPath:[sourceURL path] toPath:tempFile error:&error];
            if(error) {
                return reject(@"error", error.description, nil);
            }

            [self moveToICloudDirectory:documentsFolder :tempFile :destinationPath :resolve :reject];
        } else {
            NSLog(@"source file does not exist %@", sourceUri);
            return reject(@"error", [NSString stringWithFormat:@"no such file or directory, open '%@'", sourceUri], nil);
        }
    } else {
        NSURL *url = [NSURL URLWithString:sourceUri];
        NSData *urlData = [NSData dataWithContentsOfURL:url];

        if (urlData) {
            NSString *filename = [sourceUri lastPathComponent];
            NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
            [urlData writeToFile:tempFile atomically:YES];
            [self moveToICloudDirectory:documentsFolder :tempFile :destinationPath :resolve :reject];
        } else {
            RCTLogTrace(@"source file does not exist %@", sourceUri);
            return reject(@"error", [NSString stringWithFormat:@"cannot download '%@'", sourceUri], nil);
        }
    }
}

RCT_EXPORT_METHOD(downloadFromCloud:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {


    NSString *destinationPath = [options objectForKey:@"targetPath"];
    NSString *scope = [options objectForKey:@"scope"];
    bool documentsFolder = !scope || [scope caseInsensitiveCompare:@"visible"] == NSOrderedSame;


    NSString * destPath = destinationPath;
    while ([destPath hasPrefix:@"/"]) {
        destPath = [destPath substringFromIndex:1];
    }

    RCTLogTrace(@"Downloading file: %@", destPath);

    NSFileManager* fileManager = [NSFileManager defaultManager];

    NSURL *ubiquityURL = documentsFolder ? [self icloudDocumentsDirectory] : [self icloudDirectory];

    if (ubiquityURL) {

        NSURL* targetFile = [ubiquityURL URLByAppendingPathComponent:destPath];

        NSError *error;
        [fileManager startDownloadingUbiquitousItemAtURL:targetFile error:&error];
        if(error) {
            return reject(@"error", error.description, nil);
        }
        
        NSString *normalFileName = [destPath stringByReplacingOccurrencesOfString:@".icloud" withString:@""];
        normalFileName = [normalFileName substringFromIndex:1];
        
        RCTLogTrace(@">>> normalized file name %@", normalFileName);
        
        NSURL* downloadedFile = [ubiquityURL URLByAppendingPathComponent:normalFileName];

        // Create a dispatch timer
        // wait for the file to be downloaded
        // check the download status every 1 second
        // if the file hasn't been downloaded in 5 seconds, reject the promise
        __block int count = 0;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{
            count++;

            // if the file hasn't been downloaded in 5 seconds, reject the promise
            if (count > 5) {
                RCTLogTrace(@">>> File hasn't been downloaded in 5 seconds %@", downloadedFile);
                dispatch_source_cancel(timer);
                return resolve(downloadedFile.path);
            }

            NSError *error;
            id resourceValue = nil;

            [downloadedFile getPromisedItemResourceValue:&resourceValue
                                                forKey:NSURLUbiquitousItemDownloadingStatusKey
                                                error:&error];
            if (error == nil) {
                NSString *downloadingStatus = (NSString *)resourceValue;
                if ([downloadingStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusCurrent]) {
                    RCTLogTrace(@">>> File has been downloaded");

                    dispatch_source_cancel(timer);
                    return resolve(downloadedFile.path);
                } else if ([downloadingStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusDownloaded]) {
                    RCTLogTrace(@">>> File is downloaded");
                } else if ([downloadingStatus isEqualToString:NSURLUbiquitousItemDownloadingStatusNotDownloaded]) {
                    RCTLogTrace(@">>> File has not been downloaded");
                } else {
                    RCTLogTrace(@">>> unknown %@", downloadingStatus);
                }
            } else {
                RCTLogTrace(@"Error checking download status: %@", error);
            }
            });
        dispatch_resume(timer);
    } else {
        return reject(@"error", [NSString stringWithFormat:@"could not download '%@' from iCloud drive", destPath], nil);
    }
}

- (void) moveToICloudDirectory:(bool) documentsFolder :(NSString *)tempFile :(NSString *)destinationPath
                              :(RCTPromiseResolveBlock)resolver
                              :(RCTPromiseRejectBlock)rejecter {

    if(documentsFolder) {
        NSURL *ubiquityURL = [self icloudDocumentsDirectory];
        [self moveToICloud:ubiquityURL :tempFile :destinationPath :resolver :rejecter];
    } else {
        NSURL *ubiquityURL = [self icloudDirectory];
        [self moveToICloud:ubiquityURL :tempFile :destinationPath :resolver :rejecter];
    }
}

- (void) moveToICloud:(NSURL *)ubiquityURL :(NSString *)tempFile :(NSString *)destinationPath
                     :(RCTPromiseResolveBlock)resolver
                     :(RCTPromiseRejectBlock)rejecter {


    NSString * destPath = destinationPath;
    while ([destPath hasPrefix:@"/"]) {
        destPath = [destPath substringFromIndex:1];
    }

    RCTLogTrace(@"Moving file %@ to %@", tempFile, destPath);

    NSFileManager* fileManager = [NSFileManager defaultManager];

    if (ubiquityURL) {

        NSURL* targetFile = [ubiquityURL URLByAppendingPathComponent:destPath];
        NSURL *dir = [targetFile URLByDeletingLastPathComponent];
        NSString *name = [targetFile lastPathComponent];

        NSURL* uniqueFile = targetFile;

        int count = 1;
        while([fileManager fileExistsAtPath:uniqueFile.path]) {
            NSString *uniqueName = [NSString stringWithFormat:@"%i.%@", count, name];
            uniqueFile = [dir URLByAppendingPathComponent:uniqueName];
            count++;
        }

        RCTLogTrace(@"Target file: %@", uniqueFile.path);

        if (![fileManager fileExistsAtPath:dir.path]) {
            [fileManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSError *error;
        bool result = [fileManager setUbiquitous:YES itemAtURL:[NSURL fileURLWithPath:tempFile] destinationURL:uniqueFile error:&error];
        if(error) {
            return rejecter(@"error", error.description, nil);
        }

        [fileManager removeItemAtPath:tempFile error:&error];

        NSDictionary *dictRes = @{
                    @"filePath":uniqueFile.path,
                    @"setUbiquitousResult":@(result),
                    };
                    
        return resolver(dictRes);
    } else {
        NSError *error;
        [fileManager removeItemAtPath:tempFile error:&error];

        return rejecter(@"error", [NSString stringWithFormat:@"could not copy '%@' to iCloud drive", tempFile], nil);
    }
}

- (NSURL *)icloudDocumentsDirectory {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL *rootDirectory = [[self icloudDirectory] URLByAppendingPathComponent:@"Documents"];

    if (rootDirectory) {
        if (![fileManager fileExistsAtPath:rootDirectory.path isDirectory:nil]) {
            RCTLogTrace(@"Creating documents directory: %@", rootDirectory.path);
            [fileManager createDirectoryAtURL:rootDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }

    return rootDirectory;
}

- (NSURL *)icloudDirectory {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL *rootDirectory = [fileManager URLForUbiquityContainerIdentifier:nil];
    return rootDirectory;
}

- (NSURL *)localPathForResource:(NSString *)resource ofType:(NSString *)type {
    NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *resourcePath = [[documentsDirectory stringByAppendingPathComponent:resource] stringByAppendingPathExtension:type];
    return [NSURL fileURLWithPath:resourcePath];
}

@end
