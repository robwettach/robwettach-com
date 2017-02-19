//
//  Errors.swift
//  robwettach-com
//
//  Created by Rob Wettach on 2/19/17.
//
//

import Foundation

enum Errors : Error {
  case missingConfig(group: String, key: String)
  case invalidUserType
}
