import SwiftUI
import AppKit
import APISignalsCore
import APISignalsNetwork

struct AuthEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Type", selection: authTypeBinding) {
                ForEach(AuthType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            switch viewModel.request.auth {
            case .none:
                Text("No authentication")
                    .foregroundStyle(.secondary)
        case .bearer(let token):
            TextField("Token", text: Binding(
                get: { token },
                set: { viewModel.request.auth = .bearer(token: $0); viewModel.updateRequest() }
            ))
            .textFieldStyle(.roundedBorder)
        case .oauth1(let config):
            OAuth1Editor(config: config, onUpdate: { newConfig in
                viewModel.request.auth = .oauth1(newConfig)
                viewModel.updateRequest()
            })
        case .oauth2(let config):
            OAuth2Editor(config: config, onUpdate: { newConfig in
                viewModel.request.auth = .oauth2(newConfig)
                viewModel.updateRequest()
            })
        case .basic(let username, let password):
                HStack {
                    TextField("Username", text: Binding(
                        get: { username },
                        set: { viewModel.request.auth = .basic(username: $0, password: password); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: Binding(
                        get: { password },
                        set: { viewModel.request.auth = .basic(username: username, password: $0); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .apiKey(let key, let value, let location):
                VStack {
                    HStack {
                        TextField("Key", text: Binding(
                            get: { key },
                            set: { viewModel.request.auth = .apiKey(key: $0, value: value, location: location); viewModel.updateRequest() }
                        ))
                        .textFieldStyle(.roundedBorder)

                        TextField("Value", text: Binding(
                            get: { value },
                            set: { viewModel.request.auth = .apiKey(key: key, value: $0, location: location); viewModel.updateRequest() }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    Picker("Add to", selection: Binding(
                        get: { location },
                        set: { viewModel.request.auth = .apiKey(key: key, value: value, location: $0); viewModel.updateRequest() }
                    )) {
                        Text("Header").tag(APIKeyLocation.header)
                        Text("Query Params").tag(APIKeyLocation.query)
                    }
                    .pickerStyle(.segmented)
                }
            case .digest(let username, let password):
                HStack {
                    TextField("Username", text: Binding(
                        get: { username },
                        set: { viewModel.request.auth = .digest(username: $0, password: password); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: Binding(
                        get: { password },
                        set: { viewModel.request.auth = .digest(username: username, password: $0); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .ntlm(let username, let password, let domain):
                VStack {
                    HStack {
                        TextField("Username", text: Binding(
                            get: { username },
                            set: { viewModel.request.auth = .ntlm(username: $0, password: password, domain: domain); viewModel.updateRequest() }
                        ))
                        .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: Binding(
                            get: { password },
                            set: { viewModel.request.auth = .ntlm(username: username, password: $0, domain: domain); viewModel.updateRequest() }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    TextField("Domain (optional)", text: Binding(
                        get: { domain ?? "" },
                        set: { viewModel.request.auth = .ntlm(username: username, password: password, domain: $0.isEmpty ? nil : $0); viewModel.updateRequest() }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            case .awsSignature(let config):
                AWSSignatureEditor(config: config, onUpdate: { newConfig in
                    viewModel.request.auth = .awsSignature(newConfig)
                    viewModel.updateRequest()
                })
            }

            Spacer()
        }
        .padding()
    }

    private enum AuthType: String, CaseIterable {
        case none = "None"
        case bearer = "Bearer Token"
        case basic = "Basic Auth"
        case apiKey = "API Key"
        case oauth1 = "OAuth 1.0"
        case oauth2 = "OAuth 2.0"
        case digest = "Digest Auth"
        case ntlm = "NTLM"
        case awsSignature = "AWS Signature"
    }

    private var authTypeBinding: Binding<AuthType> {
        Binding(
            get: {
                switch viewModel.request.auth {
                case .none: return .none
                case .bearer: return .bearer
                case .basic: return .basic
                case .apiKey: return .apiKey
                case .oauth1: return .oauth1
                case .oauth2: return .oauth2
                case .digest: return .digest
                case .ntlm: return .ntlm
                case .awsSignature: return .awsSignature
                }
            },
            set: { newType in
                switch newType {
                case .none:
                    viewModel.request.auth = .none
                case .bearer:
                    viewModel.request.auth = .bearer(token: "")
                case .basic:
                    viewModel.request.auth = .basic(username: "", password: "")
                case .apiKey:
                    viewModel.request.auth = .apiKey(key: "", value: "", location: .header)
                case .oauth1:
                    viewModel.request.auth = .oauth1(OAuth1Config())
                case .oauth2:
                    viewModel.request.auth = .oauth2(OAuth2Config())
                case .digest:
                    viewModel.request.auth = .digest(username: "", password: "")
                case .ntlm:
                    viewModel.request.auth = .ntlm(username: "", password: "", domain: nil)
                case .awsSignature:
                    viewModel.request.auth = .awsSignature(AWSSignatureConfig(accessKey: "", secretKey: "", region: "us-east-1", service: "execute-api"))
                }
                viewModel.updateRequest()
            }
        )
    }
}

struct AWSSignatureEditor: View {
    let config: AWSSignatureConfig
    let onUpdate: (AWSSignatureConfig) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Access Key", text: Binding(
                    get: { config.accessKey },
                    set: { var c = config; c.accessKey = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField("Secret Key", text: Binding(
                    get: { config.secretKey },
                    set: { var c = config; c.secretKey = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                TextField("Region", text: Binding(
                    get: { config.region },
                    set: { var c = config; c.region = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Service", text: Binding(
                    get: { config.service },
                    set: { var c = config; c.service = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Text("AWS Signature V4 signing is applied to each request automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct OAuth1Editor: View {
    let config: OAuth1Config
    let onUpdate: (OAuth1Config) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Consumer Key", text: Binding(
                    get: { config.consumerKey },
                    set: { var c = config; c.consumerKey = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField("Consumer Secret", text: Binding(
                    get: { config.consumerSecret },
                    set: { var c = config; c.consumerSecret = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                TextField("Access Token", text: Binding(
                    get: { config.token },
                    set: { var c = config; c.token = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField("Token Secret", text: Binding(
                    get: { config.tokenSecret },
                    set: { var c = config; c.tokenSecret = $0; onUpdate(c) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Picker("Signature Method", selection: Binding(
                get: { config.signatureMethod },
                set: { var c = config; c.signatureMethod = $0; onUpdate(c) }
            )) {
                Text("HMAC-SHA1").tag("HMAC-SHA1")
                Text("PLAINTEXT").tag("PLAINTEXT")
            }
            .pickerStyle(.segmented)

            Text("OAuth Version: \(config.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct OAuth2Editor: View {
    let config: OAuth2Config
    let onUpdate: (OAuth2Config) -> Void
    @State private var isFetching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Grant Type", selection: Binding(
                get: { config.grantType },
                set: { var newConfig = config; newConfig.grantType = $0; onUpdate(newConfig) }
            )) {
                Text("Authorization Code").tag("authorization_code")
                Text("Client Credentials").tag("client_credentials")
                Text("Password").tag("password")
            }
            .pickerStyle(.segmented)

            TextField("Auth URL", text: Binding(
                get: { config.authUrl ?? "" },
                set: { var newConfig = config; newConfig.authUrl = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Access Token URL", text: Binding(
                get: { config.accessTokenUrl ?? "" },
                set: { var newConfig = config; newConfig.accessTokenUrl = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
            ))
            .textFieldStyle(.roundedBorder)

            HStack {
                TextField("Client ID", text: Binding(
                    get: { config.clientId ?? "" },
                    set: { var newConfig = config; newConfig.clientId = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
                ))
                .textFieldStyle(.roundedBorder)

                SecureField("Client Secret", text: Binding(
                    get: { config.clientSecret ?? "" },
                    set: { var newConfig = config; newConfig.clientSecret = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            TextField("Scope", text: Binding(
                get: { config.scope ?? "" },
                set: { var newConfig = config; newConfig.scope = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Redirect URI", text: Binding(
                get: { config.redirectUri ?? "" },
                set: { var newConfig = config; newConfig.redirectUri = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
            ))
            .textFieldStyle(.roundedBorder)

            if config.grantType == "password" {
                HStack {
                    TextField("Username", text: Binding(
                        get: { config.username ?? "" },
                        set: { var newConfig = config; newConfig.username = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
                    ))
                    .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: Binding(
                        get: { config.password ?? "" },
                        set: { var newConfig = config; newConfig.password = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                TextField("Token", text: Binding(
                    get: { config.token ?? "" },
                    set: { var newConfig = config; newConfig.token = $0.isEmpty ? nil : $0; onUpdate(newConfig) }
                ))
                .textFieldStyle(.roundedBorder)

                if config.grantType == "authorization_code" {
                    Button("Open Browser") {
                        openBrowser()
                    }
                    .buttonStyle(.bordered)
                }

                if config.grantType == "client_credentials" || config.grantType == "password" {
                    Button(isFetching ? "Fetching..." : "Get Token") {
                        fetchToken()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFetching)
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    private func openBrowser() {
        Task {
            let handler = OAuth2Handler()
            if let url = await handler.authorizationURL(config: config) {
                NSWorkspace.shared.open(url)
            } else {
                errorMessage = "Invalid auth URL"
            }
        }
    }

    private func fetchToken() {
        isFetching = true
        errorMessage = nil

        Task {
            let handler = OAuth2Handler()
            let result = await handler.fetchToken(config: config)
            isFetching = false

            switch result {
            case .success(let token):
                var newConfig = config
                newConfig.token = token
                onUpdate(newConfig)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
