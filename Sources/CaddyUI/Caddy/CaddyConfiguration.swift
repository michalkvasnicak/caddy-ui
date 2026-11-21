import Foundation

enum CaddyConfiguration {
    static let port = 8443

    static func address(for host: String) -> String {
        "https://\(host):\(port)"
    }

    static func encode(targets: [ProxyTarget], adminSocket: URL) throws -> Data {
        let routes: [[String: Any]] = targets.map { target in
            [
                "match": [["host": [target.host]]],
                "handle": [["handler": "reverse_proxy", "upstreams": [["dial": target.upstream]]]],
                "terminal": true
            ]
        }
        let storagePath = adminSocket.deletingLastPathComponent().appendingPathComponent("tls").path
        let config: [String: Any] = [
            "storage": ["module": "file_system", "root": storagePath],
            "admin": ["listen": "unix/\(adminSocket.path)", "config": ["persist": false]],
            "apps": [
                "pki": ["certificate_authorities": ["local": ["install_trust": false]]],
                "tls": ["automation": ["policies": [["issuers": [["module": "internal"]]]]]],
                "http": [
                    "https_port": port,
                    "servers": [
                        "local": [
                            "listen": ["127.0.0.1:\(port)"],
                            "automatic_https": ["disable_redirects": true],
                            "tls_connection_policies": [[String: Any]()],
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
