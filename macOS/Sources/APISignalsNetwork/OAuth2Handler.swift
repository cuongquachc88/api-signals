import Foundation
import APISignalsCore

public enum OAuth2Error: Error {
    case invalidConfiguration
    case tokenRequestFailed(String)
    case invalidTokenResponse
    case unsupportedGrantType
}

public actor OAuth2Handler {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func authorizationURL(config: OAuth2Config) -> URL? {
        guard let authUrlString = config.authUrl,
              let authUrl = URL(string: authUrlString) else {
            return nil
        }

        var components = URLComponents(url: authUrl, resolvingAgainstBaseURL: true)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "response_type", value: "code"))
        if let clientId = config.clientId {
            queryItems.append(URLQueryItem(name: "client_id", value: clientId))
        }
        if let redirectUri = config.redirectUri {
            queryItems.append(URLQueryItem(name: "redirect_uri", value: redirectUri))
        }
        if let scope = config.scope {
            queryItems.append(URLQueryItem(name: "scope", value: scope))
        }
        components?.queryItems = queryItems

        return components?.url
    }

    public func fetchToken(config: OAuth2Config) async -> Result<String, OAuth2Error> {
        switch config.grantType {
        case "client_credentials":
            return await fetchClientCredentialsToken(config: config)
        case "password":
            return await fetchPasswordToken(config: config)
        default:
            return .failure(.unsupportedGrantType)
        }
    }

    private func fetchClientCredentialsToken(config: OAuth2Config) async -> Result<String, OAuth2Error> {
        guard let tokenUrlString = config.accessTokenUrl,
              let tokenUrl = URL(string: tokenUrlString) else {
            return .failure(.invalidConfiguration)
        }

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var params: [String: String] = ["grant_type": "client_credentials"]
        if let scope = config.scope {
            params["scope"] = scope
        }

        if let clientId = config.clientId, let clientSecret = config.clientSecret {
            let credentials = "\(clientId):\(clientSecret)"
                .data(using: .utf8)?
                .base64EncodedString() ?? ""
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)

        return await executeTokenRequest(request)
    }

    private func fetchPasswordToken(config: OAuth2Config) async -> Result<String, OAuth2Error> {
        guard let tokenUrlString = config.accessTokenUrl,
              let tokenUrl = URL(string: tokenUrlString) else {
            return .failure(.invalidConfiguration)
        }

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // For password flow, we need username/password in config. Currently OAuth2Config doesn't have these fields.
        // This is a placeholder for when we extend OAuth2Config.
        var params: [String: String] = ["grant_type": "password"]
        if let scope = config.scope {
            params["scope"] = scope
        }

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)

        return await executeTokenRequest(request)
    }

    private func executeTokenRequest(_ request: URLRequest) async -> Result<String, OAuth2Error> {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(.tokenRequestFailed(String(data: data, encoding: .utf8) ?? "Unknown error"))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                return .failure(.invalidTokenResponse)
            }

            return .success(token)
        } catch {
            return .failure(.tokenRequestFailed(error.localizedDescription))
        }
    }
}
