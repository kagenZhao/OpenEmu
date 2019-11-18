/*
 * ImageFile.swift
 * SlidesPro
 *
 * Created by Gabriel Miro on 30/3/16.
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

class ImageFile {
  
  private(set) var thumbnail: NSImage?
  private(set) var fileName: String
  private(set) var url: URL
  
  init (url: URL) {
    self.url = url
    var fn = url
    while fn.pathExtension.count > 0 {
      fn = fn.deletingPathExtension()
    }
    self.fileName = fn.lastPathComponent
    let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
    if let imageSource = imageSource {
      guard CGImageSourceGetType(imageSource) != nil else { return }
      thumbnail = getThumbnailImage(imageSource: imageSource)
    }
  }
  
  private func getThumbnailImage(imageSource: CGImageSource) -> NSImage? {
    let thumbnailOptions = [
      String(kCGImageSourceCreateThumbnailFromImageIfAbsent): true,
      String(kCGImageSourceThumbnailMaxPixelSize): 320
      ] as [String : Any]
    guard let thumbnailRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else { return nil}
    return NSImage(cgImage: thumbnailRef, size: NSSize.zero)
  }
  
}
