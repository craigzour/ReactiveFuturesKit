//
//  ReactiveSwiftPimpsTests.swift
//  ReactiveFuturesKit
//
//  Created by clement on 2017-06-15.
//  Copyright © 2017 OMsignal. All rights reserved.
//

import XCTest
import Nimble
import ReactiveSwift
import Result

@testable import ReactiveFuturesKit

enum FakeError: Error {
    case someError
    case anotherError
}

class ReactiveSwiftPimpsTests: XCTestCase {
    
    func testCompletionFutureShouldReturnValueIfSignalComplete() {
        let signalProducer = SignalProducer<Void, NoError>.empty
        
        _ = try! signalProducer.completionFuture().get(timeout: 2)
    }
    
    func testCompletionFutureShouldReturnValueIfSignalCompleteWithError() {
        let signalProducer = SignalProducer<Void, FakeError>(error: .someError)
        
        expect { try signalProducer.completionFuture().get() }.to(throwError(FakeError.someError))
    }
    
    func testCompletionFutureShouldNotReturnValueIfSignalNeverComplete() {
        let signalProducer = SignalProducer<Void, NoError>.never
        
        expect { try signalProducer.completionFuture().get(timeout: 0.1) }.to(throwError(FutureFailure<NoError>.interrupted))
    }
    
    func testToFutureShouldForwardFirstValueSentByTheSignalProducer() {
        let signalProducer = SignalProducer<Int, NoError>(value: 1)
        
        let future = signalProducer.toFuture()
        
        let result = try! future.get()
        
        expect(result) == 1
    }
    
    func testToFutureShouldForwardErrorSentByTheSignalProducer() {
        let signalProducer = SignalProducer<Int, FakeError>(error: .anotherError)
        
        let future = signalProducer.toFuture()
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with anotherError")
        case .failure(let error):
            switch error {
            case .anotherError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with anotherError")
            }
        }
    }
    
}
