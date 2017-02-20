import Fluent
import Foundation
import Vapor

final class BlogPost : Model {
  struct Const {
    static let id = "id"
    static let title = "title"
    static let body = "body"
    static let author = "author"
    static let authorId = "author_id"
    static let date = "date"
    static let dateStr = "dateStr"
    static let tableName = "blog_posts"
  }

  public static var entity = Const.tableName

  var exists = false
  var id: Node?
  let date: Date
  let body: String
  let title: String
  let authorId: Node?

  fileprivate init(id: Node?, title: String, body: String, authorId: Node?, date: Date) {
    self.id = id
    self.title = title
    self.body = body
    self.authorId = authorId
    self.date = date
  }

  init(title: String, body: String, author: User, date: Date = Date()) {
    self.title = title
    self.body = body
    self.authorId = author.id
    self.date = date
  }

  func makeViewNode() throws -> Node {
    let node = try makeNode()

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    formatter.timeZone = TimeZone(abbreviation: "MST")
    var newNode = node.nodeObject!
    newNode[Const.dateStr] = formatter.string(from: date).makeNode()
    newNode[Const.author] = try author().makeNode()

    return try Node(node: newNode)
  }
}

// MARK: Author
extension BlogPost {
  func author() throws -> User {
    return try parent(authorId, nil, User.self).get()!
  }
}

// MARK: Date: NodeConvertible
/**
 * Make `Date` conform to `NodeConvertible`.
 *
 * `Date` is represented in `Node` form as it's `Double`-valued `timeIntervalSince1970`
 */
extension Date : NodeConvertible {
  public init(node: Node, in context: Context) throws {
    self.init(timeIntervalSince1970: node.double!)
  }

  public func makeNode(context: Context) throws -> Node {
    return self.timeIntervalSince1970.makeNode()
  }
}

// MARK: NodeConvertible
extension BlogPost : NodeConvertible {
  convenience init(node: Node, in context: Context) throws {
    let id = node[Const.id]
    let title: String = try node.extract(Const.title)
    let body: String = try node.extract(Const.body)
    let authorId: Node? = node[Const.authorId]
    let date: Date = try node.extract(Const.date)

    self.init(id: id, title: title, body: body, authorId: authorId, date: date)
  }

  func makeNode(context: Context) throws -> Node {
    return try Node(node: [
      Const.id : id,
      Const.title : title,
      Const.body : body,
      Const.authorId : authorId,
      Const.date : date
    ])
  }
}

// MARK: Preparation
extension BlogPost : Preparation {
  static func prepare(_ database: Database) throws {
    try database.create(Const.tableName) { blogPosts in
      blogPosts.id()
      blogPosts.string(Const.title)
      blogPosts.custom(Const.body, type: "TEXT")
      blogPosts.double(Const.date)
      blogPosts.parent(idKey: Const.authorId, optional: false)
    }
  }

  static func revert(_ database: Database) throws {
    try database.delete(Const.tableName)
  }
}
