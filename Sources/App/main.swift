import Vapor
import HTTP

let drop = Droplet()

drop.get { request in
  return Response(redirect: "index.html")
}

drop.run()
