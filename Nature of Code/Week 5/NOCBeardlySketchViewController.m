//
//  NOCBeardMatrixViewController.m
//  Nature of Code
//
//  Created by William Lindmeier on 3/9/13.
//  Copyright (c) 2013 wdlindmeier. All rights reserved.
//

#import "NOCBeardlySketchViewController.h"
#import "NOCBeard.h"
#import "NOCHair.h"

@interface NOCBeardlySketchViewController ()
{
    NSArray *_faceRects;
    int _numFramesWithoutFace;
    int _numFramesWithFace;
    GLKVector2 _posBeardOffset;
    GLKMatrix4 _matVideoTexture;
    NOCBeard *_beard;
}
@end

@implementation NOCBeardlySketchViewController

static NSString * TextureShaderName = @"Texture";
static NSString * FaceTrackingShaderName = @"ColoredVerts";
static NSString * HairShaderName = @"ColoredVerts";
static NSString * UniformMVProjectionMatrix = @"modelViewProjectionMatrix";
static NSString * UniformTexture = @"texture";

#pragma mark - Orientation

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark - App Loop

- (void)setup
{
    // Setup the shaders
    // Hair shader
    NOCShaderProgram *shader = [[NOCShaderProgram alloc] initWithName:HairShaderName];
    shader.attributes = @{ @"position" : @(GLKVertexAttribPosition),
                           @"color" : @(GLKVertexAttribColor) };
    shader.uniformNames = @[ UniformMVProjectionMatrix ];
    [self addShader:shader named:HairShaderName];
 
    // Video texture
    NOCShaderProgram *texShader = [[NOCShaderProgram alloc] initWithName:TextureShaderName];
    texShader.attributes = @{ @"position" : @(GLKVertexAttribPosition),
                              @"texCoord" : @(GLKVertexAttribTexCoord0) };
    texShader.uniformNames = @[ UniformMVProjectionMatrix, UniformTexture ];
    [self addShader:texShader named:TextureShaderName];
    
    // Create the beard
    _beard = [[NOCBeard alloc] initWithBeardType:NOCBeardTypeStandard
                                        position:GLKVector2Zero];
    
    // Video
    _videoSession = [[NOCVideoSession alloc] initWithFaceDelegate:self];
    _videoSession.shouldDetectFacesInBackground = YES;
    [_videoSession setupWithDevice:[NOCVideoSession frontFacingCamera] inContext:self.context];
    
    _numFramesWithoutFace = 0;
    _numFramesWithFace = 0;
    _posBeardOffset = GLKVector2Zero;

}

- (void)update
{
    GLKVector2 posBeardOffset = _posBeardOffset;
    
    if(_faceRects.count > 0){
        NSValue *rectFaceVal = _faceRects[0];
        CGRect rectFace = [rectFaceVal CGRectValue];

        // Account for video transform
        CGAffineTransform videoTransform = CGAffineTransformMakeRotation(M_PI * 0.5);
        videoTransform = CGAffineTransformScale(videoTransform, -1, 1);
        rectFace = CGRectApplyAffineTransform(rectFace, videoTransform);
        posBeardOffset = GLKVector2Make(CGRectGetMidX(rectFace) * _viewAspect, // this is dialed in
                                        CGRectGetMidY(rectFace) / _viewAspect);
        
        // The beard is 1 unit
        CGSize sizeFace = rectFace.size;
        _beard.scale = sizeFace.width / 1.0f;
        
        if(_numFramesWithFace == 1){
            // The first frame should just drop the beard on top of the face w/ out transition
            _beard.position = posBeardOffset;
        }
    
    }
    
    GLKVector2 posBeardDelta = GLKVector2Subtract(posBeardOffset, _posBeardOffset);
    _posBeardOffset = posBeardOffset;
    
    [_beard updateWithOffset:posBeardDelta];
}

- (void)draw
{
    [self clear];
    
    // Account for camera texture orientation
    float scaleX = [_videoSession isMirrored] ? -1 : 1;
    GLKMatrix4 matTexture = GLKMatrix4MakeScale(scaleX, -1, 1);
    matTexture = GLKMatrix4RotateZ(matTexture, M_PI * 0.5);
    _matVideoTexture = GLKMatrix4Multiply(matTexture, _projectionMatrix2D);
    
    // Draw the video
    [self drawVideoTexture];
    
    // Draw a strokeded line
    [self drawFaceTracking];
    
    // Draw the beard
    [self drawBeard];

}

- (void)drawVideoTexture
{
    // Draw the video background    
    NOCShaderProgram *texShader = [self shaderNamed:TextureShaderName];
    [texShader use];
    [texShader setMatrix:_matVideoTexture forUniform:UniformMVProjectionMatrix];
    [_videoSession bindTexture:0];
    [texShader setInt:0 forUniform:UniformTexture];
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, &_screen3DBillboardVertexData);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, &Square3DTexCoords);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindTexture(GL_TEXTURE_2D, 0);   
}

- (void)drawFaceTracking
{    
    // Draw faces
    NOCShaderProgram *shaderFace = [self shaderNamed:FaceTrackingShaderName];
    [shaderFace use];
    [shaderFace setMatrix:_matVideoTexture forUniform:UniformMVProjectionMatrix];
    
    // Draw a stroked cube
    for(NSValue *rectValue in _faceRects){
        
        CGRect rect = [rectValue CGRectValue];
        
        GLfloat verts[] = {
            rect.origin.x, rect.origin.y + rect.size.height, 0,
            rect.origin.x + rect.size.width, rect.origin.y + rect.size.height, 0,
            rect.origin.x + rect.size.width, rect.origin.y, 0,
            rect.origin.x, rect.origin.y, 0,
        };
        
        const static GLfloat colors[] = {
            1.0,0.0,0.0,1.0,
            1.0,0.0,0.0,1.0,
            1.0,0.0,0.0,1.0,
            1.0,0.0,0.0,1.0,
        };
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, &verts);
        glEnableVertexAttribArray(GLKVertexAttribColor);
        glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, &colors);
        
        glDrawArrays(GL_LINE_LOOP, 0, 4);
        
    }
}

- (void)drawBeard
{
    NOCShaderProgram *shaderHair = [self shaderNamed:HairShaderName];
    [shaderHair use];
    
    const static GLfloat colorParticles[] = {
        1.0,0,0,1.0,
        1.0,0,0,1.0,
        1.0,0,0,1.0,
        1.0,0,0,1.0,
    };
    
    const static GLfloat colorSprings[] = {
        1.0,1,0,1.0,
        1.0,1,0,1.0,
        1.0,1,0,1.0,
        1.0,1,0,1.0,
    };
    
    GLKMatrix4 matBeard = _projectionMatrix2D;

    // TODO: Should this be wrapped up a beard function
    NSArray *hairs = [_beard hairs];
    for(NOCHair *h in hairs){
        
        [h renderParticles:^(GLKMatrix4 particleMatrix, NOCParticle2D *p) {
            
            GLKMatrix4 mvProjMat = GLKMatrix4Multiply(matBeard, particleMatrix);
            [shaderHair setMatrix:mvProjMat forUniform:UniformMVProjectionMatrix];
            
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, &colorParticles);
            
        } andSprings:^(GLKMatrix4 springMatrix, NOCSpring2D *s) {
            
            GLKMatrix4 mvProjMat = GLKMatrix4Multiply(matBeard, springMatrix);
            [shaderHair setMatrix:mvProjMat forUniform:UniformMVProjectionMatrix];
            
            glEnableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, &colorSprings);
            
        }];
        
    }
}

- (void)teardown
{
    [super teardown];
    [_videoSession teardown];
    _videoSession = nil;
}

#pragma mark - Video

- (CGSize)sizeVideoFrameForSession:(NOCVideoSession *)session
{
    return _sizeView;
}

- (void)videoSession:(NOCVideoSession *)videoSession
       detectedFaces:(NSArray *)faceFeatures
             inFrame:(CGRect)previewFrame
         orientation:(UIDeviceOrientation)orientation
               scale:(CGSize)videoScale
{
    
    static const int NumEmptyFramesForClearingFaces = 5;
    
    if(faceFeatures.count == 0){
        
        _numFramesWithFace = 0;
        _numFramesWithoutFace++;
        
        if(_numFramesWithoutFace > NumEmptyFramesForClearingFaces){
            
            // Only reset if the face is gone for a bit.
            // The detector can be a little choppy.
            _faceRects = nil;
        }
        // otherwise, just keep the current rect
        
    }else{
        
        _numFramesWithoutFace = 0;
        _numFramesWithFace++;
        
        NSMutableArray *rects = [NSMutableArray arrayWithCapacity:faceFeatures.count];
        
        for ( CIFaceFeature *ff in faceFeatures ) {
            
            CGRect faceRect = [ff bounds];
            
            // Scale up from image size to view size
            faceRect = CGRectApplyAffineTransform(faceRect, CGAffineTransformMakeScale(videoScale.width, videoScale.height));
            
            // Mirror if source is mirrored
            if ([_videoSession isMirrored])
                faceRect = CGRectApplyAffineTransform(faceRect, CGAffineTransformMakeScale(-1, 1));
            
            // Translate the rect origin
            faceRect = CGRectApplyAffineTransform(faceRect, CGAffineTransformMakeTranslation(previewFrame.origin.x, previewFrame.origin.y));
            
            // Convert to GL space
            GLKVector2 glPos = NOCGLPositionFromCGPointInRect(faceRect.origin, previewFrame);
            float scale = 2.0f / previewFrame.size.width;
            GLKVector2 glSize = GLKVector2Make(faceRect.size.width * scale,
                                               faceRect.size.height * scale);
            
            [rects addObject:[NSValue valueWithCGRect:CGRectMake(glPos.x, glPos.y,
                                                                 glSize.x, glSize.y)]];
            
        }
        
        _faceRects = [NSArray arrayWithArray:rects];
        
    }
    
}

@end
