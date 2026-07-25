import Foundation
import APISignalsCore

public actor URLSessionNetworkEngine: NetworkEngine {
    private let defaultSession: URLSession
    private let builder: RequestBuilder
    private var activeTasks: [UUID: URLSessionDataTask] = [:]

    public init(session: URLSession = .shared, builder: RequestBuilder = RequestBuilder()) {
        self.defaultSession = session
        self.builder = builder
    }

    private func session(for settings: RequestSettings) -> URLSession {
        if let proxy = settings.proxy, proxy.isEnabled, !proxy.host.isEmpty {
            let config = URLSessionConfiguration.default
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: proxy.host,
                kCFNetworkProxiesHTTPPort: proxy.port,
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: proxy.host,
                kCFNetworkProxiesHTTPSPort: proxy.port
            ]
            return URLSession(configuration: config)
        }
        return defaultSession
    }

    public func execute(_ request: APIRequest, environment: Environment?) async -> RequestResult {
        let buildResult = await builder.buildURLRequest(from: request, environment: environment)

        let urlRequest: URLRequest
        switch buildResult {
        case .success(let value):
            urlRequest = value
        case .failure(let error):
            return .failure(error)
        }

        let startTime = Date()
        let requestId = request.id
        let activeSession = session(for: request.settings)

        return await withCheckedContinuation { continuation in
            let task = activeSession.dataTask(with: urlRequest) { [weak self] data, response, error in
                let totalTime = Date().timeIntervalSince(startTime)
                let requestUrl = urlRequest.url

                Task { [weak self] in
                    await self?.removeTask(requestId)

                    if let error = error as NSError? {
                        let requestError = URLSessionNetworkEngine.mapError(error)
                        continuation.resume(returning: .failure(requestError))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(returning: .failure(.unknown("Invalid response")))
                        return
                    }

                    var cookies: [Cookie] = []
                    if let url = requestUrl {
                        await CookieJar.shared.setCookies(from: httpResponse, url: url)
                        cookies = await CookieJar.shared.cookies(for: url)
                    }

                    let apiResponse = URLSessionNetworkEngine.mapResponse(
                        httpResponse: httpResponse,
                        data: data,
                        totalTime: totalTime,
                        cookies: cookies
                    )

                    continuation.resume(returning: .success(apiResponse))
                }
            }

            activeTasks[requestId] = task
            task.resume()
        }
    }

    public func cancel(requestId: UUID) {
        activeTasks[requestId]?.cancel()
        activeTasks.removeValue(forKey: requestId)
    }

    private func addTask(_ id: UUID, _ task: URLSessionDataTask) {
        activeTasks[id] = task
    }

    private func removeTask(_ id: UUID) {
        activeTasks.removeValue(forKey: id)
    }

    private static func mapResponse(httpResponse: HTTPURLResponse, data: Data?, totalTime: TimeInterval, cookies: [Cookie] = []) -> APIResponse {
        let headers = httpResponse.allHeaderFields.compactMap { key, value -> Header? in
            guard let keyString = key as? String, let valueString = value as? String else {
                return nil
            }
            return Header(key: keyString, value: valueString)
        }

        let body = data
        let bodySize = body?.count ?? 0
        let headerSize = headers.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count + 4 }

        return APIResponse(
            statusCode: httpResponse.statusCode,
            statusText: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            headers: headers,
            body: body,
            mimeType: httpResponse.mimeType,
            timing: RequestTiming(total: totalTime),
            size: ResponseSize(headers: headerSize, body: bodySize, total: headerSize + bodySize),
            cookies: cookies
        )
    }

    private static func mapError(_ error: NSError) -> RequestError {
        switch error.code {
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorCancelled:
            return .cancelled
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost:
            return .network(error.localizedDescription)
        case NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected:
            return .ssl(error.localizedDescription)
        default:
            return .network(error.localizedDescription)
        }
    }
}
