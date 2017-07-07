//
//  ReactiveSwiftPimps.swift
//  ReactiveFuturesKit
//
//  Created by clement on 2017-06-15.
//  Copyright © 2017 OMsignal. All rights reserved.
//

import Foundation
import ReactiveSwift

public extension SignalProducer {
    
    public func completionFuture() -> Future<Void, Error> {
        return Future<Void, Error>(signalProducer: self.then(SignalProducer<Void, Error>(value: ())))
    }
    
    public func toFuture() -> Future<Value, Error> {
        return Future(signalProducer: self)
    }
    
}


public extension Signal {
    
    public func toFuture() -> Future<Value, Error> {
        return SignalProducer(self).toFuture()
    }
    
}
