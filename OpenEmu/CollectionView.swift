// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Cocoa

class CollectionView: NSCollectionView {
  
  var editing: NSCollectionViewItem?
  
  var isKey: Bool = false
  var selectionColor: NSColor {
    if isKey {
      return NSColor.controlAccentColor
    }
    return NSColor.unemphasizedSelectedContentBackgroundColor
  }
  
  @objc func resignKeyWindow() {
    isKey = false
    updateSelectionHighlights()
  }
  
  @objc func becomeKeyWindow() {
    isKey = true
    updateSelectionHighlights()
  }
  
  override func mouseDown(with event: NSEvent) {
    if editing != nil {
      // if we are already editing something, we need to cancel the operation
      editing?.textField?.window?.makeFirstResponder(nil)
      self.endEditing()
    }
    
    if event.clickCount == 2 {
      let local = convert(event.locationInWindow, from: nil)
      guard
        let index = indexPathForItem(at: local),
        let item = item(at: index)
        else { return }
      
      editing = item
      
      guard let tf = item.textField else { return }
      let p = tf.convert(event.locationInWindow, from: nil)
      if tf.isMousePoint(p, in: tf.bounds) {
        // edit!
        if let editor = tf.window?.fieldEditor(true, for: tf) {
          editor.delegate = self
          tf.isEditable = true
          tf.edit(withFrame: tf.bounds, editor: editor, delegate: self, event: event)
        }
        return
      }
    }
    super.mouseDown(with: event)
  }
  
  override func cancelOperation(_ sender: Any?) {
    endEditing()
  }
  
  func endEditing() {
    guard let editing = editing else { return }
    self.editing = nil
    
    guard let tf = editing.textField else { return }
    tf.isEditable = false
    if let editor = tf.window?.fieldEditor(true, for: tf) {
      editor.delegate = nil
      tf.endEditing(editor)
    }
  }
  
  func updateSelectionHighlights() {
    CATransaction.begin()
    defer { CATransaction.commit() }
    CATransaction.setDisableActions(true)
    
    let color = selectionColor.cgColor
    for index in selectionIndexPaths {
      let v = item(at: index) as? CollectionViewItem
      v?.selectionLayer?.borderColor = color
    }
  }
  
  //  override func deselectItems(at indexPaths: Set<IndexPath>) {
  //    super.deselectItems(at: indexPaths)
  //    let viewController = delegate as! ViewController
  //    viewController.highlightItems(selected: false, atIndexPaths: indexPaths)
  //  }
}

extension CollectionView: NSTextDelegate {
  func textDidEndEditing(_ notification: Notification) {
    NSLog("textDidEndEditing")
  }
}
