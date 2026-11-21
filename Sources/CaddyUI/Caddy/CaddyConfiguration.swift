import Foundation

enum CaddyConfiguration {
    static let port = 8080

    static func encode(targets: [ProxyTarget], adminSocket: URL) throws -> Data {
        let routes: [[String: Any]] = targets.map { target in
            [
                "match": [["host": [target.host]]],
                "handle": [["handler": "reverse_proxy", "upstreams": [["dial": target.upstream]]]],
                "terminal": true
            ]
        }
        let config: [String: Any] = [
            "admin": ["listen": "unix/\(adminSocket.path)", "config": ["persist": false]],
            "apps": [
                "http": [
                    "servers": [
                        "local": [
                            "listen": ["127.0.0.1:\(port)"],
                            "automatic_https": ["disable": true],
                            "routes": routes + [[
                                "handle": [["handler": "static_response", "status_code": 404]]
                            ]]
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: config)
    }
}
