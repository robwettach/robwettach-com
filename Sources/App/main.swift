import Auth
import HTTP
import TurnstileCrypto
import TurnstileWeb
import Vapor
import VaporPostgreSQL

// MARK: Setup
let drop = Droplet()
try drop.addProvider(VaporPostgreSQL.Provider.self)
drop.preparations.append(BlogPost.self)
drop.preparations.append(User.self)
drop.middleware.append(AuthMiddleware(user: User.self))
drop.middleware.append(TrustProxyMiddleware())

// MARK: Controllers
let auth = try AuthController(drop: drop)
auth.addRoutes()

let blog = BlogController()
blog.addRoutes(drop: drop)

// MARK: Run
drop.run()
