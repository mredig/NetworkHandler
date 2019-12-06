//
//  NetworkHeaders.swift
//  NetworkHandler-iOS
//
//  Created by Michael Redig on 12/6/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import Foundation

public struct HTTPHeader: Hashable {
	let key: HTTPHeaderKey
	let value: HTTPHeaderValue
}

/// Pre-typed strings for use with formatting headers
public enum HTTPHeaderKey: Hashable {
	public enum CommonKey: String, Hashable {
		case accept = "Accept"
		case acceptEncoding = "Accept-Encoding"
		case authorization = "Authorization"
		case contentType = "Content-Type"
		case acceptCharset = "Accept-Charset"
		case acceptDatetime = "Accept-Datetime"
		case acceptLanguage = "Accept-Language"
		case cacheControl = "Cache-Control"
		case date = "Date"
		case ifMatch = "If-Match"
		case ifModifiedSince = "If-Modified-Since"
		case ifNoneMatch = "If-None-Match"
		case ifRange = "If-Range"
		case ifUnmodifiedSince = "If-Unmodified-Since"
		case maxForwards = "Max-Forwards"
		case pragma = "Pragma"
		case proxyAuthorization = "Proxy-Authorization"
		case proxyConnection = "Proxy-Connection"
		case range = "Range"
		case referer = "Referer"
		case TE = "TE"
		case upgrade = "Upgrade"
		case userAgent = "User-Agent"
		case via = "Via"
		case warning = "Warning"
		case frontEndHttps = "Front-End-Https"
		case cookie = "Cookie"
		case expect = "Expect"
	}
	case commonKey(key: CommonKey)
	case other(key: String)
}

public enum HTTPHeaderValue: Hashable {
	public enum CommonContentType: String, Hashable {
		case javascript = "application/javascript"
		case json = "application/json"
		case octetStream = "application/octet-stream"
		case xChromeExtension = "application/x-chrome-extension"
		case xFontWoff = "application/x-font-woff"
		case xml = "application/xml"
		case audioMp4 = "audio/mp4"
		case ogg = "audio/ogg"
		case opentype = "font/opentype"
		case svgXml = "image/svg+xml"
		case webp = "image/webp"
		case xIcon = "image/x-icon"
		case cacheManifest = "text/cache-manifest"
		case vCard = "text/v-card"
		case vtt = "text/vtt"
		case xXomponent = "text/x-component"
		case videoMp4 = "video/mp4"
		case videoOgg = "video/ogg"
		case webm = "video/webm"
		case xFlv = "video/x-flv"
		case png = "image/png"
		case jpeg = "image/jpeg"
		case bmp = "image/bmp"
		case css = "text/css"
		case gif = "image/gif"
		case html = "text/html"
		case audioMpeg = "audio/mpeg"
		case videoMpeg = "video/mpeg"
		case pdf = "application/pdf"
		case quicktime = "video/quicktime"
		case rtf = "application/rtf"
		case tiff = "image/tiff"
		case plain = "text/plain"
		case zip = "application/zip"
		case plist = "application/x-plist"
	}

	case contentType(type: CommonContentType)
	case other(value: String)
}
