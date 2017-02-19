import Auth
import HTTP
import TurnstileCrypto
import TurnstileWeb
import Vapor
import VaporPostgreSQL

// MARK: Setup
let drop = Droplet()
try drop.addProvider(VaporPostgreSQL.Provider.self)
drop.preparations.append(User.self)
drop.middleware.append(AuthMiddleware(user: User.self))
drop.middleware.append(TrustProxyMiddleware())

// MARK: Native routes
drop.get { request in
  return Response(redirect: "index.html")
}

// MARK: Controllers
let auth = try AuthController(drop: drop)
auth.addRoutes()

// MARK: Run
drop.run()
