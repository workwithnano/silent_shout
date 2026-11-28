#!/usr/bin/env swift
// App Store Connect bundle id and app record checks for Silent Shout.
//
//   swift scripts/asc-bundle-id.swift status    # is the bundle id registered?
//   swift scripts/asc-bundle-id.swift register  # register it (only if it does not exist)
//   swift scripts/asc-bundle-id.swift app       # does an app record use it?
//
// Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH from the environment (the Makefile sources
// .env). Prints ids and names only, never credentials. Swift rather than Python because the
// system Python on this workspace's Macs has no CA certificates.

import CryptoKit
import Darwin
import Foundation

private typealias JSON = [String: Any]

private let apiBase = "https://api.appstoreconnect.apple.com"
private let bundleID = "com.corduroying.silentshout"
private let bundleName = "Silent Shout"

private struct ToolError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

private func environment(_ name: String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        throw ToolError(message: "\(name) is not set (fill it in .env)")
    }
    return value
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func makeToken() throws -> String {
    let keyID = try environment("ASC_KEY_ID")
    let issuerID = try environment("ASC_ISSUER_ID")
    let keyPath = try environment("ASC_KEY_PATH")
    let keyPEM: String
    do {
        keyPEM = try String(contentsOfFile: keyPath, encoding: .utf8)
    } catch {
        throw ToolError(message: "could not read the key at ASC_KEY_PATH")
    }

    let headerData = try JSONSerialization.data(withJSONObject: [
        "alg": "ES256", "kid": keyID, "typ": "JWT",
    ])
    let now = Int(Date().timeIntervalSince1970)
    let payloadData = try JSONSerialization.data(withJSONObject: [
        "iss": issuerID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1",
    ])
    let signingInput = "\(base64URL(headerData)).\(base64URL(payloadData))"
    let key: P256.Signing.PrivateKey
    do {
        key = try P256.Signing.PrivateKey(pemRepresentation: keyPEM)
    } catch {
        throw ToolError(message: "the key at ASC_KEY_PATH is not a P-256 private key")
    }
    let signature = try key.signature(for: Data(signingInput.utf8)).rawRepresentation
    guard signature.count == 64 else { throw ToolError(message: "unexpected P-256 signature length") }
    return "\(signingInput).\(base64URL(signature))"
}

private final class HTTPResult: @unchecked Sendable {
    var data = Data()
    var response: URLResponse?
    var error: Error?
}

/// Formats the API's `errors` array as "title: detail" lines, falling back to the raw body.
private func apiErrorMessage(_ data: Data) -> String {
    if let object = try? JSONSerialization.jsonObject(with: data) as? JSON,
       let errors = object["errors"] as? [JSON], !errors.isEmpty {
        return errors.map { error in
            let title = error["title"] as? String ?? "error"
            let detail = error["detail"] as? String ?? ""
            let code = error["code"] as? String ?? ""
            return "  \(title)\(code.isEmpty ? "" : " [\(code)]"): \(detail)"
        }.joined(separator: "\n")
    }
    return String(data: data, encoding: .utf8) ?? ""
}

private func api(_ token: String, _ method: String, _ path: String, payload: JSON? = nil) throws -> JSON {
    guard let url = URL(string: apiBase + path) else {
        throw ToolError(message: "invalid URL \(apiBase + path)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let payload { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }

    let result = HTTPResult()
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, error in
        result.data = data ?? Data()
        result.response = response
        result.error = error
        semaphore.signal()
    }.resume()
    semaphore.wait()

    if let error = result.error { throw ToolError(message: "\(method) \(path): \(error.localizedDescription)") }
    guard let http = result.response as? HTTPURLResponse else {
        throw ToolError(message: "\(method) \(path) returned no HTTP response")
    }
    guard (200..<300).contains(http.statusCode) else {
        throw ToolError(message: "\(method) \(path) -> HTTP \(http.statusCode)\n\(apiErrorMessage(result.data))")
    }
    guard !result.data.isEmpty else { return [:] }
    guard let object = try JSONSerialization.jsonObject(with: result.data) as? JSON else {
        throw ToolError(message: "\(method) \(path) returned a non-object JSON response")
    }
    return object
}

private func dataArray(_ response: JSON) -> [JSON] { response["data"] as? [JSON] ?? [] }
private func attributes(_ item: JSON) -> JSON { item["attributes"] as? JSON ?? [:] }

/// The registered bundle id resource, if any. The API's identifier filter matches prefixes and
/// substrings too (it would also return `com.corduroying.silentshout.tests`), so the identifier
/// is compared exactly here.
private func findBundleID(_ token: String) throws -> JSON? {
    let response = try api(token, "GET", "/v1/bundleIds?filter[identifier]=\(bundleID)&limit=200")
    return dataArray(response).first { attributes($0)["identifier"] as? String == bundleID }
}

private func describe(_ item: JSON) -> String {
    let a = attributes(item)
    let id = item["id"] as? String ?? "?"
    let name = a["name"] as? String ?? "?"
    let platform = a["platform"] as? String ?? "?"
    return "\(a["identifier"] as? String ?? bundleID): id \(id), name \"\(name)\", platform \(platform)"
}

private func status() throws {
    let token = try makeToken()
    if let item = try findBundleID(token) {
        print("✓ bundle id registered: \(describe(item))")
    } else {
        print("✗ bundle id \(bundleID) is not registered (run make asc-bundle-id-register)")
        exit(1)
    }
}

private func register() throws {
    let token = try makeToken()
    if let item = try findBundleID(token) {
        print("✓ already registered, left as it is: \(describe(item))")
        return
    }
    let response = try api(token, "POST", "/v1/bundleIds", payload: [
        "data": [
            "type": "bundleIds",
            "attributes": ["identifier": bundleID, "name": bundleName, "platform": "IOS"],
        ],
    ])
    guard let item = response["data"] as? JSON else {
        throw ToolError(message: "POST /v1/bundleIds returned no data")
    }
    print("✓ registered: \(describe(item))")
}

private func app() throws {
    let token = try makeToken()
    let response = try api(token, "GET", "/v1/apps?filter[bundleId]=\(bundleID)&limit=200")
    guard let item = dataArray(response).first(where: { attributes($0)["bundleId"] as? String == bundleID }) else {
        print("✗ no App Store Connect app record uses \(bundleID) yet. Create it on the website (docs/release.md).")
        exit(1)
    }
    let a = attributes(item)
    print("✓ app record: name \"\(a["name"] as? String ?? "?")\", id \(item["id"] as? String ?? "?"), " +
          "SKU \(a["sku"] as? String ?? "?"), bundle id \(bundleID)")
}

let command = CommandLine.arguments.dropFirst().first ?? "status"
do {
    switch command {
    case "status": try status()
    case "register": try register()
    case "app": try app()
    default:
        fputs("usage: asc-bundle-id.swift status|register|app\n", stderr)
        exit(2)
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
