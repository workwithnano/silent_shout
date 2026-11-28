#!/usr/bin/env swift
// Checks that the project's (MARKETING_VERSION, CURRENT_PROJECT_VERSION) pair has not already
// been uploaded to App Store Connect. Adapted from Up There's script of the same name. Reads
// ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH from the environment (the Makefile sources .env).

import CryptoKit
import Darwin
import Foundation

private typealias JSON = [String: Any]

private let apiBase = "https://api.appstoreconnect.apple.com"
private let bundleID = "com.corduroying.silentshout"
private let projectFile = "SilentShout.xcodeproj/project.pbxproj"

private struct ToolError: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

private func readText(_ path: String) throws -> String {
    do {
        return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
        throw ToolError(message: "could not read \(path): \(error.localizedDescription)")
    }
}

private func environment(_ name: String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        throw ToolError(message: "\(name) not set")
    }
    return value
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

// This script is invoked directly by make, so it keeps the same small,
// self-contained CryptoKit/API client as publish-metadata.swift.
private func makeToken() throws -> String {
    let keyID = try environment("ASC_KEY_ID")
    let issuerID = try environment("ASC_ISSUER_ID")
    let keyPath = try environment("ASC_KEY_PATH")
    let keyPEM = try readText(keyPath)

    let headerData = try JSONSerialization.data(withJSONObject: [
        "alg": "ES256", "kid": keyID, "typ": "JWT"
    ])
    let now = Int(Date().timeIntervalSince1970)
    let payloadData = try JSONSerialization.data(withJSONObject: [
        "iss": issuerID,
        "iat": now,
        "exp": now + 900,
        "aud": "appstoreconnect-v1"
    ])

    let signingInput = "\(base64URL(headerData)).\(base64URL(payloadData))"
    let key = try P256.Signing.PrivateKey(pemRepresentation: keyPEM)
    let signature = try key.signature(for: Data(signingInput.utf8))
    let rawSignature = signature.rawRepresentation
    guard rawSignature.count == 64 else {
        throw ToolError(message: "unexpected P-256 signature length")
    }
    return "\(signingInput).\(base64URL(rawSignature))"
}

private final class HTTPResult: @unchecked Sendable {
    var data = Data()
    var response: URLResponse?
    var error: Error?
}

private struct HTTPResponse {
    let statusCode: Int
    let data: Data
}

private func performRequest(_ request: URLRequest) throws -> HTTPResponse {
    let result = HTTPResult()
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        result.data = data ?? Data()
        result.response = response
        result.error = error
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()

    if let error = result.error {
        throw ToolError(message: error.localizedDescription)
    }
    guard let response = result.response as? HTTPURLResponse else {
        throw ToolError(message: "request returned no HTTP response")
    }
    return HTTPResponse(statusCode: response.statusCode, data: result.data)
}

private func api(
    _ token: String,
    _ method: String,
    _ path: String,
    payload: JSON? = nil
) throws -> JSON {
    guard let url = URL(string: apiBase + path) else {
        throw ToolError(message: "invalid URL \(apiBase + path)")
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let payload {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    }

    let response = try performRequest(request)
    guard (200..<300).contains(response.statusCode) else {
        let body = String(data: response.data, encoding: .utf8) ?? ""
        throw ToolError(message: "\(method) \(path) -> HTTP \(response.statusCode)\n\(body)")
    }
    guard !response.data.isEmpty else { return [:] }
    guard let object = try JSONSerialization.jsonObject(with: response.data) as? JSON else {
        throw ToolError(message: "\(method) \(path) returned a non-object JSON response")
    }
    return object
}

private func dataArray(_ response: JSON) -> [JSON] {
    response["data"] as? [JSON] ?? []
}

private func marketingVersion() throws -> String {
    let contents = try readText(projectFile)
    let regex = try NSRegularExpression(pattern: "MARKETING_VERSION = ([^;]+);")
    let range = NSRange(contents.startIndex..., in: contents)
    guard let match = regex.firstMatch(in: contents, range: range),
          let valueRange = Range(match.range(at: 1), in: contents) else {
        throw ToolError(message: "MARKETING_VERSION not found in pbxproj")
    }
    return String(contents[valueRange])
}

private func pythonList(_ values: [String]) -> String {
    "[" + values.map { "'\($0)'" }.joined(separator: ", ") + "]"
}

private func isASCIIDigitString(_ value: String) -> Bool {
    !value.isEmpty && value.unicodeScalars.allSatisfy { scalar in
        (48...57).contains(scalar.value)
    }
}

private func currentBuildNumber() throws -> Int {
    let contents = try readText(projectFile)
    let prefix = "CURRENT_PROJECT_VERSION = "
    var values = Set<String>()

    for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
        let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix(prefix) else { continue }
        var raw = String(stripped.dropFirst(prefix.count))
        while raw.last == ";" { raw.removeLast() }
        values.insert(raw)
    }

    guard values.count == 1 else {
        throw ToolError(message:
            "CURRENT_PROJECT_VERSION values are missing or inconsistent: \(pythonList(values.sorted()))")
    }
    let raw = values.first!
    guard isASCIIDigitString(raw), let value = Int(raw) else {
        throw ToolError(message: "CURRENT_PROJECT_VERSION '\(raw)' is not a plain integer")
    }
    return value
}

private func checkBuildNumber() throws {
    let version = try marketingVersion()
    let build = try currentBuildNumber()

    let token = try makeToken()
    let apps = try api(token, "GET", "/v1/apps?filter[bundleId]=\(bundleID)")
    // The filter is not an exact match, so compare the bundle id here.
    guard let app = dataArray(apps).first(where: {
              ($0["attributes"] as? JSON)?["bundleId"] as? String == bundleID
          }),
          let appID = app["id"] as? String else {
        throw ToolError(message:
            "no App Store Connect app record uses \(bundleID) yet, so there is nothing to " +
            "compare \(version) (\(build)) against. Create the record on the website " +
            "(docs/release.md), then rerun.")
    }

    // Builds are per pre-release version, so filter to this marketing version.
    let builds = try api(
        token,
        "GET",
        "/v1/builds?filter[app]=\(appID)&filter[preReleaseVersion.version]=\(version)&limit=200")

    var used = Set<Int>()
    for item in dataArray(builds) {
        guard let raw = (item["attributes"] as? JSON)?["version"] as? String,
              isASCIIDigitString(raw),
              let number = Int(raw) else { continue }
        used.insert(number)
    }

    if used.isEmpty {
        print("✓ build number: \(version) (\(build)) — no builds uploaded for this version yet")
        return
    }

    let highest = used.max()!
    if used.contains(build) {
        throw ToolError(message:
            "build \(version) (\(build)) is already in App Store Connect; " +
            "run 'make bump-build' to move to \(highest + 1)")
    }
    if build < highest {
        throw ToolError(message:
            "build number \(build) is below \(highest), already uploaded " +
            "for \(version); run 'make bump-build' to move to \(highest + 1)")
    }

    print("✓ build number: \(version) (\(build)) — free; highest uploaded is \(highest)")
}

do {
    try checkBuildNumber()
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
