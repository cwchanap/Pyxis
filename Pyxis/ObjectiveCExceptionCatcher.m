#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>
#import <stdint.h>

int32_t PyxisScheduleAndPlayAudioBuffer(
    AVAudioPlayerNode *playerNode,
    AVAudioPCMBuffer *buffer,
    void (^completion)(void)
) {
    @try {
        [playerNode scheduleBuffer:buffer
                            atTime:nil
                            options:0
             completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack
                  completionHandler:^(__unused AVAudioPlayerNodeCompletionCallbackType callbackType) {
                      completion();
                  }];
        [playerNode play];
        return 1;
    } @catch (NSException *exception) {
        NSLog(@"Gameplay sound dropped after AVFAudio exception: %@", exception);
        @try {
            [playerNode stop];
        } @catch (__unused NSException *stopException) {
        }
        return 0;
    }
}
