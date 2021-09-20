import Vapor
import RediStack

/**
 
  The following is a routes file for a Vapor server that exposes two routes, "get" and "set", both of which accept any number of query parameters.

  The "get" route returns the value of given keys if they exist, while the "set" route stores all given key/value pairs in a Redis cache.
  As per Vapor's conventions, the Redis configuration exists in the `Sources/App/Controllers/configure.swift` file which is not included in this Gist.
 
 */

// MARK: - Response Models

struct SetRouteResponse: Content {
  var success: Bool
}

struct GetRouteResponse: Content {
  var key: String
  var value: String
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
      throw Abort(.custom(code: 500, reasonPhrase: "Failed to parse query params"))
    }
    
    for item in queryItems {
      _ = app.redis.set(RedisKey(item.name), to: item.value)
    }
    
    return SetRouteResponse(success: true)
  }
  
  struct Get2RouteResponse: Content {
    var value: [String]?
  }
  
  app.get("get") { req -> EventLoopFuture<[GetRouteResponse]> in
    let keys = ["somekey", "name", "aaa", "num"]
    let promise = req.eventLoop.makePromise(of: [GetRouteResponse].self)
    
    DispatchQueue.global().async {
      var responseData = [GetRouteResponse]()
      
      for key in keys {
        let value = try? app.redis.get(RedisKey(key), as: String.self).wait()
        
        if let value = value {
          responseData.append(GetRouteResponse(key: key, value: value))
        }
      }
      
      if !responseData.isEmpty {
        promise.succeed(responseData)
      } else {
        promise.fail(Abort(.notFound))
      }
    }
    
    return promise.futureResult
  }
  
}
