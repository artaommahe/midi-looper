//
//  MIDILooperTests.swift
//  MIDILooperTests
//
//  Created by maksim on 05/04/2026.
//

import XCTest
@testable import MIDILooper

final class MIDILooperTests: XCTestCase {

    func testParserKeepsNoteOnAndNoteOff() {
        let messages = MIDIMessageParser.forwardedMessages(from: [0x90, 60, 100, 0x80, 60, 0])

        XCTAssertEqual(messages.map(\.rawBytes), [[0x90, 60, 100], [0x80, 60, 0]])
    }

    func testParserKeepsSustainButDropsOtherControlChanges() {
        let messages = MIDIMessageParser.forwardedMessages(from: [0xB0, 1, 64, 0xB0, 64, 127])

        XCTAssertEqual(messages.map(\.rawBytes), [[0xB0, 64, 127]])
    }

    func testParserUsesRunningStatus() {
        let messages = MIDIMessageParser.forwardedMessages(from: [0x90, 60, 110, 64, 120])

        XCTAssertEqual(messages.map(\.rawBytes), [[0x90, 60, 110], [0x90, 64, 120]])
    }
}
