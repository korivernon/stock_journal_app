//
//  Entry.swift
//  Dreamio
//
//  Created by Bold Lion on 24.02.19.
//  Copyright © 2019 Bold Lion. All rights reserved.
//

import Foundation

struct Entry {
    
    var id: String?
    var title: String?
    var content: String?
    var creationDate: Int?
    var notebookId: String?
    var photoUrls : [String]?
}


extension Entry {
    
    static func transformEntry(dict: [String:Any], key: String) -> Entry {
        var entry = Entry()
        entry.id = key
        entry.title = dict["title"] as? String
        entry.content = dict["content"] as? String
        entry.creationDate = dict["created"] as? Int
        entry.notebookId = dict["notebookId"] as? String
        entry.photoUrls = dict["photoUrls"] as? [String]
        return entry
    }
    
}
