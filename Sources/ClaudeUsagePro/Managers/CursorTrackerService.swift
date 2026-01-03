import Foundation
import SQLite3

struct CursorAuthData {
    let accessToken: String?
    let email: String?
    let membershipType: String?
}

struct CursorUsageInfo {
    let email: String?
    let planUsed: Int
    let planLimit: Int
    let planRemaining: Int
    let planType: String?
}

class CursorTrackerService {
    private let cursorAPIBase = "https://api2.cursor.sh"
    private let stateDBPath = "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    
    func isInstalled() -> Bool {
        let path = NSString(string: "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb").expandingTildeInPath
        return FileManager.default.fileExists(atPath: path)
    }
    
    func fetchCursorUsage(completion: @escaping (Result<CursorUsageInfo, Error>) -> Void) {
        guard let auth = readAuthFromStateDB(), let token = auth.accessToken else {
            completion(.failure(NSError(domain: "CursorTracker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cursor auth not found"])))
            return
        }
        
        guard let url = URL(string: "\(cursorAPIBase)/auth/usage-summary") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "CursorTracker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch usage summary"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let individualUsage = json["individualUsage"] as? [String: Any],
                   let plan = individualUsage["plan"] as? [String: Any] {
                    
                    let used = plan["used"] as? Int ?? 0
                    let limit = plan["limit"] as? Int ?? 0
                    let remaining = plan["remaining"] as? Int ?? 0
                    let membershipType = json["membershipType"] as? String ?? auth.membershipType
                    
                    let info = CursorUsageInfo(
                        email: auth.email,
                        planUsed: used,
                        planLimit: limit,
                        planRemaining: remaining,
                        planType: membershipType
                    )
                    completion(.success(info))
                } else {
                    completion(.failure(NSError(domain: "CursorTracker", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func readAuthFromStateDB() -> CursorAuthData? {
        let path = NSString(string: stateDBPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        let uri = "file://\(path)?mode=ro&immutable=1"
        var db: OpaquePointer?
        
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }
        
        var accessToken: String?
        var email: String?
        var membershipType: String?
        
        let query = "SELECT key, value FROM ItemTable WHERE key LIKE 'cursorAuth/%'"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let keyPtr = sqlite3_column_text(stmt, 0),
                   let valuePtr = sqlite3_column_text(stmt, 1) {
                    let key = String(cString: keyPtr)
                    let value = String(cString: valuePtr)
                    
                    switch key {
                    case "cursorAuth/accessToken": accessToken = value
                    case "cursorAuth/cachedEmail": email = value
                    case "cursorAuth/stripeMembershipType": membershipType = value
                    default: break
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return CursorAuthData(accessToken: accessToken, email: email, membershipType: membershipType)
    }
}
