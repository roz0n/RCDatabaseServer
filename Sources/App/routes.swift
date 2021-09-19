import Vapor
import Foundation
import RediStack

/**
 
 The following is a routes file for a Vapor server that exposes two routes, "get" and "set", both of which accept query params.
 
 The "get" route returns the value of a given key if it exists, while the "set" route stores each key/value pair in a Redis cache.
 As per Vapor's conventions, the Redis configuration exists in the `Sources/App/Controllers/configure.swift` file which is not included in this Gist.
 
 */

// MARK: - Response Models

struct SetRouteResponse: Content {
  var success: Bool
}

struct GetRouteResponse: Content {
  var success: Bool
  var value: String?
}

// MARK: - Query Param Models

struct SetRouteQueryParams: Content, RESPValueConvertible {
  var somekey: String
  
  init?(fromRESP value: RESPValue) {
    self.somekey = value.string!
  }
  
  func convertedToRESPValue() -> RESPValue {
    .simpleString(ByteBuffer(bytes: self.somekey.utf8))
  }
}

struct GetRouterQueryParams: Content {
  var key: String
}

// MARK: - Routes

func routes(_ app: Application) throws {
  
  app.get("set") { req -> SetRouteResponse in
    // Get key (could use regex?)
    let route = req.url.string
    let start = route.firstIndex(of: "?")
    let end = route.firstIndex(of: "=")
    
    guard let start = start, let end = end else {
      throw Abort(.custom(code: 500, reasonPhrase: "Failed to parse query"))
    }
    
    let startIndex = route.index(start, offsetBy: 1)
    let endIndex = route.index(end, offsetBy: -1)
    let key = String(route[startIndex...endIndex])
    
    // Store key
    let _ = app.redis.set(RedisKey(key), to: "test")
    
    return SetRouteResponse(success: true)
  }
  
//  app.get("set") { req -> SetRouteResponse in
//    let params = try req.query.decode(SetRouteQueryParams.self)
//    let convertedParams = params.convertedToRESPValue()
//    let _ = app.redis.set("somekey", to: convertedParams.string)
//
//    return SetRouteResponse(success: true)
//  }
  
  app.get("get") { req -> EventLoopFuture<GetRouteResponse> in
    let params = try req.query.decode(GetRouterQueryParams.self)
    let key = RedisKey(stringLiteral: params.key)
    let promise = req.eventLoop.makePromise(of: GetRouteResponse.self)
        
    DispatchQueue.global().async {
      do {
        guard let value = try app.redis.get(key, as: String.self).wait() else {
          throw Abort(.notFound)
        }
        
        let response = GetRouteResponse(success: true, value: value)
        promise.succeed(response)
      } catch let error {
        promise.fail(error)
      }
    }
    
    return promise.futureResult
  }
  
}
