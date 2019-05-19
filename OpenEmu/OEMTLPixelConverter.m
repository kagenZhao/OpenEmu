/**
 * Copyright (c) 2019 Stuart Carnie
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

#import "OEMTLPixelConverter.h"

@interface Filter : NSObject

@property (nonatomic, readonly) id<MTLSamplerState> sampler;

- (instancetype)initWithKernel:(id<MTLComputePipelineState>)kernel sampler:(id<MTLSamplerState>)sampler;

- (void)convertTexture:(id<MTLTexture>)src out:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb;
- (void)convertBuffer:(id<MTLBuffer>)src bytesPerRow:(NSUInteger)bytesPerRow out:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb;

+ (instancetype)newFilterWithFunctionName:(NSString *)name
                                   device:(id<MTLDevice>)device
                                  library:(id<MTLLibrary>)library
                                    error:(NSError **)error;

@end

@implementation OEMTLPixelConverter
{
    Filter *_texToTex[OEMTLPixelFormatCount]; // convert to bgra8888
    Filter *_bufToTex[OEMTLPixelFormatCount]; // convert to bgra8888
}

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library
{
    self = [super init];
    
    NSError *err = nil;
    _texToTex[OEMTLPixelFormatBGRA4Unorm] = [Filter newFilterWithFunctionName:@"convert_bgra4444_to_bgra8888"
                                                                       device:device
                                                                      library:library
                                                                        error:&err];
    if (err) {
        NSLog(@"unable to create 'convert_bgra4444_to_bgra8888' conversion filter: %@", err.localizedDescription);
        return nil;
    }
    
    _texToTex[OEMTLPixelFormatB5G6R5Unorm] = [Filter newFilterWithFunctionName:@"convert_rgb565_to_bgra8888"
                                                                        device:device
                                                                       library:library
                                                                         error:&err];
    if (err) {
        NSLog(@"unable to create 'convert_rgb565_to_bgra8888' conversion filter: %@", err.localizedDescription);
        return nil;
    }
    
    _bufToTex[OEMTLPixelFormatBGRA4Unorm] = [Filter newFilterWithFunctionName:@"convert_bgra4444_to_bgra8888_buf"
                                                                       device:device
                                                                      library:library
                                                                        error:&err];
    if (err) {
        NSLog(@"unable to create 'convert_bgra4444_to_bgra8888_buf' conversion filter: %@", err.localizedDescription);
        return nil;
    }
    
    _bufToTex[OEMTLPixelFormatB5G6R5Unorm] = [Filter newFilterWithFunctionName:@"convert_rgb565_to_bgra8888_buf"
                                                                        device:device
                                                                       library:library
                                                                         error:&err];
    if (err) {
        NSLog(@"unable to create 'convert_rgb565_to_bgra8888_buf' conversion filter: %@", err.localizedDescription);
        return nil;
    }
    
    return self;
}

- (void)convertTexture:(id<MTLTexture>)src fromFormat:(OEMTLPixelFormat)fmt to:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    //assert(src.width == dst.width && src.height == dst.height);
    Filter *filter = _texToTex[fmt];
    assert(filter != nil);
    [filter convertTexture:src out:dst commandBuffer:cb];
}

- (void)convertBuffer:(id<MTLBuffer>)src bytesPerRow:(NSUInteger)bytesPerRow fromFormat:(OEMTLPixelFormat)fmt to:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    Filter *filter = _bufToTex[fmt];
    assert(filter != nil);
    [filter convertBuffer:src bytesPerRow:bytesPerRow out:dst commandBuffer:cb];
}

@end

@implementation Filter
{
    id<MTLComputePipelineState> _kernel;
}

+ (instancetype)newFilterWithFunctionName:(NSString *)name device:(id<MTLDevice>)device library:(id<MTLLibrary>)library error:(NSError **)error
{
    id<MTLFunction>             function = [library newFunctionWithName:name];
    id<MTLComputePipelineState> kernel   = [device newComputePipelineStateWithFunction:function error:error];
    if (*error != nil) {
        return nil;
    }
    
    MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new];
    sd.minFilter    = MTLSamplerMinMagFilterNearest;
    sd.magFilter    = MTLSamplerMinMagFilterNearest;
    sd.sAddressMode = MTLSamplerAddressModeClampToEdge;
    sd.tAddressMode = MTLSamplerAddressModeClampToEdge;
    sd.mipFilter    = MTLSamplerMipFilterNotMipmapped;
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:sd];
    
    return [[Filter alloc] initWithKernel:kernel sampler:sampler];
}

- (instancetype)initWithKernel:(id<MTLComputePipelineState>)kernel sampler:(id<MTLSamplerState>)sampler
{
    if (self = [super init]) {
        _kernel  = kernel;
        _sampler = sampler;
    }
    return self;
}

- (void)convertTexture:(id<MTLTexture>)src out:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
    ce.label = @"filter cb";
    [ce pushDebugGroup:@"filter kernel"];
    
    [ce setComputePipelineState:_kernel];
    
    [ce setTexture:src atIndex:0];
    [ce setTexture:dst atIndex:1];
    
    MTLSize size  = MTLSizeMake(16, 16, 1);
    MTLSize count = MTLSizeMake((src.width + size.width + 1) / size.width, (src.height + size.height + 1) / size.height, 1);
    
    [ce dispatchThreadgroups:count threadsPerThreadgroup:size];
    
    [ce popDebugGroup];
    [ce endEncoding];
}

- (void)convertBuffer:(id<MTLBuffer>)src bytesPerRow:(NSUInteger)bytesPerRow out:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
    ce.label = @"filter cb";
    [ce pushDebugGroup:@"filter kernel"];
    
    [ce setComputePipelineState:_kernel];
    
    [ce setBuffer:src offset:0 atIndex:0];
    [ce setBytes:&bytesPerRow length:sizeof(bytesPerRow) atIndex:1];
    [ce setTexture:dst atIndex:0];

//    MTLSize size  = MTLSizeMake(32, 1, 1);
//    MTLSize count = MTLSizeMake((src.length) / 32, 1, 1);
    
    MTLSize size  = MTLSizeMake(16, 16, 1);
    MTLSize count = MTLSizeMake((dst.width + size.width + 1) / size.width, (dst.height + size.height + 1) / size.height, 1);
    
    [ce dispatchThreadgroups:count threadsPerThreadgroup:size];
    
    [ce popDebugGroup];
    [ce endEncoding];
}

@end
