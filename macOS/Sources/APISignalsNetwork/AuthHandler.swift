import Foundation
import CryptoKit
import APISignalsCore

public struct AuthHandler: Sendable {
    public init() {}

    public func apply(auth: Auth, to urlRequest: inout URLRequest) {
        switch auth {
        case .none:
            break
        case .bearer(let token):
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
                .data(using: .utf8)?
                .base64EncodedString() ?? ""
            urlRequest.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case .apiKey(let key, let value, let location):
            switch location {
            case .header:
                urlRequest.setValue(value, forHTTPHeaderField: key)
            case .query:
                var components = urlRequest.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
                var queryItems = components?.queryItems ?? []
                queryItems.append(URLQueryItem(name: key, value: value))
                components?.queryItems = queryItems
                if let newUrl = components?.url {
                    urlRequest.url = newUrl
                }
            }
        case .oauth1(let config):
            applyOAuth1(config: config, to: &urlRequest)
        case .oauth2(let config):
            if let token = config.token, !token.isEmpty {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .digest(let username, let password):
            // Digest auth is challenge-response; set credentials for URLSession challenge handling
            // For initial request, send basic-style to trigger challenge (URLSession handles digest automatically if URLCredential is set via delegate)
            let credentials = "\(username):\(password)"
                .data(using: .utf8)?
                .base64EncodedString() ?? ""
            urlRequest.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case .ntlm:
            // NTLM is handled via URLSession authentication challenge; no header needed upfront
            break
        case .awsSignature(let config):
            applyAWSSignatureV4(config: config, to: &urlRequest)
        }
    }

    private func applyAWSSignatureV4(config: AWSSignatureConfig, to urlRequest: inout URLRequest) {
        guard let url = urlRequest.url else { return }

        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let amzDate = dateFormatter.string(from: now).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let dateStamp = String(amzDate.prefix(8))
        let method = urlRequest.httpMethod ?? "GET"

        urlRequest.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")

        // Canonical URI
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let canonicalUri = components?.path.isEmpty == false ? components!.path : "/"
        let canonicalQueryString = (components?.queryItems ?? [])
            .sorted { $0.name < $1.name }
            .map { "\(percentEncodeAWS($0.name))=\(percentEncodeAWS($0.value ?? ""))" }
            .joined(separator: "&")

        // Headers to sign
        var signedHeaders: [(name: String, value: String)] = [
            ("host", url.host ?? ""),
            ("x-amz-date", amzDate)
        ]
        signedHeaders.sort { $0.name < $1.name }

        let canonicalHeaders = signedHeaders.map { "\($0.name):\($0.value)\n" }.joined()
        let signedHeaderNames = signedHeaders.map(\.name).joined(separator: ";")

        let bodyData = urlRequest.httpBody ?? Data()
        let payloadHash = SHA256.hash(data: bodyData).map { String(format: "%02x", $0) }.joined()

        let canonicalRequest = [
            method,
            canonicalUri,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaderNames,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(config.region)/\(config.service)/aws4_request"
        let algorithm = "AWS4-HMAC-SHA256"

        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8))
            .map { String(format: "%02x", $0) }.joined()

        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequestHash
        ].joined(separator: "\n")

        let signingKey = deriveSigningKey(
            secretKey: config.secretKey,
            dateStamp: dateStamp,
            region: config.region,
            service: config.service
        )
        let signature = hmacSHA256(key: signingKey, message: stringToSign)
            .map { String(format: "%02x", $0) }.joined()

        let authHeader = "\(algorithm) Credential=\(config.accessKey)/\(credentialScope), SignedHeaders=\(signedHeaderNames), Signature=\(signature)"
        urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }

    private func deriveSigningKey(secretKey: String, dateStamp: String, region: String, service: String) -> [UInt8] {
        let kSecret = Array(("AWS4" + secretKey).utf8)
        let kDate = hmacSHA256(key: kSecret, message: dateStamp)
        let kRegion = hmacSHA256(key: kDate, message: region)
        let kService = hmacSHA256(key: kRegion, message: service)
        return hmacSHA256(key: kService, message: "aws4_request")
    }

    private func hmacSHA256(key: [UInt8], message: String) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: symmetricKey)
        return Array(mac)
    }

    private func percentEncodeAWS(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func applyOAuth1(config: OAuth1Config, to urlRequest: inout URLRequest) {
        guard let url = urlRequest.url else { return }

        let method = urlRequest.httpMethod ?? "GET"
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var oauthParams: [(String, String)] = [
            ("oauth_consumer_key", config.consumerKey),
            ("oauth_nonce", nonce),
            ("oauth_signature_method", config.signatureMethod),
            ("oauth_timestamp", timestamp),
            ("oauth_token", config.token),
            ("oauth_version", config.version),
        ]

        // Collect base parameters: oauth params + query params
        var allParams = oauthParams
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            for item in components.queryItems ?? [] {
                allParams.append((item.name, item.value ?? ""))
            }
        }

        let encodedParams: [(String, String)] = allParams.map { (percentEncode($0.0), percentEncode($0.1)) }
        let sortedParams = encodedParams
            .sorted { lhs, rhs in lhs.0 < rhs.0 || (lhs.0 == rhs.0 && lhs.1 < rhs.1) }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")

        // Base URL without query string
        var baseComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        baseComponents?.query = nil
        baseComponents?.fragment = nil
        let baseUrl = baseComponents?.string ?? url.absoluteString

        let signatureBase = [
            percentEncode(method.uppercased()),
            percentEncode(baseUrl),
            percentEncode(sortedParams)
        ].joined(separator: "&")

        let signingKey = "\(percentEncode(config.consumerSecret))&\(percentEncode(config.tokenSecret))"

        let signature: String
        if config.signatureMethod == "HMAC-SHA1" {
            signature = hmacSHA1(key: signingKey, message: signatureBase)
        } else {
            signature = ""
        }

        oauthParams.append(("oauth_signature", signature))

        let headerValue = "OAuth " + oauthParams
            .map { "\(percentEncode($0.0))=\"\(percentEncode($0.1))\"" }
            .joined(separator: ", ")

        urlRequest.setValue(headerValue, forHTTPHeaderField: "Authorization")
    }

    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func hmacSHA1(key: String, message: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: symmetricKey)
        return Data(mac).base64EncodedString()
    }
}
