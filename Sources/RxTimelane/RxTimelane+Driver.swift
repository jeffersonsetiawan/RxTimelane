//
//  RxTimelane.swift
//  ABTesting
//
//  Created by Jefferson Setiawan on 23/04/20.
//

import Foundation
import RxCocoa
import RxSwift
import TimelaneCore

fileprivate let lock = NSLock()

/// The `lane` operator logs the subscription and its events to the Timelane Instrument.
///
///  - Note: You can download the Timelane Instrument from http://timelane.tools
/// - Parameters:
///   - name: A name for the lane when visualized in Instruments
///   - transformValue: An optional closure to format the subscription values for displaying in Instruments.
///                     You can not only prettify the values but also change them completely, e.g. for arrays you can
///                     it might be more useful to report the count of elements if there are a lot of them.
///   - value: The value emitted by the subscription
extension SharedSequence where SharingStrategy == DriverSharingStrategy {
    public func lane(_ name: String,
                     file: StaticString = #file,
                     function: StaticString = #function, line: UInt = #line,
                     transformValue transform: @escaping (_ value: Element) -> String = { String(describing: $0) }) -> SharedSequence<DriverSharingStrategy, Element> {
        guard #available(iOS 12, *) else {
            return self
        }
        let filter = Set(Timelane.LaneType.allCases)
        let logger = Timelane.defaultLogger
        let fileName = file.description.components(separatedBy: "/").last!
        let source = "\(fileName):\(line) - \(function)"
        let subscription = Timelane.Subscription(name: name, logger: logger)

        var terminated = false

        return `do`(onNext: { element in
            if filter.contains(.event) {
                subscription.event(value: .value(transform(element)), source: source)
            }
        },
                    onCompleted: {
            lock.lock()
            defer { lock.unlock() }
            guard !terminated else { return }
            terminated = true

            if filter.contains(.subscription) {
                subscription.end(state: .completed)
            }

            if filter.contains(.event) {
                subscription.event(value: .completion, source: source)
            }
        },
                    onSubscribe: {
            if filter.contains(.subscription) {
                subscription.begin(source: source)
            }
        },
                    onDispose: {
            lock.lock()
            defer { lock.unlock() }
            guard !terminated else { return }
            terminated = true

            if filter.contains(.subscription) {
                subscription.end(state: .cancelled)
            }

            if filter.contains(.event) {
                subscription.event(value: .cancelled, source: source)
            }
        })
    }
}
