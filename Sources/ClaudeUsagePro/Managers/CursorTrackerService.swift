import Foundation
import SQLite3

enum CursorTrackerError: Error, LocalizedError {
    case authNotFound
    case fetchFailed(Error)
    case badResponse(statusCode: Int)
    case invalidJSONResponse(Error)
    case invalidAPIURL

    var errorDescription: String? {
        switch self {
        case .authNotFound:
            return "Cursor authentication token not found in the local database."
        case .fetchFailed(let error):
            return "Failed to fetch usage summary: \(error.localizedDescription)"
        case .badResponse(let statusCode):
            return "Received an invalid server response (Status Code: \(statusCode))."
        case .invalidJSONResponse(let error):
            return "Failed to parse the JSON response: \(error.localizedDescription)"
        case .invalidAPIURL:
            return "The API endpoint URL is invalid."
        }
    }
}

private struct CursorAPIResponse: Codable {
    let individualUsage: IndividualUsage
    let membershipType: String?
}

private struct IndividualUsage: Codable {
    let plan: Plan
}

private struct Plan: Codable {
    let used: Int
    let limit: Int
    let remaining: Int
}

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
    
    /// Checks whether the Cursor state database exists in the user's Application Support directory.
    /// - Returns: `true` if the Cursor state database file exists at ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb, `false` otherwise.
    func isInstalled() -> Bool {
        let path = NSString(string: "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb").expandingTildeInPath
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Fetches the current Cursor usage summary for the locally stored account.
    /// - Returns: A `CursorUsageInfo` containing the account email (if available), plan usage (`planUsed`, `planLimit`, `planRemaining`), and `planType` (if available).
    /// - Throws:
    ///   - `CursorTrackerError.authNotFound` if authentication data or access token is missing.
    ///   - `CursorTrackerError.invalidAPIURL` if the usage-summary URL cannot be constructed.
    ///   - `CursorTrackerError.badResponse(statusCode:)` if the HTTP response is missing or has a non-200 status code.
    ///   - `CursorTrackerError.invalidJSONResponse(_)` if the API response cannot be decoded as the expected JSON.
    func fetchCursorUsage() async throws -> CursorUsageInfo {
        guard let auth = readAuthFromStateDB(), let token = auth.accessToken else {
            throw CursorTrackerError.authNotFound
        }
        
        guard let url = URL(string: "\(cursorAPIBase)/auth/usage-summary") else {
            throw CursorTrackerError.invalidAPIURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorTrackerError.badResponse(statusCode: 0)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CursorTrackerError.badResponse(statusCode: httpResponse.statusCode)
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(CursorAPIResponse.self, from: data)
            let plan = apiResponse.individualUsage.plan
            
            return CursorUsageInfo(
                email: auth.email,
                planUsed: plan.used,
                planLimit: plan.limit,
                planRemaining: plan.remaining,
                planType: apiResponse.membershipType ?? auth.membershipType
            )
        } catch {
            throw CursorTrackerError.invalidJSONResponse(error)
        }
    }
    
    /// Reads Cursor authentication data from the local Cursor state database.
    /// 
    /// Extracts the stored `accessToken`, cached email, and Stripe membership type (if present)
    /// and returns them wrapped in a `CursorAuthData`.
    /// - Returns: A `CursorAuthData` containing any found `accessToken`, `email`, and `membershipType`, or `nil` if the state database is missing or cannot be read.
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