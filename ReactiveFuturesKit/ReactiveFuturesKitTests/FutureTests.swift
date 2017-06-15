//
//  FutureTests.swift
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

enum SampleError: Error {
    case someError
    case anotherError
    case timeout
}

enum AnotherKindOfError: Error {
    case thisIsAnotherKindOfError
    case andAnotherValue
}

class FutureTests: XCTestCase {
    
    func testInit_shouldCreateSuccessfulFutureWithValue() {
        let future = Future<Int, NoError>(value: 5)
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testInit_shouldCreateSuccessfulFutureWithPromiseHandlerSuccess() {
        let future = Future<Int, NoError> { promise in
            promise.success(5)
        }
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testInit_shouldCreateFailedFutureWithError() {
        let future = Future<Int, SampleError>(error: .someError)
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with someError")
        case .failure(let error):
            switch error {
            case .someError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with someError")
            }
        }
    }
    
    func testInit_shouldCreateFailedFutureWithPromiseHandlerFailure() {
        let future = Future<Int, SampleError> { promise in
            promise.failure(.someError)
        }
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with someError")
        case .failure(let error):
            switch error {
            case .someError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with someError")
            }
        }
    }
    
    func testInit_shouldCreateFailedFutureWithPromiseHandlerInterrupted() {
        let future = Future<Int, SampleError> { promise in
            promise.interrupted()
        }
        
        waitUntil(timeout: 2) { done in
            future.onComplete { result in
                switch result {
                case .success(_):
                    XCTFail("Future should be interrupted")
                case .failure(let error):
                    switch error {
                    case .interrupted:
                        // GOOD
                        break
                    default:
                        XCTFail("Future should be interrupted")
                    }
                }
            }
            
            done()
        }
    }
    
    func testInit_shouldOnlyTriggerSideEffectOnce() {
        var numberOfSideEffects = 0
        
        let future = Future<Void, NoError>(value: ()).map { _ in
            numberOfSideEffects += 1
        }
        
        _ = try! future.get()
        _ = try! future.get()
        
        expect(numberOfSideEffects) == 1
    }
    
    func testFutureShouldOnlyTakeIntoAccountTheFirstValueSentByTheSignalProducer() {
        let signalProducer = SignalProducer<Int, NoError>([2, 3, 4])
        
        let future = Future<Int, NoError>(signalProducer: signalProducer)
        
        let result = try! future.get()
        
        expect(result) == 2
    }
    
    func testMap_shouldMapValue() {
        let future = Future<Int, NoError>(value: 5).map { value in
            return 2 * value
        }
        
        let result = try! future.get()
        
        expect(result) == 10
    }
    
    func testMap_shouldPropagateError() {
        let future = Future<Int, SampleError>(error: .someError).map { value in
            return 2 * value
        }
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with someError")
        case .failure(let error):
            switch error {
            case .someError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with someError")
            }
        }
    }
    
    func testMapError_shouldPropagateValue() {
        let future = Future<Int, SampleError>(value: 5).mapError { _ in
            return SampleError.anotherError
        }
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testMapError_shouldTransformError() {
        let future = Future<Int, SampleError>(error: .someError).mapError { _ in
            return SampleError.anotherError
        }
        
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
    
    func testFlatMap_shouldTransformValueType() {
        let future = Future<Int, NoError>(value: 5).flatMap { value in
            return Future<String, NoError>(value: String(2 * value))
        }
        
        let result = try! future.get()
        
        expect(result) == "10"
    }
    
    func testFlatMap_shouldPropagateError() {
        let future = Future<Int, SampleError>(error: .someError).flatMap { value in
            return Future<String, SampleError>(value: String(2 * value))
        }
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with someError")
        case .failure(let error):
            switch error {
            case .someError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with someError")
            }
        }
    }
    
    func testFlatMapError_shouldPropagateValue() {
        let future = Future<Int, SampleError>(value: 5).flatMapError { _ in
            return Future<Int, AnotherKindOfError>(error: AnotherKindOfError.thisIsAnotherKindOfError)
        }
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testFlatMapError_shouldTransformErrorTypeAndValue() {
        let future = Future<Int, SampleError>(error: .someError).flatMapError { _ in
            return Future<Int, AnotherKindOfError>(error: AnotherKindOfError.thisIsAnotherKindOfError)
        }
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with thisIsAnotherKindOfError")
        case .failure(let error):
            switch error {
            case .thisIsAnotherKindOfError:
                // GOOD
                break
            default:
                XCTFail("Future should fail with thisIsAnotherKindOfError")
            }
        }
    }
    
    func testNever_shouldNeverReturn() {
        let future = Future<Int, NoError>.never()
        
        waitUntil(timeout: 4) { done in
            future.onComplete { _ in
                XCTFail("Future should never return")
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                done()
            }
        }
    }
    
    func testFlatmap_shouldPromoteErrorIfNeeded() {
        let initialFuture = Future<Int, NoError>(value: 5)
        
        let future = initialFuture.flatMap { _ in
            return Future<Int, SampleError>(value: 10)
        }
        
        let result = try! future.get()
        
        expect(result) == 10
    }
    
    func testCombineWith_shouldCombineWithAnotherFuture() {
        let future1 = Future<Int, NoError>(value: 5)
        
        let future2 = Future<String, NoError>(value: "5")
        
        let combinedFuture = future1.combineWith(future2)
        
        let result = try! combinedFuture.get()
        
        expect(result.0) == 5
        expect(result.1) == "5"
    }
    
    func testDelay_shouldEventuallyEmitTheValue() {
        let future = Future<Int, NoError>(value: 5).delay(1)
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testDelay_shouldTimeoutbeforeEmittingValue() {
        let future = Future<Int, SampleError>(value: 5)
            .delay(2)
            .timeout(after: 1, raising: .timeout)
        
        let result = try! future.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with timeout")
        case .failure(let error):
            switch error {
            case .timeout:
                // GOOD
                break
            default:
                XCTFail("Future should fail with timeout")
            }
        }
    }
    
    func testPromoteErrors_shouldPropagateValue() {
        let future = Future<Int, NoError>(value: 5).promoteErrors(SampleError.self)
        
        let result = try! future.get()
        
        expect(result) == 5
    }
    
    func testDelay_shouldWaitandGetEmitTheValue() {
        let future = Future<Int, NoError>(value: 5).delay(0.2)
        
        let result = try! future.get(timeout: 0.5)
        
        expect(result) == 5
    }
    
    func testDelay_shouldWaitandFailed() {
        let future = Future<Int, NoError>(value: 5).delay(0.3)
        
        expect { try future.get(timeout: 0.1) }.to(throwError(FutureFailure<NoError>.interrupted))
    }
    
    func testDelay_shouldWaitASignal() {
        let delay_signal = SignalProducer<Int, NoError>(value: 5).delay(0.1, on: QueueScheduler())
        
        let future = Future(signalProducer: delay_signal)
        
        let result = try! future.get(timeout: 0.5)
        
        expect(result) == 5
    }
    
    func testMaterialize_shouldReturnASuccessForASuccessfulFuture() {
        let expectedResult = Result<Int, SampleError>(value: 5)
        
        let future = Future<Int, SampleError>(value: 5)
        
        let result = try! future.materialize().get()
        
        expect(result).to(equal(expectedResult))
    }
    
    func testMaterialize_shouldReturnAFailureForAFailedFuture() {
        let expectedResult = Result<Int, SampleError>(error: .someError)
        
        let future = Future<Int, SampleError>(error: .someError)
        
        let result = try! future.materialize().get()
        
        expect(result).to(equal(expectedResult))
    }
    
    func testMaterialize_shouldDematerializeToSameSuccessCase() {
        let future = Future<Int, SampleError>(value: 5)
        
        let derivedFuture = future.materialize().dematerialize()
        
        let result = try! derivedFuture.get()
        
        expect(result) == 5
    }
    
    func testMaterialize_shouldDematerializeToSameErrorCase() {
        let future = Future<Int, SampleError>(error: .someError)
        
        let derivedFuture = future.materialize().dematerialize()
        
        expect { try derivedFuture.get() }.to(throwError(SampleError.someError))
    }
    
    func testFirstCompletedOfShouldReturnFirstCompletedFutureResult() {
        let future1 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 1).delay(0.2, on: QueueScheduler()))
        let future2 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 2).delay(0.3, on: QueueScheduler()))
        let future3 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 3).delay(0.1, on: QueueScheduler()))
        
        let result = try! Futures.firstCompletedOf(future1, future2, future3).get()
        
        expect(result) == 3
    }
    
    func testCombineShouldWaitAllFuturesHaveCompleted() {
        let future1 = Future<String, NoError>(signalProducer: SignalProducer<String, NoError>(value: "bla").delay(0.2, on: QueueScheduler()))
        let future2 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 2).delay(0.3, on: QueueScheduler()))
        let future3 = Future<String, NoError>(signalProducer: SignalProducer<String, NoError>(value: "blo").delay(0.1, on: QueueScheduler()))
        let future4 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 1).delay(0.2, on: QueueScheduler()))
        let future5 = Future<String, NoError>(signalProducer: SignalProducer<String, NoError>(value: "blu").delay(0.3, on: QueueScheduler()))
        let future6 = Future<Int, NoError>(signalProducer: SignalProducer<Int, NoError>(value: 3).delay(0.1, on: QueueScheduler()))
        
        let result = try! Futures.combine(future1, future2, future3, future4, future5, future6).get()
        
        expect(result.0) == "bla"
        expect(result.1) == 2
        expect(result.2) == "blo"
        expect(result.3) == 1
        expect(result.4) == "blu"
        expect(result.5) == 3
    }
    
    func testExecuteSequentiallyShouldExecuteFutureInOrder() {
        let elements = ["Hi", "my", "name", "is", "Clement"]
        var sentence = ""
        
        let result = try! Futures.executeSequentially(elements) { word -> Future<String, NoError> in
            return Future(value: word).map { x -> String in
                sentence += "\(x)"
                return x
            }
            }.get()
        
        expect(result) == elements
        expect(sentence) == "HimynameisClement"
    }
    
    func testExecuteSequentiallyShouldExecuteFutureInOrderAndFailIfOneOfTheFutureFails() {
        
        enum TestError: Error {
            case error1
        }
        
        func futureFailure(value: UInt8) -> Future<Void, TestError> {
            if value == 1 {
                return Future(error: .error1)
            } else {
                return Future(value: ())
            }
        }
        
        let array: [UInt8] = [0, 1, 2]
        
        let result = try! Futures.executeSequentially(array) { value -> Future<Void, TestError> in
            return futureFailure(value: value)
            }.materialize().get()
        
        switch result {
        case .success(_):
            XCTFail("Future should fail with someError")
        case .failure(let error):
            switch error {
            case .error1:
                // GOOD
                break
            }
        }
    }
    
    func testOnSuccessCallsClosureOnMainThreadIfRequired() {
        
        let sut = Future<String, NoError>(value: "myString")
        
        waitUntil(timeout: 5) { done in
            
            sut.onSuccess { value in
                if Thread.current.isMainThread {
                    XCTFail()
                    done()
                } else {
                    sut.onSuccess(scheduler: UIScheduler()) { value in
                        if Thread.current.isMainThread {
                            done()
                        } else {
                            XCTFail()
                            done()
                        }
                    }
                }
            }
            
        }
        
    }
    
    func testOnFailureCallsClosureOnMainThreadIfRequired() {
        
        let sut = Future<String, SampleError>(error: .timeout)
        
        waitUntil(timeout: 5) { done in
            
            sut.onFailure { value in
                if Thread.current.isMainThread {
                    XCTFail()
                    done()
                } else {
                    sut.onFailure(scheduler: UIScheduler()) { value in
                        if Thread.current.isMainThread {
                            done()
                        } else {
                            XCTFail()
                            done()
                        }
                    }
                }
            }
            
        }
        
    }
    
    func testOnCompleteCallsClosureOnMainThreadIfRequired() {
        
        let sut = Future<String, SampleError>(value: "myString")
        
        waitUntil(timeout: 5) { done in
            
            sut.onComplete { value in
                if Thread.current.isMainThread {
                    XCTFail()
                    done()
                } else {
                    sut.onComplete(scheduler: UIScheduler()) { value in
                        if Thread.current.isMainThread {
                            done()
                        } else {
                            XCTFail()
                            done()
                        }
                    }
                }
            }
            
        }
        
    }
    
}

public func equal<T : Equatable, Error : Equatable>(_ expectedValue: Result<T, Error>) -> MatcherFunc<Result<T, Error>> {
    
    return MatcherFunc { actualExpression, failureMessage in
        failureMessage.postfixMessage = "equal <\(expectedValue)>"
        let x = try! actualExpression.evaluate()!
        return x == expectedValue
    }
    
}
