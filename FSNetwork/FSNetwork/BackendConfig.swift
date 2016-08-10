//
//  BackendConfig.swift
//  FSNetwork
//
//  Created by 王正一 on 16/8/10.
//  Copyright © 2016年 FsThatOne. All rights reserved.
//

import Foundation

protocol BackendAPIRequest {
    var endpoint: String { get }
    var method: NetworkService.Method { get }
    var parameters: [String: AnyObject]? { get }
    var headers: [String: String]? { get }
}

public final class BackendConfig {

    private let baseURL: NSURL
    
    init(baseUrl: NSURL) {
        baseURL = baseUrl
    }
    
    public static var shared : BackendConfig!
}

final class SignUpRequest: BackendAPIRequest {
    
    private let firstName: String
    private let lastName: String
    private let email: String
    private let password: String
    
    init(firstName: String, lastName: String, email: String, password: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.password = password
    }
    
    var endpoint: String {
        return "/users"
    }
    
    var method: NetworkService.Method {
        return .POST
    }
    
    var parameters: [String: AnyObject]? {
        return [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "password": password
        ]
    }
    
    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
}

class NetworkService {
    
    private var task: URLSessionDataTask?
    private var successCodes: Range<Int> = 200..<299
    private var failureCodes: Range<Int> = 400..<499
    
    enum Method: String {
        case GET, POST, PUT, DELETE
    }
    
    func request(url: NSURL, method: Method,
                 params: [String: AnyObject]? = nil,
                 headers: [String: String]? = nil,
                 success: ((NSData?) -> Void)? = nil,
                 failure: ((data: NSData?, error: NSError?, responseCode: Int) -> Void)? = nil) {
        
        let mutableRequest = NSMutableURLRequest(url: url as URL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                                 timeoutInterval: 10.0)
        mutableRequest.allHTTPHeaderFields = headers
        mutableRequest.httpMethod = method.rawValue
        if let params = params {
            mutableRequest.httpBody = try! JSONSerialization.data(withJSONObject: params, options: [])
        }
        
        let session = URLSession.shared
        task = session.dataTask(with: mutableRequest as URLRequest, completionHandler: { data, response, error in
            // Decide whether the response is success or failure and call
            // proper callback.
        })
        
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
}

class BackendService {
    
    private let conf: BackendConfig
    private let service: NetworkService!
    
    init(_ conf: BackendConfig) {
        self.conf = conf
        self.service = NetworkService()
    }
    
    func request(request: BackendAPIRequest,
                 success: ((AnyObject?) -> Void)? = nil,
                 failure: ((NSError) -> Void)? = nil) {
        
        let url = conf.baseURL.appendingPathComponent(request.endpoint)
        
        var headers = request.headers
        // Set authentication token if available.
        headers?["X-Api-Auth-Token"] = BackendAuth.shared.token
        
        service.request(url: url!, method: request.method, params: request.parameters, headers: headers, success: { data in
            var json: AnyObject? = nil
            if let data = data {
                json = try? JSONSerialization.jsonObject(with: data as Data, options: [])
            }
            success?(json)
            
            }, failure: { data, error, statusCode in
                // Do stuff you need, and call failure block.
        })
    }
    
    func cancel() {
        service.cancel()
    }
}

public final class BackendAuth {
    
    private let key = "BackendAuthToken"
    private let defaults: UserDefaults
    
    public static var shared: BackendAuth!
    
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    public func setToken(token: String) {
        defaults.setValue(token, forKey: key)
    }
    
    public var token: String? {
        return defaults.value(forKey: key) as? String
    }
    
    public func deleteToken() {
        defaults.removeObject(forKey: key)
    }
}

public class NetworkOperation: Operation {
    
    private var _ready: Bool
    public override var isReady: Bool {
        get { return _ready }
        set { update(change: { self._ready = newValue }, key: "isReady") }
    }
    
    private var _executing: Bool
    public override var isExecuting: Bool {
        get { return _executing }
        set { update(change: { self._executing = newValue }, key: "isExecuting") }
    }
    
    private var _finished: Bool
    public override var isFinished: Bool {
        get { return _finished }
        set { update(change: { self._finished = newValue }, key: "isFinished") }
    }
    
    private var _cancelled: Bool
    public override var isCancelled: Bool {
        get { return _cancelled }
        set { update(change: { self._cancelled = newValue }, key: "isCancelled") }
    }
    
    private func update(change: (Void) -> Void, key: String) {
        willChangeValue(forKey: key)
        change()
        didChangeValue(forKey: key)
    }
    
    override init() {
        _ready = true
        _executing = false
        _finished = false
        _cancelled = false
        super.init()
        name = "Network Operation"
    }
    
    public override var isAsynchronous: Bool {
        return true
    }
    
    public override func start() {
        if self.isExecuting == false {
            self.isReady = false
            self.isExecuting = true
            self.isFinished = false
            self.isCancelled = false
        }
    }
    
    /// Used only by subclasses. Externally you should use `cancel`.
    func finish() {
        self.isExecuting = false
        self.isFinished = true
    }
    
    public override func cancel() {
        self.isExecuting = false
        self.isCancelled = true
    }
}

public class ServiceOperation: NetworkOperation {
    
    let service: BackendService
    
    public override init() {
        self.service = BackendService(BackendConfig.shared)
        super.init()
    }
    
    public override func cancel() {
        service.cancel()
        super.cancel()
    }
}
//
//public class SignInOperation: ServiceOperation {
//    
//    private let request: SignInRequest
//    
//    public var success: (SignInItem -> Void)?
//    public var failure: ((NSError) -> Void)?
//    
//    public init(email: String, password: String) {
//        request = SignInRequest(email: email, password: password)
//        super.init()
//    }
//    
//    public override func start() {
//        super.start()
//        service.request(request, success: handleSuccess, failure: handleFailure)
//    }
//    
//    private func handleSuccess(response: AnyObject?) {
//        do {
//            let item = try SignInResponseMapper.process(response)
//            self.success?(item)
//            self.finish()
//        } catch {
//            handleFailure(NSError.cannotParseResponse())
//        }
//    }
//    
//    private func handleFailure(error: NSError) {
//        self.failure?(error)
//        self.finish()
//    }
//}
//
//public class NetworkQueue {
//    
//    public static var shared: NetworkQueue!
//    
//    let queue = NSOperationQueue()
//    
//    public init() {}
//    
//    public func addOperation(op: NSOperation) {
//        queue.addOperation(op)
//    }
//}
