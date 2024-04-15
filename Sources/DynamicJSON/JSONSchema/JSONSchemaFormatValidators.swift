//
//  JSONSchemaDraft2020FormatValidators.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 14/04/2024.
//

import Foundation

public struct JSONSchemaFormatValidators {
  
  public static let draft2020: [String : (String) -> Bool] = [
    "date-time": JSONSchemaFormatValidators.isDateTime,
    "date": JSONSchemaFormatValidators.isDate,
    "time": JSONSchemaFormatValidators.isTime
  ]
  
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
  
  public static func isTime(_ str: String) -> Bool {
    guard str.allSatisfy(\.isASCII) else {
      return false
    }
    let regexp = try! NSRegularExpression(pattern: #"""
      (?x) ^ (?<hour>(([01]\d)|(2[0-3]))) :
             (?<minute>([0-5]\d)) :
             (?<second>(([0-5]\d)|(60)))
             (?<secfrac>\.\d+)?
             (?<offset> ( Z | (?<numoffset>
                              (?<numoffsetdirection>[+-])
                              (?<numoffsethour>([01]\d)|2[0-3]) :
                              (?<numoffsetminute>[0-5]\d)))) $
      """#, options: [.caseInsensitive])
    guard let match = regexp.firstMatch(in: str, range: NSMakeRange(0, str.utf16.count)),
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
}
