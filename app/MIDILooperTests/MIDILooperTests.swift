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

    func testFirstIncomingEventStartsRecordingAndCompletesLoop() {
        var engine = SingleTrackLooperEngine()

        XCTAssertEqual(engine.snapshot(at: 0).trackState, .empty)

        _ = engine.handleRecordButton(at: 10)
        XCTAssertEqual(engine.snapshot(at: 10).trackState, .armed)
        XCTAssertTrue(engine.snapshot(at: 10).transportIsRunning)

        engine.handleIncomingMessages([[0x90, 60, 100]], at: 10.5)
        XCTAssertEqual(engine.snapshot(at: 10.5).trackState, .recording)

        engine.handleIncomingMessages([[0x80, 60, 0]], at: 11.0)
        _ = engine.handleRecordButton(at: 11.5)

        let snapshot = engine.snapshot(at: 11.5)
        XCTAssertEqual(snapshot.trackState, .playing)
        XCTAssertEqual(snapshot.bpm, 240)
        XCTAssertEqual(snapshot.recordButtonEnabled, false)
    }

    func testPlaybackReplaysRecordedMessagesInLoopOrder() {
        var engine = SingleTrackLooperEngine()

        _ = engine.handleRecordButton(at: 1.0)
        engine.handleIncomingMessages([[0x90, 60, 100]], at: 1.2)
        engine.handleIncomingMessages([[0x80, 60, 0]], at: 1.6)
        let closeOutput = engine.handleRecordButton(at: 2.2)

        XCTAssertEqual(closeOutput, [[0x90, 60, 100]])
        XCTAssertEqual(engine.advancePlayback(to: 2.65), [[0x80, 60, 0]])
        XCTAssertEqual(engine.advancePlayback(to: 3.25), [[0x90, 60, 100]])
    }

    func testLoopStartEventRepeatsOnEveryCycle() {
        var engine = SingleTrackLooperEngine()

        _ = engine.handleRecordButton(at: 1.0)
        engine.handleIncomingMessages([[0x90, 60, 100]], at: 1.0)
        engine.handleIncomingMessages([[0x80, 60, 0]], at: 1.4)
        let closeOutput = engine.handleRecordButton(at: 2.0)

        XCTAssertEqual(closeOutput, [[0x90, 60, 100]])
        XCTAssertEqual(engine.advancePlayback(to: 2.45), [[0x80, 60, 0]])
        XCTAssertEqual(engine.advancePlayback(to: 3.05), [[0x90, 60, 100]])
        XCTAssertEqual(engine.advancePlayback(to: 3.45), [[0x80, 60, 0]])
        XCTAssertEqual(engine.advancePlayback(to: 4.05), [[0x90, 60, 100]])
    }

    func testQueuedClearAppliesAtBoundaryAndReleasesPlaybackNote() {
        var engine = SingleTrackLooperEngine()

        _ = engine.handleRecordButton(at: 1.0)
        engine.handleIncomingMessages([[0x90, 60, 100]], at: 1.2)
        let closeOutput = engine.handleRecordButton(at: 2.2)

        XCTAssertEqual(closeOutput, [[0x90, 60, 100]])

        _ = engine.handleClearButton(at: 2.3)
        XCTAssertEqual(engine.snapshot(at: 2.3).queuedAction, .clear)

        let output = engine.advancePlayback(to: 3.25)
        XCTAssertEqual(output.last, [0x80, 60, 0])
        XCTAssertEqual(engine.snapshot(at: 3.25).trackState, .empty)
        XCTAssertEqual(engine.snapshot(at: 3.25).queuedAction, .none)
    }

    func testStoppingTransportReleasesPlaybackState() {
        var engine = SingleTrackLooperEngine()

        _ = engine.handleRecordButton(at: 1.0)
        engine.handleIncomingMessages([[0x90, 60, 100], [0xB0, 64, 127]], at: 1.2)
        _ = engine.handleRecordButton(at: 2.2)

        _ = engine.advancePlayback(to: 2.25)
        let stopOutput = engine.toggleTransport(at: 2.3)

        XCTAssertTrue(stopOutput.contains([0x80, 60, 0]))
        XCTAssertTrue(stopOutput.contains([0xB0, 64, 0]))
        XCTAssertFalse(engine.snapshot(at: 2.3).transportIsRunning)
    }
}
