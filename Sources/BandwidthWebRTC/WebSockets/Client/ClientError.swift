//
//  ClientError.swift
//
//
//  Created by Michael Hamer on 12/11/20.
//

import Foundation

enum ClientError: Error {
    case invalid(data: Data, encoding: String.Encoding)
    case duplicateSubscription
    case custom(String)
}
