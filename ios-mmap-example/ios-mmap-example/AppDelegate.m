#import "AppDelegate.h"
#import <sys/mman.h>


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    UIViewController *vc = [[UIViewController alloc] init];
    
    [self.window setRootViewController:vc];
    
    // Change the parameters to tweak the test
    [self memoryMapTestWithSizeInMb:1 numberOfFiles:1 permission:PROT_WRITE];
    
    
    // Mapping 1 file Max succes size:
    
    // iPad Air 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:800 numberOfFiles:1 permission:PROT_READ]; 800 mb total
    // [self memoryMapTestWithSizeInMb:800 numberOfFiles:1 permission:PROT_WRITE]; 800 mb total
    
    // iPhone 5s 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:720 numberOfFiles:1 permission:PROT_READ]; 720 mb total
    
    // iPhone 4s 2011. 512 mb memory
    // [self memoryMapTestWithSizeInMb:300 numberOfFiles:1 permission:PROT_READ]; 300 mb total
    // [self memoryMapTestWithSizeInMb:300 numberOfFiles:1 permission:PROT_WRITE]; 300 mb total
    
    // Simulator
    // [self memoryMapTestWithSizeInMb:500000000 numberOfFiles:1 permission:PROT_READ]; NO LIMIT
    
    
    
    // Mapping 10 files Max succes size:
    
    // iPad Air 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:150 numberOfFiles:10 permission:PROT_READ]; 1500 mb total
    // [self memoryMapTestWithSizeInMb:150 numberOfFiles:10 permission:PROT_WRITE]; 1500 mb total
    
    
    // iPhone 5s 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:150 numberOfFiles:10 permission:PROT_READ]; 1500 mb total
    
    // iPhone 4s 2011. 512 mb memory
    // ONLY 1 FILE ALLOWED TO BE MAPPED
    
    
    // Simulator
    // [self memoryMapTestWithSizeInMb:500000000 numberOfFiles:10 permission:PROT_READ]; NO LIMIT
    
    
    
    // Mapping 100 files Max succes size:
    
    // iPad Air 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:19 numberOfFiles:100 permission:PROT_READ]; 1900 mb total
    // [self memoryMapTestWithSizeInMb:19 numberOfFiles:100 permission:PROT_WRITE]; 1900 mb total
    
    
    // iPhone 5s 2013. 1 gb memory
    // [self memoryMapTestWithSizeInMb:19 numberOfFiles:100 permission:PROT_READ]; 1900 mb total
    
    // iPhone 4s 2011. 512 mb memory
    // ONLY 1 FILE ALLOWED TO BE MAPPED
    
    // Simulator
    // [self memoryMapTestWithSizeInMb:500000000 numberOfFiles:100 permission:PROT_READ]; NO LIMIT
    
    
    return YES;
}


- (void)memoryMapTestWithSizeInMb:(int)mb numberOfFiles:(int)numberOfFiles permission:(int)permission;
{
    size_t sizeInBytes = mb*1024*1024;
    
//    for (int i=0;i<numberOfFiles;i++) {
//        [[NSFileManager defaultManager] createFileAtPath:[AppDelegate writeablePathForFile:[NSString stringWithFormat:@"file%i.realm", i]]
//                                                contents:[[NSMutableData alloc] initWithLength:sizeInBytes] // Setting size to sizeInBytes does not make any difference on the results
//                                              attributes:nil ];
//    }
    
    const char *paths[numberOfFiles];
    int files[numberOfFiles];
    
    for (int i=0;i<numberOfFiles;i++) {
        paths[i] = [[AppDelegate writeablePathForFile:[NSString stringWithFormat:@"file%i.realm", i]] UTF8String];
        files[i] = open(paths[i], O_RDWR);
//        files[i] = fopen(paths[i], "w+");
        ftruncate(files[i], sizeInBytes);
    }
    
    void *baseAdresses[numberOfFiles];
    
    int totalmbAlreadyMapped = 0;
    
    for (int i=0;i<numberOfFiles;i++) {
        
        baseAdresses[i] = mmap(NULL, sizeInBytes*2, permission, MAP_SHARED, files[i], 0);
        
        if (baseAdresses[i] == MAP_FAILED)
        {
            perror("mmap");
            NSLog(@"Failing %i for size: %zu (%d mb) with permission: %@. Already mapped: %i", i, sizeInBytes, mb, [AppDelegate permissionToString:permission], totalmbAlreadyMapped);
            close(files[i]);
        } else {
            NSLog(@"Success %i for size: %zu (%d mb) with permission: %@", i, sizeInBytes, mb, [AppDelegate permissionToString:permission]);
            totalmbAlreadyMapped = totalmbAlreadyMapped + mb;
        }
        
        int k = 0;
        char ch = 'a';
        for(; k < sizeInBytes; ++k)
        {
            Byte *pAddr = (Byte *)(baseAdresses[i]);
            pAddr[k] = ch;
            ++ch;
            if(ch > 'z') ch = 'a';
        }
        
        //try to extend the mapped file for on page.
        int err = 0;
#define Method 4
#if Method == 1
//        FILE *tmpF = fopen(paths[i], "rb+");
//        fseek(tmpF, 0, SEEK_END);
//        char *pTmp = "\n";
//        fwrite(pTmp, 1, 1, tmpF);
//        fclose(tmpF);
#elif Method == 2
        err = truncate(paths[i], sizeInBytes + 1);
#elif Method == 3
        FILE *tmpF = fopen(paths[i], "rb+");
        err = ftruncate(fileno(tmpF), sizeInBytes + 1);
        fclose(tmpF);
#elif Method == 4
        err = ftruncate(files[i], sizeInBytes + 4097);
#endif
        if(0 == err)
        {
            for(int j = 0; j < sizeInBytes; ++j)
            {
                Byte *pAddr = (Byte *)(baseAdresses[i]);
                pAddr[k++] = ch;
                ++ch;
                if(ch > 'z') ch = 'a';
            }
        }
        else
        {
            NSLog(@"failed to extend the mapped file: %d", err);
        }

    }
    
    for (int i=0;i<numberOfFiles;i++) {
        munmap(baseAdresses[i], sizeInBytes);
    }
}


+ (NSString *)permissionToString:(int)permission
{
    if (permission == 1) {
        return @"PROT_READ";
    } else if (permission == 2) {
        return @"PROT_WRITE";
    } else {
        return @"other";
    }
}


+ (NSString *)writeablePathForFile:(NSString*)fileName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

@end
