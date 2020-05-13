//
//  HttpServer.swift
//  GoldenPassport
//
//  Created by StanZhai on 2017/3/4.
//  Copyright © 2017年 StanZhai. All rights reserved.
//

import Foundation
import Swifter

public func httpServer() -> HttpServer {
    let server = HttpServer()
    server.listenAddressIPv4 = "127.0.0.1"
    
    server["/"] = scopes {
        html {
            body {
                h3 { inner = "Verification code list:" }
                
                ul(DataManager.shared.allAuthCode()) { code in
                    li {
                        a { href = "/code/\(code.key)"; inner = "\(code.key) -> \(code.value)" }
                    }
                }
            }
        }
    }
    
    server["/code/:key"] = { r in
        let key = r.params[":key"]
        let allCodes = DataManager.shared.allAuthCode()
        if let code = allCodes.first(where: { (c) -> Bool in
            return c.key == key
            })?.value {
            return HttpResponse.ok(.text(code))
        } else {
            return HttpResponse.ok(.text("key does not exists!"))
        }
    }
    
    return server
}
