//
//  ProxmoxNetworking.swift
//  ProxMan
//
//  Created by Luc Kurstjens on 15/02/2024.
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    private init() {} // Private constructor for singleton pattern

    // Updated performRequest to handle generic Decodable and String responses
    func performRequest<T: Decodable>(endpoint: String, apiAddress: String?, apiID: String?, apiKey: String?, useHTTPS: Bool, httpMethod: String, completion: @escaping (Result<T, Error>) -> Void) {
        performRequestInternal(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: httpMethod) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    
    
    // Overloaded function for handling String responses
    func performRequest(endpoint: String, apiAddress: String?, apiID: String?, apiKey: String?, useHTTPS: Bool, httpMethod: String, completion: @escaping (Result<String, Error>) -> Void) {
        performRequestInternal(endpoint: endpoint, apiAddress: apiAddress, apiID: apiID, apiKey: apiKey, useHTTPS: useHTTPS, httpMethod: httpMethod) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    private func performRequestInternal<T>(endpoint: String, apiAddress: String?, apiID: String?, apiKey: String?, useHTTPS: Bool, httpMethod: String, completion: @escaping (Result<T, Error>) -> Void) where T: Decodable {
        guard let apiAddress = apiAddress, let apiID = apiID, let apiKey = apiKey, !apiAddress.isEmpty, !apiID.isEmpty, !apiKey.isEmpty else {
            print("NetworkManager Error: Missing configuration")
            completion(.failure(NetworkError.missingConfiguration))
            return
        }

        let protocolString = useHTTPS ? "https" : "http"
        let urlString = "\(protocolString)://\(apiAddress)\(endpoint)"
        print("NetworkManager: Network Request URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("NetworkManager Error: Invalid URL - \(urlString)")
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.addValue("PVEAPIToken=\(apiID)=\(apiKey)", forHTTPHeaderField: "Authorization")

        print("NetworkManager: Making network request to endpoint: \(endpoint), Method: \(httpMethod)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("NetworkManager Error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let httpRes = response as? HTTPURLResponse else {
                    print("NetworkManager Error: Invalid response type")
                    completion(.failure(NetworkError.badResponse))
                    return
                }

                print("NetworkManager: HTTP Response Status Code: \(httpRes.statusCode)")
                if !(200...299).contains(httpRes.statusCode) {
                    print("NetworkManager Error: Bad response - Status code \(httpRes.statusCode)")
                    completion(.failure(NetworkError.badResponse))
                    return
                }

                guard let data = data else {
                    print("NetworkManager Error: No data received")
                    completion(.failure(NetworkError.noData))
                    return
                }

                // Logging the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("NetworkManager: Raw Response Data: \(responseString)")
                }

                if T.self == String.self {
                    if let responseString = String(data: data, encoding: .utf8) {
                        completion(.success(responseString as! T))
                    } else {
                        print("NetworkManager Error: Failed to decode response as string")
                        completion(.failure(NetworkError.decodingFailed))
                    }
                } else {
                    do {
                        let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                        completion(.success(decodedResponse))
                    } catch {
                        print("NetworkManager Error: Failed to decode response - \(error)")
                        // Log the raw JSON that failed to decode
                        if let rawJSON = String(data: data, encoding: .utf8) {
                            print("NetworkManager: Failing JSON Data: \(rawJSON)")
                        }
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }

    enum NetworkError: Error {
        case missingConfiguration
        case invalidURL
        case badResponse
        case noData
        case decodingFailed
    }
}
