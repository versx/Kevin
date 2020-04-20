//
//  SystemInfo.m
//  Jarvis++
//
//  Created by versx on 4/6/20.
//

#import "SystemInfo.h"

@implementation SystemInfo

+(SystemInfo *)sharedInstance
{
    static SystemInfo *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SystemInfo alloc] init];
    });
    return sharedInstance;
}

@synthesize cpuUsage;
@synthesize processorCount;
@synthesize thermalState;
@synthesize systemUptime;

@synthesize totalMemory;
@synthesize freeMemory;
@synthesize usedMemory;

@synthesize totalSpace;
@synthesize freeSpace;
@synthesize usedSpace;


-(id)init
{
    if ((self = [super init])) {
        //NSDate *start = [NSDate date];
        [self setCpuUsage:@0.0];
        [self setTotalMemory:@0];
        [self setFreeMemory:@0];
        [self setUsedMemory:@0];
        [self setTotalSpace:@0];
        [self setFreeSpace:@0];
        [self setUsedSpace:@0];
            
        @try {
            //load info
            [self setCpuUsage:[self getCpuUsage]];
            [self setProcessorCount:[[NSProcessInfo processInfo] processorCount]];
            [self setSystemUptime:[[NSProcessInfo processInfo] systemUptime]];
            [self setThermalState:[[NSProcessInfo processInfo] thermalState]];
            [self getMemory];
            [self getDiskSpace];
        }
        @catch (NSException *exception) {
            syslog(@"[ERROR] %@", exception);
        }
        //syslog(@"[DEBUG] System information fetch took %f seconds", [[NSDate date] timeIntervalSinceDate:start]);
    }
    return self;
}

/*
-(void)toggleWiFi
{
    Class _SBWifiManager = objc_getClass("SBWiFiManager"); // Steal a class from SpringBoard
    [[_SBWifiManager sharedInstance] setWiFiEnabled:NO]; // disable
    sleep(5);
    [[_SBWifiManager sharedInstance] setWiFiEnabled:YES]; // enable
}
*/

-(NSNumber *)getCpuUsage
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;

    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;

    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;

    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads

    basic_info = (task_basic_info_t)tinfo;

    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;

    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    for (int j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }

        basic_info_th = (thread_basic_info_t)thinfo;
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }

    } // for each thread

    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    return @(tot_cpu);
}

-(void)getMemory
{
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;

    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);

    vm_statistics_data_t vm_stat;

    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        syslog(@"[ERROR] Failed to fetch vm statistics");
    }

    /* Stats in bytes */
    unsigned long mem_used = (vm_stat.active_count +
                              vm_stat.inactive_count +
                              vm_stat.wire_count) * pagesize;
    unsigned long mem_free = vm_stat.free_count * pagesize;
    unsigned long mem_total = mem_used + mem_free;
    [self setTotalMemory:@(mem_total)];
    [self setFreeMemory:@(mem_free)];
    [self setUsedMemory:@(mem_total - mem_free)];
    //NSLog(@"[DEBUG] used: %lu free: %lu total: %lu", mem_used, mem_free, mem_total);
}

-(void)getDiskSpace
{
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject]
                                                                                       error:&error];
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        [self setTotalSpace:@(totalSpace)];
        [self setFreeSpace:@(totalFreeSpace)];
        [self setUsedSpace:@(totalSpace - totalFreeSpace)];
        //NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available and %llu MiB Used memory.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll), ((totalSpace - totalFreeSpace)/1024ll/1024ll));
    } else {
        syslog(@"[ERROR] Error obtaining system storage info: %@", error);
    }
}

+(NSString *)formatBytes:(long)bytes
{
    return [NSByteCountFormatter stringFromByteCount:bytes
                                          countStyle:NSByteCountFormatterCountStyleFile];
}

+(NSString *)formatThermalState:(NSProcessInfoThermalState)state
{
    if (state == NSProcessInfoThermalStateFair) {
        // Thermals are fair. Consider taking proactive measures to prevent higher thermals.
        return @"Fair";
    } else if (state == NSProcessInfoThermalStateSerious) {
        // Thermals are highly elevated. Help the system by taking corrective action.
        return @"Serious";
    } else if (state == NSProcessInfoThermalStateCritical) {
        // Thermals are seriously elevated. Help the system by taking immediate corrective action.
        return @"Critical";
    } else {
        // Thermals are okay. Go about your business.
        return @"Normal";
    }
}

+(NSString *)formatTimeInterval:(NSTimeInterval)timeInterval
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    // TODO: check if greater than 1hr, 1day
    //if ([time intValue] > 24 * 3600) {
        formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    //} else {
    //    formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    //}
    return [formatter stringFromTimeInterval:timeInterval];
}

@end
