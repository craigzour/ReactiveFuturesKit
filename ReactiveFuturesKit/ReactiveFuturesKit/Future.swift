//
//  Future.swift
//  ReactiveFuturesKit
//
//  Created by clement on 2017-06-15.
//  Copyright © 2017 OMsignal. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

public protocol FutureType {
    associatedtype Value
    associatedtype Error: Swift.Error
    
    var futureProducer: SignalProducer<Value, Error> { get }
}


public enum FutureFailure<E: Error>: Error {
    case error(error: E)
    case interrupted
}

/**
 A [Promise] is an object which can be completed with a value or failed with an error.
 */
public class Promise<Value, Error: Swift.Error> {
    private let observer: Signal<Value, Error>.Observer
    
    init(observer: Signal<Value, Error>.Observer) {
        self.observer = observer
    }
    
    public func success(_ value: Value) -> Void {
        self.observer.send(value: value)
        self.observer.sendCompleted()
    }
    
    public func failure(_ error : Error) -> Void {
        self.observer.send(error: error)
    }
    
    public func interrupted() -> Void {
        self.observer.sendInterrupted()
    }
}

/**
 A [Future](https://en.wikipedia.org/wiki/Futures_and_promises) based on ReactiveCoacoa's SignalProducer
 
 Compared to a generic SignalProducer, a Future will either
 - have a value AND successfully complete
 - have NO value AND fail
 */
public class Future<Value, Error: Swift.Error>: Disposable, FutureType {
    
    public let futureProducer: SignalProducer<Value, Error>
    
    private let disposable: Disposable
    
    public init(signalProducer: SignalProducer<Value, Error>) {
        self.futureProducer = signalProducer.take(first: 1).replayLazily(upTo: 1)
        
        self.disposable = self.futureProducer.start()
    }
    
    public convenience init<C: PropertyProtocol>(property: C) where C.Value == Value {
        self.init(value: property.value)
    }
    
    public convenience init(_ promiseHandler: @escaping (Promise<Value, Error>) -> Void) {
        let signalProducer = SignalProducer<Value, Error> { observer, disposable in
            let promise = Promise(observer: observer)
            promiseHandler(promise)
        }
        self.init(signalProducer: signalProducer)
    }
    
    public convenience init(value: Value) {
        self.init(signalProducer: SignalProducer(value: value))
    }
    
    public convenience init(error: Error) {
        self.init(signalProducer: SignalProducer(error: error))
    }
    
    public func map<U>(_ transform: @escaping (Value) -> U) -> Future<U, Error> {
        let transformedProducer = self.futureProducer.map(transform)
        return Future<U, Error>(signalProducer: transformedProducer)
    }
    
    public func mapError<F>(_ handler: @escaping (Error) -> F) -> Future<Value, F> {
        let transformedProducer = self.futureProducer.mapError(handler)
        return Future<Value, F>(signalProducer: transformedProducer)
    }
    
    public func flatMap<U>(_ transform: @escaping (Value) -> Future<U, Error>) -> Future<U, Error> {
        let transformedProducer = self.futureProducer.flatMap(FlattenStrategy.concat) { value -> SignalProducer<U, Error> in
            let resultFuture = transform(value)
            return resultFuture.futureProducer
        }
        return Future<U, Error>(signalProducer: transformedProducer)
    }
    
    public func flatMapError<F>(_ handler: @escaping (Error) -> Future<Value, F>) -> Future<Value, F> {
        let transformedProducer = self.futureProducer.flatMapError { error -> SignalProducer<Value, F> in
            let resultFuture = handler(error)
            return resultFuture.futureProducer
        }
        return Future<Value, F>(signalProducer: transformedProducer)
    }
    
    public func onSuccess(scheduler: Scheduler = QueueScheduler(), _ successCallback: @escaping (Value) -> ()) -> Void {
        // C.J: FYI > https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2942#issuecomment-222284617
        self
            .futureProducer
            .observe(on: scheduler)
            .on(value: successCallback)
            .start()
    }
    
    public func onFailure(scheduler: Scheduler = QueueScheduler(), _ failureHandler: @escaping (FutureFailure<Error>) -> Void) -> Void {
        self
            .futureProducer
            .observe(on: scheduler)
            .on(failed: { error in
                failureHandler(FutureFailure.error(error: error))
            }, interrupted: { () in
                failureHandler(FutureFailure.interrupted)
            })
            .start()
    }
    
    public func onComplete(scheduler: Scheduler = QueueScheduler(), _ completionCallback: @escaping (Result<Value, FutureFailure<Error>>) -> Void) -> Void {
        self
            .futureProducer
            .observe(on: scheduler)
            .on(failed: { error in
                completionCallback(Result.failure(FutureFailure.error(error: error)))
            }, interrupted: { () in
                completionCallback(Result.failure(FutureFailure.interrupted))
            }, value: { value in
                completionCallback(Result.success(value))
            })
            .start()
    }
    
    public func combineWith<U>(_ otherFuture: Future<U, Error>) -> Future<(Value, U), Error> {
        let transformedProducer = self.futureProducer.combineLatest(with: otherFuture.futureProducer)
        return Future<(Value, U), Error>(signalProducer: transformedProducer)
    }
    
    public func delay(_ interval: TimeInterval) -> Future<Value, Error> {
        let transformedProducer = self.futureProducer.delay(interval, on: QueueScheduler())
        return Future<Value, Error>(signalProducer: transformedProducer)
    }
    
    public func timeout(after interval: TimeInterval, raising error: Error) -> Future<Value, Error> {
        let transformedProducer = self.futureProducer.timeout(after: interval, raising: error, on: QueueScheduler())
        return Future<Value, Error>(signalProducer: transformedProducer)
    }
    
    public func materialize() -> Future<Result<Value, Error>, NoError> {
        return self
            .map { Result.success($0) }
            .flatMapError { Future<Result<Value, Error>, NoError>(value: Result.failure($0)) }
    }
    
    public var isDisposed: Bool {
        get {
            return self.disposable.isDisposed
        }
    }
    
    public func dispose() -> Void {
        self.disposable.dispose()
    }
    
    /**
     @OnlyForTesting
     Return the value on blocking mode
     */
    public func get() throws -> Value {
        return try self.futureProducer
            .single()!
            .dematerialize()
    }
    
    /**
     @OnlyForTesting
     Return the value on blocking mode with a TimeOut
     Throws FutureFailure.Interrupted if the timeout is reached
     */
    public func get(timeout: TimeInterval) throws -> Value {
        //create a event FAILED signal which wait of throwing an exception when we are reaching the delay
        let errorProducer : SignalProducer<Value, FutureFailure<Error>> = SignalProducer(value: Event.failed(FutureFailure<Error>.interrupted))
            .delay(timeout, on: QueueScheduler())
            // will check the event and throw the exception
            .dematerialize()
        
        // Need to transform the normal error into a FutureFailure for the current signal
        let valueProducer = self.futureProducer.mapError { FutureFailure.error(error: $0) }
        let merged = SignalProducer.merge([errorProducer, valueProducer])
        
        //Take the first signal emitted Value or throw the exception
        return try merged
            .take(first: 1)
            .single()!
            .dematerialize()
    }
}

extension FutureType where Error == NoError  {
    
    public func promoteErrors<F: Swift.Error>(_: F.Type) -> Future<Value, F> {
        let transformedProducer = self.futureProducer.promoteErrors(F.self)
        return Future<Value, F>(signalProducer: transformedProducer)
    }
    
    public func flatMap<U, E: Swift.Error>(_ transform: @escaping (Value) -> Future<U, E>) -> Future<U, E> {
        return self
            .promoteErrors(E.self)
            .flatMap(transform)
    }
    
}

extension FutureType where Value : ResultProtocol, Error == NoError {
    
    public func dematerialize() -> Future<Value.Value, Value.Error> {
        return self
            .promoteErrors(Value.Error.self)
            .flatMap { value in
                return value.value.map { v in return Future(value: v) } ?? Future(error: value.error!)
        }
    }
    
}

extension FutureType {
    
    public static func never() -> Future<Value, Error> {
        return SignalProducer<Value, Error>.never.toFuture()
    }
    
}

public struct Futures {
    
    public static func firstCompletedOf<Value, Error>(_ futures: Future<Value, Error>...) -> Future<Value, Error> {
        let signals = futures.map { $0.futureProducer }
        let mergedSignals = SignalProducer<Value, Error>.merge(signals)
        return Future(signalProducer: mergedSignals)
    }
    
    public static func combine<A, B, C, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>) -> Future<(A, B, C), Error> {
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer)
        return Future<(A, B, C), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>) -> Future<(A, B, C, D), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer, futureD.futureProducer)
        return Future<(A, B, C, D), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>, _ futureE: Future<E, Error>) -> Future<(A, B, C, D, E), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer)
        return Future<(A, B, C, D, E), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, F, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>, _ futureE: Future<E, Error>, _ futureF: Future<F, Error>) -> Future<(A, B, C, D, E, F), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer, futureF.futureProducer)
        return Future<(A, B, C, D, E, F), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, F, G, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>, _ futureE: Future<E, Error>, _ futureF: Future<F, Error>,
                               _ futureG: Future<G, Error>) -> Future<(A, B, C, D, E, F, G), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer, futureF.futureProducer,
                                                           futureG.futureProducer)
        return Future<(A, B, C, D, E, F, G), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, F, G, H, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>, _ futureE: Future<E, Error>, _ futureF: Future<F, Error>,
                               _ futureG: Future<G, Error>, _ futureH: Future<H, Error>) -> Future<(A, B, C, D, E, F, G, H), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer, futureF.futureProducer,
                                                           futureG.futureProducer, futureH.futureProducer)
        return Future<(A, B, C, D, E, F, G, H), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, F, G, H, I, Error>(_ futureA: Future<A, Error>, _ futureB: Future<B, Error>, _ futureC: Future<C, Error>,
                               _ futureD: Future<D, Error>, _ futureE: Future<E, Error>, _ futureF: Future<F, Error>,
                               _ futureG: Future<G, Error>, _ futureH: Future<H, Error>, _ futureI: Future<I, Error>) -> Future<(A, B, C, D, E, F, G, H, I), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer, futureF.futureProducer,
                                                           futureG.futureProducer, futureH.futureProducer, futureI.futureProducer)
        return Future<(A, B, C, D, E, F, G, H, I), Error>(signalProducer: combinedSignals)
    }
    
    public static func combine<A, B, C, D, E, F, G, H, I, J, Error>(_ futureA: Future<A, Error>,
                               _ futureB: Future<B, Error>, _ futureC: Future<C, Error>, _ futureD: Future<D, Error>,
                               _ futureE: Future<E, Error>, _ futureF: Future<F, Error>, _ futureG: Future<G, Error>,
                               _ futureH: Future<H, Error>, _ futureI: Future<I, Error>, _ futureJ: Future<J, Error>) -> Future<(A, B, C, D, E, F, G, H, I, J), Error> {
        
        let combinedSignals = SignalProducer.combineLatest(futureA.futureProducer, futureB.futureProducer, futureC.futureProducer,
                                                           futureD.futureProducer, futureE.futureProducer, futureF.futureProducer,
                                                           futureG.futureProducer, futureH.futureProducer, futureI.futureProducer, futureJ.futureProducer)
        return Future<(A, B, C, D, E, F, G, H, I, J), Error>(signalProducer: combinedSignals)
    }
    
    public static func executeSequentially<T,R, Error>(_ elements: [T], _ executeNext: @escaping (T) -> Future<R, Error>) -> Future<[R], Error> {
        return elements.reduce(Future(value: [])) { acc, current in
            return acc.flatMap { list in executeNext(current).map { result in list + [result] } }
        }
    }
    
}
