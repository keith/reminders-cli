import Foundation
import EventKit
import SystemPackage

private let Store = EKEventStore();

let reminders2 = Reminders();

public final class MDScanner {
   public func scan() {
      let url = URL.init(fileURLWithPath: "/Users/pascalvonfintel/Documents/Personal Writings");
      // let url = Bundle.main.bundleURL;
      print(url);
      let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
      let directoryEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
 
      var fileURLs: [URL] = []
      for case let fileURL as URL in directoryEnumerator {
         guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
            let isDirectory = resourceValues.isDirectory,
            let name = resourceValues.name
            else {
                  continue
            }
         
         if !isDirectory {
            if (name.suffix(8) == ".scan.md") {
               fileURLs.append(fileURL)
               print(name);
            }
         }
      }
      for url in fileURLs {
         do {
            let test = try String (contentsOf: url);
            let arrayOfStrings = test.components(separatedBy: "\n")

            let todos = arrayOfStrings.filter({line in 
               return line.prefix(5) == "- [ ]" || line.prefix(5) == "- [x]"; 
            });
            let resourceValues = try url.resourceValues(forKeys: [.nameKey, .contentModificationDateKey]);
            // Name of file without .scan.md
            let name = resourceValues.name!.dropLast(8);
            let lastmodified = resourceValues.contentModificationDate;
            print(name);
            // If list does not exist, create it
            if !reminders2.hasList(calendarName: String(name)) {
               reminders2.newList(calendarName: String(name));
            }
            let remindersArray = reminders2.returnListItems(withName: String(name));
            var reminderTitleArray:[String] = [];
            for rem in remindersArray {
               reminderTitleArray.append(rem.title);
            }
            for todo in todos {
               // Get rid of '- [ ] '
               let todoName = todo.dropFirst(6);
               // Add reminder if not already there
               if !reminderTitleArray.contains(String(todoName)) {
                 reminders2.addReminder(string: String (todoName), toListNamed: String(name), dueDate: nil);
               } else {
                  let rem = remindersArray.find(where: {$0.title == todoName});
                  // File updated more recently than reminder
                  if (rem!.lastModifiedDate! < lastmodified!) {
                     let isComplete = todo.prefix(5) == "- [x]";
                     // If difference
                     if (isComplete != rem?.isCompleted) {
                        rem?.isCompleted = isComplete;
                        try Store.save(rem!, commit: true)
                        print("Updated '\(rem!.title!)'")
                     }
                  } else {
                     print(todoName);
                     // Stores length of line to overwrite
                     var lenOfLine = 0;
                     var pos = arrayOfStrings[0..<arrayOfStrings.firstIndex(of: todo)!].reduce(0, {x, y in
                        var buf:[UInt8] = Array(y.utf8);
                        buf.append(contentsOf: [10]);
                        if (y == todos[1]) {
                           lenOfLine = buf.count;
                        }
                        return x + buf.count;
                     });
                     // Account for special character
                     pos -= 1;

                     let path:FilePath = FilePath.init(url.path);
                     let fd = try FileDescriptor.open(path, .readWrite);
                     try fd.seek(offset: Int64.init(pos), from: .start);
                     try fd.closeAfter {
                        print("writing to \(url.path)");
                        print(pos);
                        let rawBuf = UnsafeMutableRawBufferPointer.allocate(byteCount: 10000, alignment: 1)
                        // while true {
                        var result = try fd.read(fromAbsoluteOffset: Int64.init(pos), into: rawBuf);
                        
                        var s = "";
                        for it in rawBuf.makeIterator() {
                           if (UInt8(it) == 10) {
                              break;
                           }
                           s += String(UnicodeScalar(UInt8(it))); 
                           result-=1;
                           if (result == 0) {
                              break;
                           }
                        }
                        print(s);
                        // }
                        // print(String.init(decoding: rawBuf, as:UInt8));
                        _ = try fd.writeAll(toAbsoluteOffset: Int64.init(pos - lenOfLine + 4), "x".utf8);
                        // _ = try fd.writeAll("test".utf8);
                     }
                     print (fd);
                  }
               }
               // print(todoName);
            }
            // print (test);
         } catch let error {
            print(error);
            print("error");
            exit(1);
         }   
      }
   }
}
