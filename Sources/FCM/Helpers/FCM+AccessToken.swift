import Foundation
import Vapor

extension FCM {
    func getAccessToken(_ client: Client) throws -> Future<String> {
        if !gAuthPayload.hasExpired, let token = accessToken {
            return client.container.eventLoop.newSucceededFuture(result: token)
        }
        var payload: [String: String] = [:]
        payload["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        payload["assertion"] = try getJWT()
        return client.post(audience) { req throws in
            try req.content.encode(payload, as: .urlEncodedForm)
        }.map { res in
            struct Result: Codable {
                var access_token: String
            }
            guard let data = res.http.body.data else {
                throw Abort(.notFound, reason: "Data not found")
            }
            if res.http.status.code != 200 {
                let code = "Code: \(res.http.status.code)"
                let message = "Message: \(String(data: data, encoding: .utf8) ?? "n/a")"
                let reason = "[FCM] Unable to refresh access token. \(code) \(message)"
                throw Abort(.internalServerError, reason: reason)
            }
            let result = try JSONDecoder().decode(Result.self, from: data)
            return result.access_token
        }
    }
}
