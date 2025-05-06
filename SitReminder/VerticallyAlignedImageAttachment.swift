//
//  VerticallyAlignedImageAttachment.swift
//  SitReminder
//
//  Created by Hu Gang on 2025/5/6.
//


import AppKit

class VerticallyAlignedImageAttachment: NSTextAttachment {
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
        // 图标高度手动调整以向下对齐
        let iconSize: CGFloat = 14
        return CGRect(x: 0, y: -3, width: iconSize, height: iconSize)
    }
}