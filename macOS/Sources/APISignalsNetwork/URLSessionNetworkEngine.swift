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

        let requestId = request.id
        let activeSession = session(for: request.settings)
        let delegate = MetricsDelegate()
        let metricsSession = URLSession(
            configuration: activeSession.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        return await withCheckedContinuation { continuation in
            let task = metricsSession.dataTask(with: urlRequest) { [weak self] data, response, error in
                let requestUrl = urlRequest.url

                Task { [weak self] in
                    await self?.removeTask(requestId)
                    let metrics = await delegate.collectedMetrics

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

                    let timing = URLSessionNetworkEngine.extractTiming(from: metrics)
                    let apiResponse = URLSessionNetworkEngine.mapResponse(
                        httpResponse: httpResponse,
                        data: data,
                        timing: timing,
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

    private func removeTask(_ id: UUID) {
        activeTasks.removeValue(forKey: id)
    }

    private static func extractTiming(from metrics: URLSessionTaskMetrics?) -> RequestTiming {
        guard let metrics = metrics,
              let tx = metrics.transactionMetrics.last else {
            return RequestTiming(total: 0)
        }

        let total = metrics.taskInterval.duration

        var dns: TimeInterval? = nil
        if let start = tx.domainLookupStartDate, let end = tx.domainLookupEndDate {
            dns = end.timeIntervalSince(start)
        }

        var connect: TimeInterval? = nil
        if let start = tx.connectStartDate, let end = tx.connectEndDate {
            connect = end.timeIntervalSince(start)
        }

        var tls: TimeInterval? = nil
        if let start = tx.secureConnectionStartDate, let end = tx.secureConnectionEndDate {
            tls = end.timeIntervalSince(start)
        }

        var ttfb: TimeInterval = 0
        if let start = tx.requestStartDate, let end = tx.responseStartDate {
            ttfb = max(0, end.timeIntervalSince(start))
        }

        var download: TimeInterval = 0
        if let start = tx.responseStartDate, let end = tx.responseEndDate {
            download = max(0, end.timeIntervalSince(start))
        }

        return RequestTiming(dns: dns, connect: connect, tls: tls, ttfb: ttfb, download: download, total: total)
    }

    private static func mapResponse(httpResponse: HTTPURLResponse, data: Data?, timing: RequestTiming, cookies: [Cookie] = []) -> APIResponse {
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
            timing: timing,
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

// MARK: - Metrics delegate

private final class MetricsDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private var metrics: URLSessionTaskMetrics?
    private let lock = NSLock()

    var collectedMetrics: URLSessionTaskMetrics? {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        self.metrics = metrics
        lock.unlock()
    }
}
