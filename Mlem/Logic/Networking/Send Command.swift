//
//  Send Command.swift
//  Mlem
//
//  Created by David Bureš on 03.05.2023.
//

import Foundation
import SwiftyJSON

enum ConnectionError: Error
{
    case failedToEncodeAddress, receivedInvalidResponseFormat, failedToSendRequest
}
internal enum EncodingFailure: Error
{
    case failedToConvertURLToComponents, failedToSendRequest, failedToEncodeJSON
}

func sendGetCommand(account: SavedAccount, endpoint: String, parameters: [URLQueryItem]) async throws -> String
{
    var finalURL: URL = account.instanceLink.appendingPathComponent(endpoint, conformingTo: .url)
    var finalParameters: [URLQueryItem] = parameters
    
    guard var urlComponents = URLComponents(url: finalURL, resolvingAgainstBaseURL: true) else
    {
        throw EncodingFailure.failedToConvertURLToComponents
    }
    
    finalParameters.append(URLQueryItem(name: "auth", value: account.accessToken))
    
    urlComponents.queryItems = finalParameters
    
    finalURL = urlComponents.url!
    
    print("Final URL: \(finalURL)")
    
    var request: URLRequest = URLRequest(url: finalURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
    request.httpMethod = "GET"
    
    do
    {
        let (data, response) = try await AppConstants.urlSession.data(for: request)
        
        let httpResponse: HTTPURLResponse = response as! HTTPURLResponse
        
        print("Received response code \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200
        {
            throw ConnectionError.receivedInvalidResponseFormat
        }
        
        return String(decoding: data, as: UTF8.self)
    }
    catch let requestError
    {
        print("Failed while sending GET request: \(requestError)")
        throw ConnectionError.failedToSendRequest
    }
}

func sendPostCommand(account: SavedAccount, endpoint: String, body: String) async throws -> String
{
    var finalURL: URL = account.instanceLink.appendingPathComponent(endpoint, conformingTo: .url)
    
    var request: URLRequest = URLRequest(url: finalURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
    request.httpMethod = "POST"
    
    do
    {
        let jsonData = try JSONSerialization.jsonObject(with: body.data(using: .utf8, allowLossyConversion: false)!) as! Data
        
        request.httpBody = jsonData
        
        do
        {
            let (data, response) = try await AppConstants.urlSession.data(for: request)
            
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse
            
            print("Received response code \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200
            {
                throw ConnectionError.receivedInvalidResponseFormat
            }
            
            return String(decoding: data, as: UTF8.self)
        }
        catch let requestError
        {
            print("Failed while sending POST request: \(requestError)")
            throw ConnectionError.failedToSendRequest
        }
    }
    catch let encodingError
    {
        print("Failed while encoding JSON string to data: \(encodingError)")
        throw EncodingFailure.failedToEncodeJSON
    }
}

func sendCommand(maintainOpenConnection: Bool, instanceAddress: URL, command: String) async throws -> String
{
    print("Instance address: \(instanceAddress)")
    print("Will send command \(command)")
    
    let session = URLSession(configuration: .default)

    let task: URLSessionWebSocketTask = session.webSocketTask(with: instanceAddress)

    let finalCommand = URLSessionWebSocketTask.Message.string(command)
    
    task.maximumMessageSize = 1048576 * 2 // temporarily increased in lieu of REST migration
    task.resume()
    
    try await task.send(finalCommand)
    
    let response = try await task.receive()
    
    switch response
    {
        case let .string(responseString):
            print("Received a valid string")
            
            if !maintainOpenConnection
            {
                task.cancel(with: .goingAway, reason: nil)
            }
            return responseString
            
        case let .data(responseData):
            print("Received this data: \(responseData)")
            task.cancel(with: .policyViolation, reason: nil)
            throw ConnectionError.receivedInvalidResponseFormat
            
        @unknown default:
            print("Unknown response received")
            task.cancel(with: .policyViolation, reason: nil)
            throw ConnectionError.receivedInvalidResponseFormat
    }
}
