import Cookies
import Foundation
import HTTP
import TurnstileCrypto
import TurnstileWeb
import Vapor

/**
 * Controller that handles routes under `/auth` for authentication.
 */
class AuthController {
  private struct Const {
    static let cookieName = "OAuthState"
  }

  /// The Google Login Provider
  private let google: Google
  /// A reference to the Droplet
  private let drop: Droplet

  /**
   * Initialize AuthController.
   *
   * - throws: `Errors.missingConfig` if missing Google configuration values
   */
  init(drop: Droplet) throws {
    self.drop = drop

    let clientId = try AuthController.getConfig(drop: drop, group: "google", key: "clientId")
    let clientSecret = try AuthController.getConfig(drop: drop, group: "google", key: "clientSecret")
    google = Google(clientID: clientId, clientSecret: clientSecret)
  }

  private static func getConfig(drop: Droplet, group: String, key: String) throws -> String {
    guard let value = drop.config[group, key]?.string else {
      throw Errors.missingConfig(group: group, key: key)
    }
    return value
  }

  /**
   * Add `/auth` routes to the Droplet
   */
  func addRoutes() {
    let auth = drop.grouped("auth")
    auth.get("register", "google", handler: registerGoogle)
    auth.get("register", "google", "consumer", handler: registerGoogleConsume)
    auth.get("login", "google", handler: loginGoogle)
    auth.get("login", "google", "consumer", handler: loginGoogleConsume)
  }

  /**
   * Handle `/auth/login/google`.
   */
  func loginGoogle(request: Request) -> ResponseRepresentable {
    return redirectGoogle(request: request, endpoint: "login")
  }

  /**
   * Handle `/auth/login/google/consumer`.
   */
  func loginGoogleConsume(request: Request) throws -> ResponseRepresentable {
    return try authenticateGoogle(request: request, endpoint: "login")
  }

  /**
   * Handle `/auth/register/google`.
   */
  func registerGoogle(request: Request) -> ResponseRepresentable {
    return redirectGoogle(request: request, endpoint: "register")
  }

  /**
   * Handle `/auth/register/google/consumer`.
   */
  func registerGoogleConsume(request: Request) throws -> ResponseRepresentable {
    return try authenticateGoogle(request: request, endpoint: "register") { account in
      // Check that the account is me!
      if account.email != "rob@robwettach.com" {
        throw Abort.custom(status: .notFound, message: "That's not me!")
      }

      try _ = User.register(credentials: account)
    }
  }

  /**
   * Redirect to Google to start the OAuth request.
   *
   * - parameter request: The Vapor Request
   * - parameter endpoint: The endpoint to return to ("login" or "register")
   */
  private func redirectGoogle(request: Request, endpoint: String) -> ResponseRepresentable {
    let state = URandom().secureToken
    let response = Response(redirect: google.getLoginLink(
      redirectURL: request.baseURL + "/auth/\(endpoint)/google/consumer",
      state: state,
      scopes: ["https://www.googleapis.com/auth/userinfo.email"]).absoluteString)
    response.cookies[Const.cookieName] = state
    return response
  }

  /**
   * Authenticate with a Google response.
   *
   * - parameter request: The Vapor Request
   * - parameter endpoint: The endpoint to redirect to on error ("login" or "register")
   * - parameter register: (Optional) A function to call after authenticating with Google but before logging in, to give the opportunity to register the account.
   */
  private func authenticateGoogle(request: Request, endpoint: String, register: ((GoogleAccount) throws -> Void)? = nil) throws -> ResponseRepresentable {
    guard let state = request.cookies[Const.cookieName] else {
      return Response(redirect: "/auth/\(endpoint)")
    }
    let account = try google.authenticate(authorizationCodeCallbackURL: request.uri.description, state: state) as! GoogleAccount

    if let register = register {
      try register(account)
    }

    try request.auth.login(account)

    let response = Response(redirect: "/")
    // Delete the OAuthState cookie as it's no longer needed.
    response.cookies.insert(Cookie(name: Const.cookieName, value: "", expires: Date()))
    return response
  }
}
