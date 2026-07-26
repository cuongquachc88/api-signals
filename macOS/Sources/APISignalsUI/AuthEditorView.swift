import SwiftUI
import AppKit
import APISignalsCore
import APISignalsNetwork

// MARK: - Auth Editor

struct AuthEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Type picker header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsTextSec)
                Text("Auth Type")
                    .font(DS.Font.label)
                    .foregroundStyle(Color.dsTextSec)
                Spacer()
                Picker("", selection: authTypeBinding) {
                    ForEach(AuthType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.dsSurf)

            DSDivider()

            // Auth content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    authContent
                }
                .padding(DS.Spacing.lg)
            }
            .background(Color.dsBg)
        }
    }

    @ViewBuilder
    private var authContent: some View {
        switch viewModel.request.auth {
        case .none:
            noneView

        case .bearer(let token):
            authSection("Bearer Token", icon: "key.horizontal") {
                authField("Token", placeholder: "Enter token…", isSecret: true, value: Binding(
                    get: { token },
                    set: { viewModel.request.auth = .bearer(token: $0); viewModel.updateRequest() }
                ))
            } hint: {
                "Token will be sent as: Authorization: Bearer <token>"
            }

        case .basic(let username, let password):
            authSection("Basic Authentication", icon: "person.badge.key") {
                authField("Username", placeholder: "username", value: Binding(
                    get: { username },
                    set: { viewModel.request.auth = .basic(username: $0, password: password); viewModel.updateRequest() }
                ))
                authField("Password", placeholder: "password", isSecret: true, value: Binding(
                    get: { password },
                    set: { viewModel.request.auth = .basic(username: username, password: $0); viewModel.updateRequest() }
                ))
            } hint: {
                "Credentials are Base64-encoded and sent as: Authorization: Basic <encoded>"
            }

        case .apiKey(let key, let value, let location):
            authSection("API Key", icon: "key") {
                authField("Key", placeholder: "X-API-Key", value: Binding(
                    get: { key },
                    set: { viewModel.request.auth = .apiKey(key: $0, value: value, location: location); viewModel.updateRequest() }
                ))
                authField("Value", placeholder: "your-api-key", isSecret: true, value: Binding(
                    get: { value },
                    set: { viewModel.request.auth = .apiKey(key: key, value: $0, location: location); viewModel.updateRequest() }
                ))
                HStack(spacing: DS.Spacing.sm) {
                    Text("Add to")
                        .font(DS.Font.body)
                        .foregroundStyle(Color.dsTextSec)
                        .frame(width: 100, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { location },
                        set: { viewModel.request.auth = .apiKey(key: key, value: value, location: $0); viewModel.updateRequest() }
                    )) {
                        Text("Header").tag(APIKeyLocation.header)
                        Text("Query Params").tag(APIKeyLocation.query)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }

        case .oauth1(let config):
            authSection("OAuth 1.0", icon: "arrow.triangle.2.circlepath.circle") {
                OAuth1EditorDS(config: config, onUpdate: { newConfig in
                    viewModel.request.auth = .oauth1(newConfig)
                    viewModel.updateRequest()
                })
            }

        case .oauth2(let config):
            authSection("OAuth 2.0", icon: "arrow.triangle.2.circlepath.circle.fill") {
                OAuth2EditorDS(config: config, onUpdate: { newConfig in
                    viewModel.request.auth = .oauth2(newConfig)
                    viewModel.updateRequest()
                })
            }

        case .digest(let username, let password):
            authSection("Digest Authentication", icon: "person.badge.shield.checkmark") {
                authField("Username", placeholder: "username", value: Binding(
                    get: { username },
                    set: { viewModel.request.auth = .digest(username: $0, password: password); viewModel.updateRequest() }
                ))
                authField("Password", placeholder: "password", isSecret: true, value: Binding(
                    get: { password },
                    set: { viewModel.request.auth = .digest(username: username, password: $0); viewModel.updateRequest() }
                ))
            } hint: {
                "The client will respond to server's WWW-Authenticate challenge with a digest hash."
            }

        case .ntlm(let username, let password, let domain):
            authSection("NTLM Authentication", icon: "building.2") {
                authField("Username", placeholder: "username", value: Binding(
                    get: { username },
                    set: { viewModel.request.auth = .ntlm(username: $0, password: password, domain: domain); viewModel.updateRequest() }
                ))
                authField("Password", placeholder: "password", isSecret: true, value: Binding(
                    get: { password },
                    set: { viewModel.request.auth = .ntlm(username: username, password: $0, domain: domain); viewModel.updateRequest() }
                ))
                authField("Domain", placeholder: "CORP (optional)", value: Binding(
                    get: { domain ?? "" },
                    set: { viewModel.request.auth = .ntlm(username: username, password: password, domain: $0.isEmpty ? nil : $0); viewModel.updateRequest() }
                ))
            } hint: {
                "NTLM challenge-response authentication handled by URLSession."
            }

        case .awsSignature(let config):
            authSection("AWS Signature V4", icon: "cloud.bolt") {
                AWSSignatureEditorDS(config: config, onUpdate: { newConfig in
                    viewModel.request.auth = .awsSignature(newConfig)
                    viewModel.updateRequest()
                })
            } hint: {
                "Requests are signed with AWS Signature Version 4 automatically."
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private var noneView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "lock.open")
                .font(.system(size: 32))
                .foregroundStyle(Color.dsTextTertiary)
            Text("No Authentication")
                .font(DS.Font.title)
                .foregroundStyle(Color.dsTextPrim)
            Text("Select an auth type above to configure credentials")
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    @ViewBuilder
    private func authSection<Content: View>(_ title: String, icon: String, @ViewBuilder fields: () -> Content, hint: (() -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsAcc)
                Text(title)
                    .font(DS.Font.labelLg)
                    .foregroundStyle(Color.dsTextPrim)
            }

            VStack(spacing: 0) {
                fields()
            }
            .background(Color.dsSurf)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.dsBord, lineWidth: 1)
            )

            if let hint = hint?() {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dsTextTertiary)
                    Text(hint)
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func authField(_ label: String, placeholder: String, isSecret: Bool = false, value: Binding<String>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .frame(width: 100, alignment: .leading)
            if isSecret {
                SecureField(placeholder, text: value)
                    .textFieldStyle(.plain)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
            } else {
                TextField(placeholder, text: value)
                    .textFieldStyle(.plain)
                    .font(DS.Font.bodyMono)
                    .foregroundStyle(Color.dsTextPrim)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
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
                case .none: viewModel.request.auth = .none
                case .bearer: viewModel.request.auth = .bearer(token: "")
                case .basic: viewModel.request.auth = .basic(username: "", password: "")
                case .apiKey: viewModel.request.auth = .apiKey(key: "", value: "", location: .header)
                case .oauth1: viewModel.request.auth = .oauth1(OAuth1Config())
                case .oauth2: viewModel.request.auth = .oauth2(OAuth2Config())
                case .digest: viewModel.request.auth = .digest(username: "", password: "")
                case .ntlm: viewModel.request.auth = .ntlm(username: "", password: "", domain: nil)
                case .awsSignature: viewModel.request.auth = .awsSignature(AWSSignatureConfig(accessKey: "", secretKey: "", region: "us-east-1", service: "execute-api"))
                }
                viewModel.updateRequest()
            }
        )
    }
}

// MARK: - AWS Signature Editor

struct AWSSignatureEditorDS: View {
    let config: AWSSignatureConfig
    let onUpdate: (AWSSignatureConfig) -> Void

    var body: some View {
        VStack(spacing: 0) {
            field("Access Key", placeholder: "AKIAIOSFODNN7EXAMPLE", value: Binding(
                get: { config.accessKey },
                set: { var c = config; c.accessKey = $0; onUpdate(c) }
            ))
            DSDivider()
            secureField("Secret Key", placeholder: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", value: Binding(
                get: { config.secretKey },
                set: { var c = config; c.secretKey = $0; onUpdate(c) }
            ))
            DSDivider()
            field("Region", placeholder: "us-east-1", value: Binding(
                get: { config.region },
                set: { var c = config; c.region = $0; onUpdate(c) }
            ))
            DSDivider()
            field("Service", placeholder: "execute-api", value: Binding(
                get: { config.service },
                set: { var c = config; c.service = $0; onUpdate(c) }
            ))
        }
    }

    private func field(_ label: String, placeholder: String, value: Binding<String>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .frame(width: 100, alignment: .leading)
            TextField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func secureField(_ label: String, placeholder: String, value: Binding<String>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.body)
                .foregroundStyle(Color.dsTextSec)
                .frame(width: 100, alignment: .leading)
            SecureField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - OAuth1 Editor

struct OAuth1EditorDS: View {
    let config: OAuth1Config
    let onUpdate: (OAuth1Config) -> Void

    var body: some View {
        VStack(spacing: 0) {
            row("Consumer Key", value: Binding(
                get: { config.consumerKey },
                set: { var c = config; c.consumerKey = $0; onUpdate(c) }
            ))
            DSDivider()
            secureRow("Consumer Secret", value: Binding(
                get: { config.consumerSecret },
                set: { var c = config; c.consumerSecret = $0; onUpdate(c) }
            ))
            DSDivider()
            row("Access Token", value: Binding(
                get: { config.token },
                set: { var c = config; c.token = $0; onUpdate(c) }
            ))
            DSDivider()
            secureRow("Token Secret", value: Binding(
                get: { config.tokenSecret },
                set: { var c = config; c.tokenSecret = $0; onUpdate(c) }
            ))
            DSDivider()
            HStack(spacing: DS.Spacing.sm) {
                Text("Signature")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: Binding(
                    get: { config.signatureMethod },
                    set: { var c = config; c.signatureMethod = $0; onUpdate(c) }
                )) {
                    Text("HMAC-SHA1").tag("HMAC-SHA1")
                    Text("PLAINTEXT").tag("PLAINTEXT")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func row(_ label: String, value: Binding<String>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label).font(DS.Font.body).foregroundStyle(Color.dsTextSec).frame(width: 100, alignment: .leading)
            TextField("", text: value).textFieldStyle(.plain).font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
    }

    private func secureRow(_ label: String, value: Binding<String>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label).font(DS.Font.body).foregroundStyle(Color.dsTextSec).frame(width: 100, alignment: .leading)
            SecureField("", text: value).textFieldStyle(.plain).font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - OAuth2 Editor

struct OAuth2EditorDS: View {
    let config: OAuth2Config
    let onUpdate: (OAuth2Config) -> Void
    @State private var isFetching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Text("Grant Type")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                    .frame(width: 100, alignment: .leading)
                Picker("", selection: Binding(
                    get: { config.grantType },
                    set: { var c = config; c.grantType = $0; onUpdate(c) }
                )) {
                    Text("Auth Code").tag("authorization_code")
                    Text("Client Creds").tag("client_credentials")
                    Text("Password").tag("password")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            DSDivider()
            urlRow("Auth URL", key: \.authUrl)
            DSDivider()
            urlRow("Token URL", key: \.accessTokenUrl)
            DSDivider()
            textRow("Client ID", key: \.clientId)
            DSDivider()
            secureOptionalRow("Client Secret", key: \.clientSecret)
            DSDivider()
            textRow("Scope", key: \.scope)
            DSDivider()
            textRow("Redirect URI", key: \.redirectUri)

            if config.grantType == "password" {
                DSDivider()
                textRow("Username", key: \.username)
                DSDivider()
                secureOptionalRow("Password", key: \.password)
            }

            DSDivider()
            HStack(spacing: DS.Spacing.sm) {
                Text("Token")
                    .font(DS.Font.body)
                    .foregroundStyle(Color.dsTextSec)
                    .frame(width: 100, alignment: .leading)
                TextField("access_token…", text: Binding(
                    get: { config.token ?? "" },
                    set: { var c = config; c.token = $0.isEmpty ? nil : $0; onUpdate(c) }
                ))
                .textFieldStyle(.plain)
                .font(DS.Font.bodyMono)
                .foregroundStyle(Color.dsAcc)

                if config.grantType == "authorization_code" {
                    Button("Open Browser") { openBrowser() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Button(isFetching ? "Fetching…" : "Get Token") { fetchToken() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isFetching)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            if let err = errorMessage {
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(Color.dsError)
                    Text(err)
                        .font(DS.Font.caption)
                        .foregroundStyle(Color.dsError)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private func urlRow(_ label: String, key: WritableKeyPath<OAuth2Config, String?>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label).font(DS.Font.body).foregroundStyle(Color.dsTextSec).frame(width: 100, alignment: .leading)
            TextField("https://…", text: Binding(
                get: { config[keyPath: key] ?? "" },
                set: { var c = config; c[keyPath: key] = $0.isEmpty ? nil : $0; onUpdate(c) }
            )).textFieldStyle(.plain).font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
    }

    private func textRow(_ label: String, key: WritableKeyPath<OAuth2Config, String?>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label).font(DS.Font.body).foregroundStyle(Color.dsTextSec).frame(width: 100, alignment: .leading)
            TextField("", text: Binding(
                get: { config[keyPath: key] ?? "" },
                set: { var c = config; c[keyPath: key] = $0.isEmpty ? nil : $0; onUpdate(c) }
            )).textFieldStyle(.plain).font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
    }

    private func secureOptionalRow(_ label: String, key: WritableKeyPath<OAuth2Config, String?>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label).font(DS.Font.body).foregroundStyle(Color.dsTextSec).frame(width: 100, alignment: .leading)
            SecureField("", text: Binding(
                get: { config[keyPath: key] ?? "" },
                set: { var c = config; c[keyPath: key] = $0.isEmpty ? nil : $0; onUpdate(c) }
            )).textFieldStyle(.plain).font(DS.Font.bodyMono).foregroundStyle(Color.dsTextPrim)
        }
        .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
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
                var c = config; c.token = token; onUpdate(c)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Kept for backward compat (used by existing code)

typealias AWSSignatureEditor = AWSSignatureEditorDS
typealias OAuth1Editor = OAuth1EditorDS
typealias OAuth2Editor = OAuth2EditorDS
