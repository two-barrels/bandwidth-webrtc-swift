//
//  Response.swift
//
//
//  Created by Michael Hamer on 12/8/20.
//

import Foundation

struct Response<T: Decodable>: Decodable {
    let jsonRPC: String
    let id: String
    let result: T?
    
    enum CodingKeys: String, CodingKey {
        case jsonRPC = "jsonrpc"
        case id
        case result
    }
}
