//
//  Document.swift
//  OneCut
//
//  Created by zpc on 2018/7/3.
//  Copyright © 2018年 Apple Inc. All rights reserved.
//

import UIKit
import AVFoundation

class Document: UIDocument {
    
    var comp: AVMutableComposition? = nil
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        return Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
        comp = AVMutableComposition(url: URL(fileURLWithPath: "<#T##String#>"))
    }
}

