//
//  Request.swift
//
//
//  Created by Michael Hamer on 12/8/20.
//

import Foundation

struct Request<T: Codable>: Codable {
    let jsonRPC: String
    let id: String?
    let method: String
    let parameters: T
    
    init(id: String? = UUID().uuidString, method: String, parameters: T) {
        self.jsonRPC = "2.0"
        self.id = id
        self.method = method
        self.parameters = parameters
    }
    
    enum CodingKeys: String, CodingKey {
        case jsonRPC = "jsonrpc"
        case id
        case method
        case parameters = "params"
    }
}
