//
//  NOCColorHelpers.h
//  Nature of Code
//
//  Created by William Lindmeier on 3/31/13.
//  Copyright (c) 2013 wdlindmeier. All rights reserved.
//

#ifndef Nature_of_Code_NOCColorHelpers_h
#define Nature_of_Code_NOCColorHelpers_h

typedef struct {
    float r;
    float g;
    float b;
} RGBcolor;

typedef struct {
    float hue;
    float sat;
    float val;
} HSVcolor;

static inline HSVcolor HSVfromRGB(RGBcolor rgb)
{
    HSVcolor hsv;
    
    CGFloat rgb_min, rgb_max;
    rgb_min = MIN(rgb.r, MIN(rgb.g, rgb.b));
    rgb_max = MAX(rgb.r, MAX(rgb.g, rgb.b));
    
    if (rgb_max == rgb_min) {
        hsv.hue = 0;
    } else if (rgb_max == rgb.r) {
        hsv.hue = 60.0f * ((rgb.g - rgb.b) / (rgb_max - rgb_min));
        hsv.hue = fmodf(hsv.hue, 360.0f);
    } else if (rgb_max == rgb.g) {
        hsv.hue = 60.0f * ((rgb.b - rgb.r) / (rgb_max - rgb_min)) + 120.0f;
    } else if (rgb_max == rgb.b) {
        hsv.hue = 60.0f * ((rgb.r - rgb.g) / (rgb_max - rgb_min)) + 240.0f;
    }
    hsv.val = rgb_max;
    if (rgb_max == 0) {
        hsv.sat = 0;
    } else {
        hsv.sat = 1.0 - (rgb_min / rgb_max);
    }
    
    return hsv;
}

#endif
