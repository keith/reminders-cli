import Foundation
import EventKit
import SystemPackage

private let Store = EKEventStore();

let reminders2 = Reminders();

struct URLUpdates {
   var path:String;
   var updatedAt:Date
}

public final class MDScanner {

   var urls:[URLUpdates] = [];

   public func scan() {
      NotificationCenter.default.addObserver(self, selector: #selector(reloadModelData(notification:)), name: Notification.Name.EKEventStoreChanged, object: nil)
      let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(fire), userInfo: nil, repeats: true);
      RunLoop.current.add(timer, forMode: .common)
      RunLoop.current.run();
   }
   @objc private func reloadModelData(notification: NSNotification) {
      print("Recieved notification")
      fire(notif: true);
   }

   @objc private func fire(notif:Bool = false) {
      // Check if files have updated
      // Keep track of updatedAtDates
      let ret = scan2(notif: notif);
      urls = [];
      do {
         for url in ret {
            let resourceValues = try url.resourceValues(forKeys: [.pathKey, .contentModificationDateKey]);
            urls.append(URLUpdates.init(path: resourceValues.path!, updatedAt: resourceValues.contentModificationDate!))
         } 
      } catch {
         print ("error");
      }
      // print(urls)
   }

   public func scan2(notif:Bool = false) -> [URL] {
      let url = URL.init(fileURLWithPath: "/Users/pascalvonfintel/Documents/Personal Writings");
      // let url = Bundle.main.bundleURL;
      // print(url);
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
               // print(name);
            }
         }
      }
      for url in fileURLs {
         do {
            let test = try String (contentsOf: url);
            let arrayOfStrings = test.components(separatedBy: "\n")

            let resourceValues = try url.resourceValues(forKeys: [.nameKey, .pathKey, .contentModificationDateKey]);
            // If urls not initialized, or if notification was recieved, bypass
            if (urls.count != 0 && !notif) {
               // If file not more recent, break
               if (urls[urls.firstIndex(where: {$0.path == resourceValues.path})!].updatedAt == resourceValues.contentModificationDate!) {
                  break;
               }
            }
            // Name of file without .scan.md
            let name = resourceValues.name!.dropLast(8);
            let lastmodified = resourceValues.contentModificationDate;

            let todos = arrayOfStrings.filter({line in 
               return line.prefix(5) == "- [ ]" || line.prefix(5) == "- [x]"; 
            });
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
                     // Determine whether to complete or uncomplete item (or do nothing)
                     let isComplete = rem!.isCompleted;
                     // If no difference
                     if (isComplete == (todo.prefix(5) == "- [x]")) {
                        continue;
                     }
                     // Stores length of line to overwrite
                     let pos = arrayOfStrings[0..<arrayOfStrings.firstIndex(of: todo)!].reduce(0, {x, y in
                        var buf:[UInt8] = Array(y.utf8);
                        buf.append(contentsOf: [10]);
                        return x + buf.count;
                     });
                     
                     let path:FilePath = FilePath.init(url.path);
                     let fd = try FileDescriptor.open(path, .readWrite);
                     try fd.seek(offset: Int64.init(pos+3), from: .start);
                     try fd.closeAfter {
                        let char = isComplete ? "x" : " ";
                        _ = try fd.writeAll(char.utf8);
                     }
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
      return fileURLs;
   }
}
