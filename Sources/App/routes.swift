import Vapor
import RediStack

/**
 
 The following is a routes file for a Vapor server that exposes two routes, "get" and "set", both of which accept query params.
 
 The "get" route returns the value of a given key if it exists, while the "set" route stores each provided key/value pair in a Redis cache.
 As per Vapor's conventions, the Redis configuration exists in the `Sources/App/Controllers/configure.swift` file which is not included in this Gist.
 
 */

// MARK: - Response Models

struct SetRouteResponse: Content {
  var success: Bool
}

struct GetRouteResponse: Content {
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
    let url = URL(string: req.url.string)
    let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
    
    guard let components = components, let queryItems = components.queryItems else {
      throw Abort(.custom(code: 500, reasonPhrase: "Failed to parse query params from route"))
    }
    
    for item in queryItems {
      _ = app.redis.set(RedisKey(item.name), to: item.value)
    }

    return SetRouteResponse(success: true)
  }
  
  app.get("get") { req -> EventLoopFuture<GetRouteResponse> in
    let params = try req.query.decode(GetRouterQueryParams.self)
    let key = RedisKey(stringLiteral: params.key)
    let promise = req.eventLoop.makePromise(of: GetRouteResponse.self)
        
    DispatchQueue.global().async {
      do {
        guard let value = try app.redis.get(key, as: String.self).wait() else {
          throw Abort(.notFound)
        }
        
        let response = GetRouteResponse(value: value)
        promise.succeed(response)
      } catch let error {
        promise.fail(error)
      }
    }
    
    return promise.futureResult
  }
  
}
