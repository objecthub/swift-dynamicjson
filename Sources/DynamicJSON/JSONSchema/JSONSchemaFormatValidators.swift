//
//  JSONSchemaDraft2020FormatValidators.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 14/04/2024.
//

import Foundation

public struct JSONSchemaFormatValidators {
  
  public static let draft2020: [String : (String) -> Bool] = [
    "unknown": JSONSchemaFormatValidators.isUnknown,
    "date-time": JSONSchemaFormatValidators.isDateTime,
    "date": JSONSchemaFormatValidators.isDate,
    "time": JSONSchemaFormatValidators.isTime,
    "duration": JSONSchemaFormatValidators.isDuration,
    "email": JSONSchemaFormatValidators.isEmail,
    "json-pointer": JSONSchemaFormatValidators.isJSONPointer,
    "regex": JSONSchemaFormatValidators.isRegex,
    "uuid": JSONSchemaFormatValidators.isUUID,
    "uri": JSONSchemaFormatValidators.isURI,
    "uri-reference": JSONSchemaFormatValidators.isURIReference,
    "ipv4": JSONSchemaFormatValidators.isIPV4,
    "ipv6": JSONSchemaFormatValidators.isIPV6,
    "hostname": JSONSchemaFormatValidators.isHostname
  ]
  
  public static func isUnknown(_ str: String) -> Bool {
    return true
  }
  
  public static func isDateTime(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    do {
      let parser = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
      _ = try parser.parse(str)
      return true
    } catch {}
    do {
      let parser = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
      _ = try parser.parse(str)
      return true
    } catch {}
    return false
  }
  
  public static func isDate(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    let regex = Regex<AnyRegexOutput>(/(?<year>\d{4})\-(?<month>\d{2})\-(?<day>\d{2})/)
    if let match = str.wholeMatch(of: regex) {
      if let year = match["year"]?.substring,
         let month = match["month"]?.substring,
         let day = match["day"]?.substring {
        let date = DateComponents(year: Int(year), month: Int(month), day: Int(day))
        return date.isValidDate(in: .current)
      }
    }
    return false
  }
  
  private static let timeRegex = try! NSRegularExpression(pattern: #"""
      (?x) ^ (?<hour>(([01]\d)|(2[0-3]))) :
             (?<minute>([0-5]\d)) :
             (?<second>(([0-5]\d)|(60)))
             (?<secfrac>\.\d+)?
             (?<offset> ( Z | (?<numoffset>
                              (?<numoffsetdirection>[+-])
                              (?<numoffsethour>([01]\d)|2[0-3]) :
                              (?<numoffsetminute>[0-5]\d)))) $
      """#, options: [.caseInsensitive])
  
  public static func isTime(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    guard let match = JSONSchemaFormatValidators.timeRegex.firstMatch(
      in: str, range: NSMakeRange(0, str.utf16.count)),
          var hour = Int(str[Range(match.range(withName: "hour"), in: str)!]),
          var minute = Int(str[Range(match.range(withName: "minute"), in: str)!]),
          let second = Int(str[Range(match.range(withName: "second"), in: str)!]) else {
      return false
    }
    if Range(match.range(withName: "numoffset"), in: str) != nil {
      let offsetHour = Int(str[Range(match.range(withName: "numoffsethour"), in: str)!])!
      let offsetMinute = Int(str[Range(match.range(withName: "numoffsetminute"), in: str)!])!
      switch str[Range(match.range(withName: "numoffsetdirection"), in: str)!] {
        case "+":
          hour -= offsetHour
          minute -= offsetMinute
        case "-":
          hour += offsetHour
          minute += offsetMinute
        default:
          break
      }
    }
    return second < 60 || (hour == 23 && minute == 59) || (hour == 0 && minute == -1)
  }
  
  private static let durationRegex =
    try! NSRegularExpression(
      pattern: ##"^P((((\d+D)|((\d+M)(\d+D)?)|((\d+Y)((\d+M)(\d+D)?)?))(T(((\d+H)((\d+M)"## +
      ##"(\d+S)?)?)|((\d+M)(\d+S)?)|(\d+S)))?)|(T(((\d+H)((\d+M)(\d+S)?)?)|"## +
      ##"((\d+M)(\d+S)?)|(\d+S)))|(\d+W))$"##,
      options: [])
  
  public static func isDuration(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    return JSONSchemaFormatValidators.durationRegex.numberOfMatches(
      in: str, range: NSMakeRange(0, str.utf16.count)) > 0
  }
  
  private static let emailRegex =
    try! NSRegularExpression(
      pattern: ##"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:"## +
      ##"[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\"## +
      ##"[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)"## +
      ##"+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|"## +
      ##"[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|"## +
      ##"[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\"## +
      ##"[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])"##, options: [.caseInsensitive])
  
  public static func isEmail(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    return JSONSchemaFormatValidators.emailRegex.numberOfMatches(
      in: str, range: NSMakeRange(0, str.utf16.count)) == 1
  }
  
  public static func isJSONPointer(_ str: String) -> Bool {
    do {
      _ = try JSONPointer(str, strict: true)
      return true
    } catch {
      return false
    }
  }
  
  public static func isRegex(_ str: String) -> Bool {
    do {
      _ = try NSRegularExpression(pattern: str)
      return true
    } catch {
      return false
    }
  }
  
  public static func isUUID(_ str: String) -> Bool {
    return UUID(uuidString: str) != nil
  }
  
  public static func isURI(_ str: String) -> Bool {
    if let uri = URL(string: str) {
      return uri.scheme != nil && !str.contains("\\")
    } else {
      return false
    }
  }
  
  public static func isURIReference(_ str: String) -> Bool {
    return URL(string: str) != nil && !str.contains("\\")
  }
  
  public static func isIPV4(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    let components = str.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 4 else {
      return false
    }
    for component in components {
      guard let first = component.first,
            first != "0" || component.count == 1,
            let num = Int(component),
            num >= 0 && num < 256 else {
        return false
      }
    }
    return true
  }
  
  public static func isIPV6(_ str: String) -> Bool {
    var sin6 = sockaddr_in6()
    return str.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1
  }
  
  private static let hostnameRegex =
    try! NSRegularExpression(
      pattern: "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$",
      options: [])
  
  public static func isHostname(_ str: String) -> Bool {
    if str.count < 256,
       JSONSchemaFormatValidators.hostnameRegex.numberOfMatches(in: str,
                                                                range: NSMakeRange(0, str.utf16.count)) == 1 {
      let components = str.split(separator: ".", omittingEmptySubsequences: false)
      for component in components {
        if component.count >= 64 {
          return false
        }
      }
      return true
    } else {
      return false
    }
  }
}
