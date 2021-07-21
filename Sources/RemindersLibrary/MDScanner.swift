import Foundation
import EventKit
import SystemPackage

/* 
* TODO: Reminders w/ due dates
* TODO: Deleting reminders
* TODO: Nested reminders??
* TODO: Grouped reminders lists??
*/

private let Store = EKEventStore();

let reminders2 = Reminders();

struct URLUpdates {
   var path:String;
   var updatedAt:Date
   var todos:[String.SubSequence];
}

struct ReminderUpdates {
   var title:String;
   var reminderTitles:[String];
}

public final class MDScanner {

   var urls:[URLUpdates] = [];
   var cals:[ReminderUpdates] = [];

   public func scan() {
      fputs("hi\n",stderr);
      // reminders2.showLists();
      NotificationCenter.default.addObserver(self, selector: #selector(reloadModelData(notification:)), name: Notification.Name.EKEventStoreChanged, object: nil)
      let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(fire), userInfo: nil, repeats: true);
      RunLoop.current.add(timer, forMode: .common)
      RunLoop.current.run();
      // scan2();
   }
   @objc private func reloadModelData(notification: NSNotification) {
      print("Recieved notification");
      fire(notif: true);
   }

   @objc private func fire(notif:Bool = false) {
      scan2(notif: notif);
      // for url in urls {
      //    print(url)
      // }
      // for cal in cals {
      //    print(cal)
      // };
   }

   public func scan2(notif:Bool = false) {
      let url = URL.init(fileURLWithPath: "/Users/pascalvonfintel/Documents/Personal Writings");
      // let url = Bundle.main.bundleURL;
      // print(url);
      let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
      let directoryEnumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
 
      var fileURLs: [URL] = []
      let suffix = ".scan.test.md";
      // Find all files with .scan.md in 'url'
      for case let fileURL as URL in directoryEnumerator {
         guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
            let isDirectory = resourceValues.isDirectory,
            let name = resourceValues.name
            else {
                  continue
            }
         
         if !isDirectory {
            if (name.suffix(suffix.count) == suffix) {
               fileURLs.append(fileURL)
               // print(name);
            }
         }
      }
      // Loop through each file with .scan.md
      for url in fileURLs {
         do {
            var arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")

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
               var todoName = todo.dropFirst(6);
               // Get date, if there is one
               let dateString = getDate(todo: String(todoName));
               // If dateString, remove dateString from todoName
               todoName = removeDate(todo: String(todoName));
               print(todoName);
               // Convert dateString to date
               let date = DateComponents(argument: String(dateString));
               print(date);
               // If reminder in md and not reminders app
               if !reminderTitleArray.contains(String(todoName)) {
                  // If todo is in previous record of reminderTitleArray (has it been deleted?)
                  if (cals.firstIndex(where: {$0.title == name}) != nil && cals[cals.firstIndex(where: {$0.title == name})!].reminderTitles.contains(String(todoName))) {
                     print("cals: \(cals)");
                     print("in notif triggered removal")                     
                     // Remove todo
                     arrayOfStrings.remove(at: arrayOfStrings.firstIndex(of: todo)!);
                     print(arrayOfStrings);
                     let path:FilePath = FilePath.init(url.path);
                     let fd = try FileDescriptor.open(path, .readWrite, options: [.truncate]);
                     // Loop through and rewrite file without line
                     // try fd.seek(offset: Int64.init(pos-1), from: .start);
                     try fd.closeAfter {
                        for str in arrayOfStrings {
                           _ = try fd.writeAll((str + "\n").utf8);
                        }
                     }
                  } else {
                     // Add reminder
                     reminders2.addReminder(string: String (todoName), toListNamed: String(name), isComplete: todo.prefix(5) == "- [x]", dueDate: date);
                  }
               } else {
                  let rem = remindersArray.find(where: {$0.title == todoName})!;
                  // File updated more recently than reminder
                  if (rem.lastModifiedDate! < lastmodified!) {
                     // Compare dates
                     var dateDifference:Bool;
                     if (rem.dueDateComponents != nil) {
                        // True if dates are different
                        dateDifference = date?.date != rem.dueDateComponents?.date
                     } else {
                        // True if date is existent and rem.dueDateComponents is not
                        dateDifference = date != nil;
                     }
                     print(rem.dueDateComponents?.date)
                     print(date?.date);
                     print(dateDifference);
                     let isComplete = todo.prefix(5) == "- [x]";
                     // If difference in completeness
                     if (isComplete != rem.isCompleted || dateDifference) {
                        rem.isCompleted = isComplete;
                        rem.dueDateComponents = date
                        try Store.save(rem, commit: true)
                        print("Updated '\(rem.title!)'")
                     }
                  } else {
                     // Determine whether to complete or uncomplete item (or do nothing)
                     let isComplete = rem.isCompleted;
                     // If no difference
                     if (isComplete == (todo.prefix(5) == "- [x]")) {
                        continue;
                     }
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
            // Stores the names without - [(x)]
            let todoNames = mapToNames(todos:todos);
            // Loop through reminders in reminders list
            for rem in remindersArray {
               var dateString:String = "";
               if (rem.dueDateComponents != nil) {
                  let formatter = DateFormatter()
                  // Check if date is all day
                  if (rem.dueDateComponents!.hour != nil) {
                     formatter.dateFormat = " – EEEE, d 'at' h:mm a"
                  } else {
                     formatter.dateFormat = " – EEEE, d"
                  }
                  dateString = formatter.string(from: rem.dueDateComponents!.date!)
               }   
               // If reminder not in md file
               if !todoNames.contains(Substring.init(rem.title)) {
                  let section = "## Todos added from cli";
                  // Check if there's not a '## Todos added from cli' section
                  let path:FilePath = FilePath.init(url.path);

                  // If todo is in previous record of todoNames (has it been deleted?)
                  if (urls.firstIndex(where: {$0.path == url.path}) != nil && urls[urls.firstIndex(where: {$0.path == url.path})!].todos.contains(String.SubSequence(rem.title))) {
                     // Remove todo
                     try Store.remove(rem, commit: true);
                  } else {
                     if (arrayOfStrings.firstIndex(of: section) == nil) {
                        let fd = try FileDescriptor.open(path, .readWrite, options: [.append]);
                        let str = "\n" + section + "\n\n";
                        try fd.closeAfter {
                           _ = try fd.writeAll(str.utf8);
                        }
                        // Update arrayOfStrings
                        arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")
                     }
                     let remString = "- [" + (rem.isCompleted ? "x" : " ") + "] \(rem.title!)\(dateString)\n";
                     let fd = try FileDescriptor.open(path, .readWrite, options: [.append]);
                     try fd.closeAfter {
                        _ = try fd.writeAll(remString.utf8);
                     }
                  }
               }
            }
            // print (test);
         } catch let error {
            print(error);
            print("error");
            exit(1);
         }   
      }
      urls = [];
      cals = [];
      // Second loop through files in order to keep record of what cals and files contained at last go through
      // This is done so we know which file or calendar list has most recently been updated so we can properly sync items
      do {
         for url in fileURLs {
            let resourceValues = try url.resourceValues(forKeys: [.pathKey, .nameKey, .contentModificationDateKey]);
            let arrayOfStrings = try String(contentsOf: url).components(separatedBy: "\n")
            // Name of file without .scan.md
            let name = resourceValues.name!.dropLast(8);
            let lastmodified = resourceValues.contentModificationDate!;
            let path = resourceValues.path!;
            let todos = arrayOfStrings.filter({line in 
               return line.prefix(5) == "- [ ]" || line.prefix(5) == "- [x]"; 
            });
            let todoNames = mapToNames(todos: todos);
            // If list does not exist, create it
            if !reminders2.hasList(calendarName: String(name)) {
               reminders2.newList(calendarName: String(name));
            }
            let remindersArray = reminders2.returnListItems(withName: String(name));
            var reminderTitleArray:[String] = [];
            for rem in remindersArray {
               reminderTitleArray.append(rem.title);
            }
            urls.append(URLUpdates.init(path:path, updatedAt: lastmodified, todos:todoNames))
            cals.append(ReminderUpdates.init(title: String(name), reminderTitles: reminderTitleArray));
         }
      } catch {
         print ("error");
      }
   }
   // Gets the date suffix if there is one, otherwise returns an empty string
   private func getDate(todo:String) -> String.SubSequence {
     return todo.suffix(from: todo.index(todo.lastIndex(of: "–") ?? todo.index(todo.endIndex, offsetBy: -2), offsetBy: 2));
   }
   // Returns the todo without a date suffix, if there is one
   private func removeDate(todo:String) -> String.SubSequence {
      if (todo.lastIndex(of: "–") != nil) {
         return todo.prefix(upTo: todo.index(todo.lastIndex(of: "–")!, offsetBy: -1));
      }
      return String.SubSequence(todo);
   }
   // Remose - [ ] prefix and date suffix
   private func mapToNames(todos:[String])->[String.SubSequence]{
      return todos.map({todo in
         return removeDate(todo: String(todo.dropFirst(6)));
      })
   }
}

