//
//  BlogController.swift
//  robwettach-com
//
//  Created by Rob Wettach on 2/19/17.
//
//

import Auth
import HTTP
import Vapor

class BlogController {
  func addRoutes(drop: Droplet) {
    drop.get(handler: indexView)
    let blog = drop.grouped("blog")
    blog.get(handler: indexView)

    let protected = ProtectMiddleware(error: Abort.custom(status: .unauthorized, message: "Unauthorized"))
    blog.group(protected) { authed in
      authed.get("new", handler: createView)
      authed.post("new", handler: create)
    }
  }

  func indexView(request: Request) throws -> ResponseRepresentable {
    let posts = try BlogPost.query().sort(BlogPost.Const.date, .descending).all()
    let viewPosts = try posts.map { post in
      return try post.makeViewNode()
    }
    return try drop.view.make("blog/index", ["posts" : viewPosts.makeNode()])
  }

  func createView(request: Request) throws -> ResponseRepresentable {
    return try drop.view.make("blog/create")
  }

  func create(request: Request) throws -> ResponseRepresentable {
    guard let title = request.formURLEncoded?["title"]?.string,
      let body = request.formURLEncoded?["body"]?.string else {
        throw Abort.badRequest
    }

    var post = try BlogPost(title: title, body: body, author: request.user())
    try post.save()

    return Response(redirect: "/blog")
  }
}
