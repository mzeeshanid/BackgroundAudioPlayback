//
//  MetadataEntry.swift
//  AudioPlayerTest
//
//  Created by Zeeshan on 01/09/2026.
//

import Foundation

struct MetadataEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}
