// Adapted from SkyLightWindow/SkyLightOperator.swift
// Copyright (c) 2025 Lakr Aream — MIT; see Vendor/SkyLightWindow/LICENSE.
// Pinned upstream: a28588bc5222b8daf6c4b46afb462a5d31495685
import AppKit
import OSLog

enum SkyLightFailure: LocalizedError {
    case unavailable(String)
    case call(String, Int32)
    var errorDescription: String? {
        switch self {
        case .unavailable(let name): return String(format: NSLocalizedString("SkyLight is unavailable: %@", comment: ""), name)
        case .call(let name, let code): return String(format: NSLocalizedString("SkyLight %@ failed (%d)", comment: ""), name, code)
        }
    }
}

/// Only this module knows the private ABI. No injection, input or focus APIs.
/// Function types follow the pinned SkyLightWindow implementation.
final class SkyLightBridge {
    typealias Connection = @convention(c) () -> Int32
    typealias Create = @convention(c) (Int32, Int32, Int32) -> Int32
    typealias Level = @convention(c) (Int32, Int32, Int32) -> Int32
    typealias Spaces = @convention(c) (Int32, CFArray) -> Int32
    typealias Add = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let handle: UnsafeMutableRawPointer
    private let connection: Int32
    private let create: Create
    private let setLevel: Level
    private let show: Spaces
    private let hide: Spaces
    private let add: Add
    private var space: Int32?
    private var needsHide = false
    private var poisoned = false
    private let logger = Logger(subsystem: "local.MaskedNotch", category: "SkyLight")

    init() throws {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW | RTLD_LOCAL) else {
            throw SkyLightFailure.unavailable("dlopen")
        }
        func symbol<T>(_ name: String, _: T.Type) throws -> T {
            guard let address = dlsym(handle, name) else { throw SkyLightFailure.unavailable(name) }
            return unsafeBitCast(address, to: T.self)
        }
        do {
            let main = try symbol("SLSMainConnectionID", Connection.self)
            create = try symbol("SLSSpaceCreate", Create.self)
            setLevel = try symbol("SLSSpaceSetAbsoluteLevel", Level.self)
            show = try symbol("SLSShowSpaces", Spaces.self)
            hide = try symbol("SLSHideSpaces", Spaces.self)
            add = try symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", Add.self)
            connection = main()
            guard connection > 0 else { throw SkyLightFailure.unavailable("connection") }
            self.handle = handle
        } catch {
            dlclose(handle)
            throw error
        }
    }

    func attach(_ window: NSWindow) throws {
        guard !poisoned else { throw SkyLightFailure.unavailable("previous cleanup failed; restart required") }
        guard !needsHide else { throw SkyLightFailure.unavailable("space already in use") }
        guard window.windowNumber > 0, Int32(exactly: window.windowNumber) != nil else {
            throw SkyLightFailure.unavailable("window number")
        }
        let newSpace: Int32
        if let space { newSpace = space }
        else {
            newSpace = create(connection, 1, 0)
            guard newSpace > 0 else { throw SkyLightFailure.unavailable("SLSSpaceCreate") }
            space = newSpace
        }
        needsHide = true
        do {
            // Upstream's screen-lock notification Space (400), enabled only while locked.
            // This is a compatibility candidate, not proof that OS indicators remain visible.
            try check("SLSSpaceSetAbsoluteLevel", setLevel(connection, newSpace, 400))
            try check("SLSSpaceAddWindowsAndRemoveFromSpaces",
                      add(connection, newSpace, [NSNumber(value: window.windowNumber)] as CFArray, 7))
            try check("SLSShowSpaces", show(connection, [NSNumber(value: newSpace)] as CFArray))
        } catch {
            window.orderOut(nil)
            window.close()
            _ = teardown()
            throw error
        }
    }

    /// Caller closes the band BEFORE hiding its Space. Never reuse a delegated panel.
    /// Keep at most one empty hidden Space per connection; WindowServer reclaims it at exit.
    /// This avoids adding an uncertain destroy ABI absent from the pinned upstream.
    @discardableResult func teardown() -> Bool {
        guard let space, needsHide else { return !poisoned }
        needsHide = false
        let hideResult = hide(connection, [NSNumber(value: space)] as CFArray)
        if hideResult != 0 {
            poisoned = true
            logger.error("Space cleanup failed: hide=\(hideResult)")
        }
        return !poisoned
    }

    private func check(_ operation: String, _ result: Int32) throws {
        guard result == 0 else { throw SkyLightFailure.call(operation, result) }
    }

    deinit { _ = teardown(); dlclose(handle) }
}
