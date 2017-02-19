import HTTP
import Fluent
import Turnstile
import TurnstileCrypto
import TurnstileWeb
import Auth

/**
 * A User model that can authenticate with Google credentials.
 */
final class User : Auth.User {
  fileprivate struct Const {
    static let tableName = "users"
    static let id = "id"
    static let username = "username"
    static let googleId = "google_id"
  }

  var exists: Bool = false
  var id: Node?
  let username: String
  let googleId: String

  /**
   * Create a User with the given `GoogleAccount` and optional user name.
   */
  init(credentials: GoogleAccount, username: String? = nil) {
    if let username = username {
      self.username = username
    } else {
      self.username = "goog" + credentials.uniqueID
    }
    googleId = credentials.uniqueID
  }

  fileprivate init(id: Node?, username: String, googleId: String) {
    self.id = id
    self.username = username
    self.googleId = googleId
  }
}

// MARK: Authenticator
extension User : Authenticator {
  /**
   * Register an account.
   *
   * - parameter credentials: Only `GoogleAccount` credentials are supported
   * - returns: A new `User` created by the `credentials`
   * - throws:
   * `UnsupportedCredentialsError` if the `credentials` parameter is not a `GoogleAccount`
   * `AccountTakenError` if the Google account already maps to a user
   */
  static func register(credentials: Credentials) throws -> Auth.User {
    var newUser: User

    switch credentials {
    case let credentials as GoogleAccount:
      newUser = User(credentials: credentials)
    default:
      throw UnsupportedCredentialsError()
    }

    if try User.query().filter(Const.googleId, newUser.googleId).first() == nil {
      try newUser.save()
      return newUser
    } else {
      throw AccountTakenError()
    }
  }

  /**
   * Authenticate an account.
   *
   * - parameter credentials: Either `GoogleAccount` or `Identifier`
   * - returns: The `User` represented by the `credentials`
   * - throws:
   * `UnsupportedCredentialsError` if the `credentials` parameter is not a `GoogleAccount` or an `Identifier`
   * `IncorrectCredentialsError` if the `credentials` parameter does not match an existing user
   */
  static func authenticate(credentials: Credentials) throws -> Auth.User {
    var user: User?

    switch credentials {
    // Vapor Session
    case let credentials as Identifier:
      user = try User.find(credentials.id)
    // Initial Google log in
    case let credentials as GoogleAccount:
      if let existing = try User.query().filter(Const.googleId, credentials.uniqueID).first() {
        user = existing
      }
    default:
      throw UnsupportedCredentialsError()
    }

    if let user = user {
      return user
    } else {
      print("No user found for credentials: \(credentials)")
      throw IncorrectCredentialsError()
    }
  }
}

// MARK: NodeRepresentable
extension User : NodeRepresentable {
  convenience init(node: Node, in context: Context) throws {
    let id = node[Const.id]
    let username: String = try node.extract(Const.username)
    let googleId: String = try node.extract(Const.googleId)

    self.init(id: id, username: username, googleId: googleId)
  }

  func makeNode(context: Context) throws -> Node {
    return try Node(node: [
      Const.id : id,
      Const.username : username,
      Const.googleId : googleId
    ])
  }
}

// MARK: Prepration
extension User : Preparation {
  static func prepare(_ database: Database) throws {
    try database.create(Const.tableName) { users in
      users.id()
      users.string(Const.username)
      users.string(Const.googleId)
    }
  }

  static func revert(_ database: Database) throws {
    try database.delete(Const.tableName)
  }
}

// MARK: Request
/**
 * Add a user() method to Vapor Requests
 */
extension Request {
  /**
   * Get the currently-authenticated user.
   *
   * - returns: The authenticated `User`
   * - throws: `Errors.invalidUserType` if the authenticated user is not of type `User`
   */
  func user() throws -> User {
    guard let user = try auth.user() as? User else {
      throw Errors.invalidUserType
    }
    return user
  }
}
