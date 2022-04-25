//
//  NotificationSubscriber.swift
//
//
//  Created by Michael Hamer on 12/11/20.
//

import Foundation

struct NotificationSubscriber {
    let method: String
    var completion: ((Data) throws -> Void)?
}
