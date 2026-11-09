import Foundation
import XCTest
import Supabase
@testable import AuthKit
@testable import AuthKitSupabase

final class MockSupabaseURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class SupabaseBackendTests: XCTestCase {

    private let testURL = URL(string: "https://mock.supabase.co") ?? URL(fileURLWithPath: "/")
    private let testKey = "mock_publishable_key"
    private let callbackURL = URL(string: "mock://callback") ?? URL(fileURLWithPath: "/")

    private let sessionJSON = Data("""
    {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNjQ4NjQwMDIxLCJzdWIiOiJmMzNkM2VjOS1hMmVlLTQ3YzQtODBlMS01YmQ5MTlmM2Q4YjgiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJwaG9uZSI6IiIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIiwicHJvdmlkZXJzIjpbImVtYWlsIl19LCJ1c2VyX21ldGFkYXRhIjp7fSwicm9sZSI6ImF1dGhlbnRpY2F0ZWQifQ.sig",
      "token_type": "bearer",
      "expires_in": 3600,
      "expires_at": 345345345,
      "refresh_token": "GGduTeu95GraIXQ56jppkw",
      "user": {
        "id": "f33d3ec9-a2ee-47c4-80e1-5bd919f3d8b8",
        "aud": "authenticated",
        "role": "authenticated",
        "email": "test@example.com",
        "created_at": "2022-03-30T10:33:41.005433Z",
        "updated_at": "2022-03-30T10:33:41.022688Z"
      }
    }
    """.utf8)

    private let signupJSON = Data("""
    {
      "id": "859f402d-b3de-4105-a1b9-932836d9193b",
      "aud": "authenticated",
      "role": "authenticated",
      "email": "test@example.com",
      "created_at": "2022-04-09T11:23:45.874827Z",
      "updated_at": "2022-04-09T11:57:01.720803Z"
    }
    """.utf8)

    private let userJSON = Data("""
    {
      "id": "f33d3ec9-a2ee-47c4-80e1-5bd919f3d8b8",
      "aud": "authenticated",
      "role": "authenticated",
      "email": "test@example.com",
      "created_at": "2022-03-30T10:33:41.005433Z",
      "updated_at": "2022-03-30T10:33:41.022688Z"
    }
    """.utf8)

    override func tearDown() {
        MockSupabaseURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeBackend(flowType: AuthFlowType = .implicit) -> SupabaseAuthBackend {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockSupabaseURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let manager = SupabaseManager(
            url: testURL,
            publishableKey: testKey,
            authOptions: .init(flowType: flowType),
            globalOptions: .init(session: session)
        )
        return SupabaseAuthBackend(manager: manager)
    }

    private func makeResponse(
        for request: URLRequest,
        statusCode: Int = 200,
        headerFields: [String: String]? = ["Content-Type": "application/json"]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? testURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        ) ?? HTTPURLResponse()
    }

    func testBackendFactoryCreation() {
        let backend = SupabaseBackendFactory.make(
            projectURL: testURL,
            publishableKey: testKey,
            callbackURL: callbackURL,
            storageKey: "test.storage"
        )
        XCTAssertNotNil(backend)

        let config = AppAuthConfiguration(
            projectURL: testURL,
            publishableKey: testKey,
            callbackURL: callbackURL,
            storageKey: "test.storage"
        )
        let backendFromConfig = SupabaseBackendFactory.make(configuration: config)
        XCTAssertNotNil(backendFromConfig)
    }

    func testSignInSuccess() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.sessionJSON)
        }

        let backend = makeBackend()
        let user = try await backend.signIn(email: "test@example.com", password: "password123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.id.uuidString.lowercased(), "f33d3ec9-a2ee-47c4-80e1-5bd919f3d8b8")
    }

    func testSignUpSuccess() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.signupJSON)
        }

        let backend = makeBackend()
        let requiresConfirmation = try await backend.signUp(email: "test@example.com", password: "password123")
        XCTAssertTrue(requiresConfirmation)
    }

    func testCurrentUserReturnsNilWhenNoSession() async throws {
        let backend = makeBackend()
        let user = try await backend.currentUser()
        XCTAssertNil(user)
    }

    func testSignOutSuccess() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request, headerFields: [:])
            return (response, Data())
        }

        let backend = makeBackend()
        try await backend.signOut()
    }

    func testDeleteAccountSuccess() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request, headerFields: [:])
            return (response, Data("{}".utf8))
        }

        let backend = makeBackend()
        try await backend.deleteAccount()
    }

    func testPasswordResetAndRecovery() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            let data = path.contains("recover") ? Data("{}".utf8) : self.userJSON
            let response = self.makeResponse(for: request)
            return (response, data)
        }

        let backend = makeBackend()
        try await backend.requestPasswordReset(email: "test@example.com", redirectTo: callbackURL)
        try await backend.updatePassword("new-secret-password")
    }

    func testInitWithClient() {
        let client = SupabaseClient(supabaseURL: testURL, supabaseKey: testKey)
        let backend = SupabaseAuthBackend(client: client)
        XCTAssertNotNil(backend)
    }

    func testRefreshSession() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.sessionJSON)
        }

        let backend = makeBackend()
        try await backend.refreshSession()
    }

    func testCurrentUserWhenSessionPresent() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.sessionJSON)
        }

        let backend = makeBackend()
        _ = try await backend.signIn(email: "test@example.com", password: "pwd")
        let user = try await backend.currentUser()
        XCTAssertEqual(user?.email, "test@example.com")
    }

    func testEventsStream() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.sessionJSON)
        }

        let backend = makeBackend()
        let stream = await backend.events()
        var iterator = stream.makeAsyncIterator()
        let task = Task {
            await iterator.next()
        }
        _ = try await backend.signIn(email: "test@example.com", password: "pwd")
        _ = await task.value
    }

    func testHandleCallback() async throws {
        MockSupabaseURLProtocol.requestHandler = { request in
            let response = self.makeResponse(for: request)
            return (response, self.userJSON)
        }

        let backend = makeBackend()
        let callbackURL = URL(string: "mock://callback#access_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMzNkM2VjOS1hMmVlLTQ3YzQtODBlMS01YmQ5MTlmM2Q4YjgiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20ifQ.sig&expires_in=3600&refresh_token=mock_refresh&token_type=bearer") ?? self.callbackURL
        let user = try await backend.handleCallback(callbackURL)
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.id.uuidString.lowercased(), "f33d3ec9-a2ee-47c4-80e1-5bd919f3d8b8")
    }
}
