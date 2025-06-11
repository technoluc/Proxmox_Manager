//
//  NetworkManager.swift
//  ProxManager
//

import Foundation
import Combine
import SwiftUI

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}

    // MARK: - Create URLRequest
    private func createRequest(endpoint: String, httpMethod: String, body: Data?) -> URLRequest? {
        Logger.shared.log("🛠 Creating request: \(httpMethod) \(endpoint)", level: .debug)
        let authHeaders = ProxmoxAuthManager.shared.authHeaders()
        Logger.shared.log("🔎 Auth Headers: \(authHeaders)", level: .debug)

        guard let baseURL = ProxmoxAuthManager.shared.baseURL,
              let rootURL = URL(string: baseURL) else {
            Logger.shared.log("❌ NetworkManager Error: Base URL not set or invalid.", level: .error)
            return nil
        }

        var cleanBaseURL = baseURL
        if cleanBaseURL.hasSuffix("/api2/json") {
            cleanBaseURL = String(cleanBaseURL.dropLast(10))
        }

        var cleanEndpoint = endpoint
        if cleanEndpoint.hasPrefix("/api2/json") {
            cleanEndpoint = String(cleanEndpoint.dropFirst(10))
        }

        let fullURLString = cleanBaseURL + "/api2/json" + (cleanEndpoint.hasPrefix("/") ? cleanEndpoint : "/\(cleanEndpoint)")
        guard let fullURL = URL(string: fullURLString) else {
            Logger.shared.log("❌ NetworkManager Error: Invalid URL - \(fullURLString)", level: .error)
            return nil
        }

        var request = URLRequest(url: fullURL)
        request.httpMethod = httpMethod
        request.httpBody = body

        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        // ✅ Inject CSRF token after request is defined
        if ["POST", "PUT", "DELETE"].contains(httpMethod.uppercased()),
           ProxmoxAuthManager.shared.getAuthMethod() == .ticketBased,
           let csrf = ProxmoxAuthManager.shared.getCSRFToken() {
            request.setValue(csrf, forHTTPHeaderField: "CSRFPreventionToken")
            Logger.shared.log("🛡 Injected CSRFPreventionToken for \(httpMethod): \(csrf)", level: .debug)
        }

        Logger.shared.log("🛠 Created request for \(httpMethod) \(fullURL)", level: .debug)
        return request
    }

    // MARK: - Perform Request (Decodable)
    func performRequest<T: Decodable>(
        endpoint: String,
        httpMethod: String = "GET",
        body: Data? = nil,
        retryOnAuthFailure: Bool = true,
        skipTicketCheck: Bool = false,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            if !skipTicketCheck {
                do {
                    try await ProxmoxAuthManager.shared.refreshAuthenticationIfNeeded()
                } catch {
                    Logger.shared.log("❌ Auth validation failed: \(error)", level: .error)
                    completion(.failure(NetworkError.unauthorized))
                    return
                }
            }

            guard let request = createRequest(endpoint: endpoint, httpMethod: httpMethod, body: body) else {
                Logger.shared.log("❌ Bad request for \(endpoint)", level: .error)
                completion(.failure(NetworkError.badResponse))
                return
            }

            Logger.shared.log("📡 Sending \(httpMethod) request to \(request.url!.absoluteString)")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    Logger.shared.log("❌ No HTTP response received", level: .error)
                    completion(.failure(NetworkError.badResponse))
                    return
                }

                Logger.shared.log("📥 Response Status Code: \(httpResponse.statusCode)", level: .debug)

                if httpResponse.statusCode == 401 && retryOnAuthFailure {
                    Logger.shared.log("🔁 401 Unauthorized - retrying after re-auth", level: .warning)

                    do {
                        try await ProxmoxAuthManager.shared.refreshAuthenticationIfNeeded()
                        performRequest(
                            endpoint: endpoint,
                            httpMethod: httpMethod,
                            body: body,
                            retryOnAuthFailure: false,
                            skipTicketCheck: false,
                            completion: completion
                        )
                        return
                    } catch {
                        Logger.shared.log("❌ Retry failed - auth still invalid: \(error)", level: .error)
                        completion(.failure(NetworkError.unauthorized))
                        return
                    }
                }

                Logger.shared.log("📦 Raw Response: \(String(data: data, encoding: .utf8) ?? "N/A")", level: .debug)

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    Logger.shared.log("✅ Decoded response successfully", level: .debug)
                    completion(.success(decoded))
                } catch {
                    Logger.shared.log("❌ Failed to decode: \(error)", level: .error)
                    completion(.failure(NetworkError.decodingFailed))
                }

            } catch {
                Logger.shared.log("❌ Request failed: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Perform Request (String)
    func performRequest(
        endpoint: String,
        httpMethod: String = "GET",
        body: Data? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        Task {
            do {
                try await ProxmoxAuthManager.shared.refreshAuthenticationIfNeeded()

                guard let request = createRequest(endpoint: endpoint, httpMethod: httpMethod, body: body) else {
                    Logger.shared.log("❌ Bad request for \(endpoint)", level: .error)
                    completion(.failure(NetworkError.badResponse))
                    return
                }

                Logger.shared.log("📡 Sending \(httpMethod) request to \(request.url!.absoluteString)", level: .debug)

                let (data, _) = try await URLSession.shared.data(for: request)
                guard let responseString = String(data: data, encoding: .utf8) else {
                    Logger.shared.log("❌ Failed to decode response as string", level: .error)
                    completion(.failure(NetworkError.decodingFailed))
                    return
                }

                completion(.success(responseString))
            } catch {
                Logger.shared.log("❌ performRequest Error: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Error Handling
    enum NetworkError: Error {
        case badResponse
        case noData
        case decodingFailed
        case unauthorized
    }
}

// MARK: - Helper Models
struct TaskResponse: Decodable {
    let data: String // e.g., UPID
}
