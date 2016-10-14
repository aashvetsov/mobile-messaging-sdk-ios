//
//  MMResponseSerializer.swift
//
//  Created by Andrey K. on 14/04/16.
//
//

import MMAFNetworking
import SwiftyJSON

final class MMResponseSerializer<T: JSONDecodable> : MM_AFHTTPResponseSerializer {
	override init() {
		super.init()
		let range: NSRange = NSMakeRange(200, 100)
		self.acceptableStatusCodes = NSIndexSet(indexesInRange: range)
	}
	
	override func responseObjectForResponse(response: NSURLResponse?, data: NSData?, error: NSErrorPointer) -> AnyObject? {
		super.responseObjectForResponse(response, data: data, error: error)
		
		guard let response = response,
			  let data = data else {
				return nil
		}
		let dataString = String(data: data, encoding: NSUTF8StringEncoding)
		
		MMLogSecureDebug("Response received: \(response)\n\(dataString)")
		
		let json = JSON(data: data)
		if let requestError = MMRequestError(json: json) where response.isFailureHTTPResponse ?? false {
			error.memory = requestError.foundationError
		}
		
		return T(json: json) as? AnyObject
	}
}

extension NSURLResponse {
	var isFailureHTTPResponse: Bool {
		var statusCodeIsError = false
		if let httpResponse = self as? NSHTTPURLResponse {
			statusCodeIsError = NSIndexSet(indexesInRange: NSMakeRange(200, 100)).containsIndex(httpResponse.statusCode) == false
		}
		return statusCodeIsError
	}
}
