//
//  Client.swift
//
//
//  Created by Michael Hamer on 12/4/20.
//

import Foundation

public class Client: NSObject {
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?

    private var connectCompletion: (() -> Void)?
    private var disconnectCompletion: (() -> Void)?
    
    private var receivableSubscribers = [ReceivableSubscriber]()
    private var notificationSubscribers = [NotificationSubscriber]()
    
    public func connect(url: URL, queue: OperationQueue? = nil, completion: @escaping () -> Void) {
        connectCompletion = completion
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receive()
        ping()
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        
        disconnectCompletion = completion
    }
    
    public func notify<T: Codable>(method: String, parameters: T, completion: @escaping (Result<(), Error>) -> Void) {
        let request = Request(id: nil, method: method, parameters: parameters)
        
        do {
            let data = try JSONEncoder().encode(request)
            
            guard let string = String(data: data, encoding: .utf8) else {
                throw ClientError.invalid(data: data, encoding: .utf8)
            }
            
            let message = URLSessionWebSocketTask.Message.string(string)
            webSocketTask?.send(message) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    public func call<T: Codable, U: Decodable>(method: String, parameters: T, type: U.Type, timeout: TimeInterval = 5, completion: @escaping (Result<U?, Error>) -> Void) {
        let request = Request(method: method, parameters: parameters)
        
        guard let id = request.id else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(request)
            
            guard let string = String(data: data, encoding: .utf8) else {
                completion(.failure(ClientError.invalid(data: data, encoding: .utf8)))
                return
            }

            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { timer in
                // Remove the receivable if the request hasn't received a response within the timeout.
                if let index = self.receivableSubscribers.firstIndex(where: { $0.id == id }) {
                    self.receivableSubscribers.remove(at: index)
                }
            }
            
            let completion = { (data: Data) in
                // Attempt to decode the data to a matching type.
                guard let response = try? JSONDecoder().decode(Response<U>.self, from: data) else {
                    return
                }
                
                // Continue only if the request and response ids match.
                guard id == response.id else {
                    return
                }
                
                if let index = self.receivableSubscribers.firstIndex(where: { $0.id == id }) {
                    // Invalidate the current timeout timer which is running.
                    self.receivableSubscribers[index].timer.invalidate()
                        
                    // Remove the receivable once the request has been paired with a matching response.
                    self.receivableSubscribers.remove(at: index)
                        
                    completion(.success(response.result))
                }
            }
            
            receivableSubscribers.append(ReceivableSubscriber(id: id, timer: timer, completion: completion))
            
            let message = URLSessionWebSocketTask.Message.string(string)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    public func subscribe<T: Codable>(to method: String, type: T.Type) throws {
        // Only allow subscribing to a method once.
        guard notificationSubscribers.first(where: { $0.method == method }) == nil else {
            throw ClientError.duplicateSubscription
        }
        
        notificationSubscribers.append(NotificationSubscriber(method: method, completion: nil))
    }
    
    public func on<T: Codable>(method: String, type: T.Type, completion: @escaping (T) -> Void) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers[index].completion = { data in
                // Attempt to decode the data to a matching type.
                let notification = try JSONDecoder().decode(Request<T>.self, from: data)

                // There's a chance that two methods point to one type.
                guard self.notificationSubscribers[index].method == notification.method else {
                    return
                }
                
                completion(notification.parameters)
            }
        }
    }
    
    public func unsubscribe(from method: String) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers.remove(at: index)
        }
    }

    private func receive() {
        webSocketTask?.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let string):
                    guard let data = string.data(using: .utf8) else {
                        return
                    }
                    
                    self.receivableSubscribers.forEach {
                        $0.completion(data)
                    }
                    
                    self.notificationSubscribers.forEach {
                        do {
                            try $0.completion?(data)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                default:
                    break
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
            
            self.receive()
        }
    }
    
    private func ping() {
        webSocketTask?.sendPing { error in
            if let error = error {
                print(error.localizedDescription)
            } else {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
                    self.ping()
                }
            }
        }
    }
}

extension Client: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        connectCompletion?()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        disconnectCompletion?()
    }
}

