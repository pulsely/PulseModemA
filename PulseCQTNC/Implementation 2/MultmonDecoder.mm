//
//  MultmonDecoder.m
//  PulseCQAPRS
//
//  Created by Kenneth Lo on 4/11/18.
//  Copyright © 2018 Kenneth Lo. All rights reserved.
//

#import "MultmonDecoder.h"

#include "multimon.h"


static const char *allowed_types[] = {
    "raw", "aiff", "au", "hcom", "sf", "voc", "cdr", "dat",
    "smp", "wav", "maud", "vwe", "mp3", "mp4", "ogg", "flac", NULL
};

/* ---------------------------------------------------------------------- */

static const struct demod_param *dem[] = { ALL_DEMOD };

#define NUMDEMOD (sizeof(dem)/sizeof(dem[0]))

static struct demod_state dem_st[NUMDEMOD];
static unsigned int dem_mask[(NUMDEMOD+31)/32];

#define MASK_SET(n) dem_mask[(n)>>5] |= 1<<((n)&0x1f)
#define MASK_RESET(n) dem_mask[(n)>>5] &= ~(1<<((n)&0x1f))
#define MASK_ISSET(n) (dem_mask[(n)>>5] & 1<<((n)&0x1f))

void process_buffer_(float *float_buf, short *short_buf, unsigned int len)
{
    for (int i = 0; (unsigned int) i <  NUMDEMOD; i++)
        if (MASK_ISSET(i) && dem[i]->demod)
        {
            buffer_t buffer = {short_buf, float_buf};
            dem[i]->demod(dem_st+i, buffer, len);
        }
}


@implementation MultmonDecoder

@end
