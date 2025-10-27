import Foundation

protocol AuthTokenProviding: AnyObject {
    var authToken: String? { get }
}
