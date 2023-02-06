//
//  AppfroschPersistLocally.swift
//  AppfroschsToolbox
//
//  Created by Andreas Seeger on 29.01.20.
//  Copyright © 2020 Andreas Seeger. All rights reserved.
//
import AppfroschLogger
import Foundation
import CoreGraphics
#if os(iOS)
import UIKit //only required to save/load images on iOS
#else
import AppKit
import SwiftUI
#endif

//MARK: Class Documentation
///Generic, singleton class to persist locally as json files.
///Use `AppfroschPersistLocally.shared` to get access to the singleton.
///
///The struct or class using this __must__ conform to `Codable & Identifiable` which is why iOS13
///is required.
///
///# Example struct
///An example of this is the
///struct `Contact`:
///```
///import Foundation
///
///struct Contact: Codable, Identifiable {
///    let id: UUID // could be String or Int alternatively also
///    var contactTitle: String
///    var name: String? = nil
///    var firstname: String? = nil
///    var address: String? = nil
///    var zip: String? = nil
///    var city: String? = nil
///}
///```
///
///# Saving
///Saving to disk now is as simple as:
///```
///let contact = Contact(id: UUID(), contactTitle: "Foo")
///AppfroschPersistLocally.shared.save(contact)
///```
///Saving like this results in a (potentially new) folder `Contact` locally in the user's domain documents folder
///and a new or updated file within with the `id` as the file name and the instance itself in a json format.
///
///# Loading
///Loading all files of a given type is now done like this:
///```
///contacts = AppfroschPersistLocally.shared.loadAll(of: Contact.self)
///```
///This will grab the contents of the directory `Contact` in this example, decode each file and return an
///array of contacts.
///
///# Deleting
///Deleting a file is done like this:
///```
///AppfroschPersistLocally.shared.delete(instance)
///```
///
public class AppfroschPersistLocally {
    ///The shared instance of this singleton class.
    public static let shared = AppfroschPersistLocally()
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    private let decoderIso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private let decoder = JSONDecoder()
    
    private let fileManager: FileManager = {
        return FileManager.default
    }()
    
    public lazy var docPath: URL = {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let docPath = urls.first else { fatalError() }
        AppfroschLogger.shared.logToConsole(message: "Doc path is: \(docPath)", type: .debug)
        return docPath
    }()
    
    private lazy var imageFolder: URL = {// = docPath.appendingPathComponent("images")
        let imageFolder = docPath.appendingPathComponent("images")
        
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: imageFolder.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
            try? fileManager.createDirectory(at: imageFolder, withIntermediateDirectories: false, attributes: nil)
        }
        
        return imageFolder
    }()
    
    private lazy var dataFolder: URL = {
        let dataFolder = docPath.appendingPathComponent("data")
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: dataFolder.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
            try? fileManager.createDirectory(at: dataFolder, withIntermediateDirectories: false, attributes: nil)
        }
        return dataFolder
    }()
    
    public lazy var tmpFolder: URL = {
        fileManager.temporaryDirectory
    }()
    
    //MARK: - Create
    /// Saves an instance of a given type to a specific filename.
    ///
    /// Use case: could be used to persist a currentObject of an application (e.g. a running timer),
    /// enabling to reload such an object again when the app (re-)launches.
    ///
    /// If the instance is nil, this func will try to delete any instance of a currently saved instance at the filename's path,
    /// if it is not nil, it will save the the instance to the given filename's path.
    public func save<T: Codable>(instance: T? = nil, to filename: String) {
        let path = docPath.appendingPathComponent(filename).appendingPathExtension("json")
        let pathUrl = URL(fileURLWithPath: path.relativePath)
        if let instance = instance {
            do {
                let data = try encoder.encode(instance)
                do {
                    try data.write(to: pathUrl)
                    AppfroschLogger.shared.logToConsole(message: "Saved instance of \(T.self) to file \(path.relativePath)", type: .debug)
                } catch {
                    AppfroschLogger.shared.logToConsole(message: "Could not save data: \(error)", type: .error)
                }
            }
            catch {
                AppfroschLogger.shared.logToConsole(message: "Could not encode data: \(error)", type: .error)
            }
        } else {
            if fileManager.fileExists(atPath: pathUrl.path) {
                do {
                    try fileManager.removeItem(at: pathUrl)
                } catch {
                    AppfroschLogger.shared.logToConsole(message: "Could not remove instance: \(error)", type: .error)
                }
            }
        }
    }
    
    ///Saves an instance of a given type, encoding it and saving it to disk.
    ///
    ///Use the property `subfolder` if the need to save multiple collections of the same type
    ///(e.g. `items` and `archivedItems` for the type `Item`).
    ///
    ///# Usage of this method:
    ///
    ///See the __class documentation__ on the preliminaries and on how to use this method.
    ///- parameter instance: Specific instance of a generic type conforming to `Codable & Identifiable`
    ///- parameter subfolder: optional property that enables saving to a subfolder within the type's folder
    public func save<T: Codable & Identifiable>(instance: T, in subfolder: String? = nil) {
        var pathFolder = docPath.appendingPathComponent(String(describing: T.self))
        if let subfolder = subfolder {
            pathFolder = pathFolder.appendingPathComponent(subfolder)
        }
        if !fileManager.fileExists(atPath: pathFolder.absoluteString) {
            do {
                try fileManager.createDirectory(atPath: pathFolder.relativePath, withIntermediateDirectories: true)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not create folder for type \(T.self): \(error)", type: .error)
            }
        }
        
        let path = pathFolder.appendingPathComponent(String(describing: instance.id)).appendingPathExtension("json")
        
        do {
            let data = try encoder.encode(instance)
            do {
                try data.write(to: URL(fileURLWithPath: path.relativePath))
                AppfroschLogger.shared.logToConsole(message: "Saved instance of \(T.self)", type: .debug)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not save data: \(error)", type: .error)
            }
        } catch let error {
            AppfroschLogger.shared.logToConsole(message: "Could not encode data: \(error)", type: .error)
        }
    }
    
    /// Saves one file of type T locally that cannot be stored in UserDefaults.
    public func saveSingle<T: Codable>(instance: T) {
        let pathFolder = docPath.appendingPathComponent(String(describing: T.self))
        if !fileManager.fileExists(atPath: pathFolder.absoluteString) {
            do {
                try fileManager.createDirectory(atPath: pathFolder.relativePath, withIntermediateDirectories: true)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not create folder for type \(T.self): \(error)", type: .error)
            }
        }
        
        let path = pathFolder.appendingPathComponent(String(describing: T.self)).appendingPathExtension("json")
        
        do {
            let data = try encoder.encode(instance)
            do {
                try data.write(to: URL(fileURLWithPath: path.relativePath))
                AppfroschLogger.shared.logToConsole(message: "Saved instance of \(T.self)", type: .debug)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not save data: \(error)", type: .error)
            }
        } catch let error {
            AppfroschLogger.shared.logToConsole(message: "Could not encode data: \(error)", type: .error)
        }
    }
    
    /// Saves a collection of type T to individual json-files using the `save(instance:)` function.
    /// - Parameter collection: the collection to be saved
    /// - parameter subFolder:
    /// - parameter resetSaveFolder: deletes all entries of the instances being saved prior to saving to reflect the fact that items in the list might have gotten deleted
    public func save<T: Codable & Identifiable>(collection: [T], in subFolder: String? = nil, resetSaveFolder: Bool = true) {
        #warning("Room for improvement here: find the delta from persistence and the collection being saved first and delete only those that need to be deleted... Also, only save those that have changes...")
        self.resetSaveFolder(of: T.self)
        for item in collection {
            save(instance: item, in: subFolder)
        }
    }
    
    /// Saves an image to the `images`-folder using the `id` to name the file.
    ///
    /// Requires UIKit, which is not running on macOS
    ///
    /// By using a `UUID` to name the file, retrieving a file that belongs to an instance of a given type is done by using the instances `id`.
    /// - Parameters:
    ///   - image: the image to be saved
    ///   - id: unique identifier to name the image
    #if os(iOS)
    public func saveImage(_ image: UIImage, with id: UUID) {
        let imagePath = imageFolder.appendingPathComponent(id.uuidString)
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return }
        
        do {
            try imageData.write(to: imagePath, options: .atomic)
            AppfroschLogger.shared.logToConsole(message: "Saved image successfully to \(imagePath.path)", type: .debug)
        } catch let error {
            AppfroschLogger.shared.logToConsole(message: error.localizedDescription, type: .error)
        }
    }
    #else
    public func saveImage(_ image: NSImage, with id: UUID) {
        let imagePath = imageFolder.appendingPathComponent(id.uuidString)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let imageData = bitmapRep.representation(using: .jpeg, properties: .init())
        else { return }
        do {
            try imageData.write(to: imagePath, options: .atomic)
            AppfroschLogger.shared.logToConsole(message: "Saved image successfully to \(imagePath.path)", type: .debug)
        } catch let error {
            AppfroschLogger.shared.logToConsole(message: error.localizedDescription, type: .error)
        }
    }
    #endif
    
    /// Saves an image to the `images`-folder using the `id` to name the file.
    ///
    /// As this method uses `CIImage` as the input, it should be `UIKit` and `AppKit` compatible.
    ///
    /// By using a `UUID` to name the file, retrieving a file that belongs to an instance of a given type is done by using the instances `id`.
    /// - Parameters:
    ///   - image: the image (`CIImage`) to be saved
    ///   - id: unique identifier to name the image
    public func saveImage(_ image: CIImage, with id: UUID) throws {
        let imagePath = imageFolder.appendingPathComponent(id.uuidString)
        let context = CIContext()
        try context.writePNGRepresentation(of: image, to: imagePath, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        AppfroschLogger.shared.logToConsole(message: "Save image with id \(id) successfully to \(imagePath)", type: .debug)
    }
    
    /// Saves an image to the `images`-folder using the `id` to name the file.
    ///
    /// As this method uses `CGImage` as the input, it should be `UIKit` and `AppKit` compatible.
    ///
    /// By using a `UUID` to name the file, retrieving a file that belongs to an instance of a given type is done by using the instances `id`.
    /// - Parameters:
    ///   - image: the image (`CGImage`) to be saved
    ///   - id: unique identifier to name the image
    public func saveImage(_ image: CGImage, with id: UUID) throws {
        let imagePath = imageFolder.appendingPathComponent(id.uuidString)
        let ciImage = CIImage(cgImage: image)
        let context = CIContext()
        try context.writePNGRepresentation(of: ciImage, to: imagePath, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        AppfroschLogger.shared.logToConsole(message: "Save image with id \(id) successfully to \(imagePath)", type: .debug)
    }
    
    /// Copies arbitrary files from a given URL to a data folder within the app.
    ///
    /// This can be used for example to import files from the Files app on iOS. The file will be copied to the folder `data` within the application with its filename being a newly created `UUID`.
    /// This `UUID` is returned so that the model layer of the app can save a reference to the copied file in order to later load that file if needed.
    ///
    /// The counterpart `loadData(with:)` will load the file with the given `UUID`.
    /// - Parameter source: the source url
    /// - Returns: uuid of the file to reference it
    public func copyFile(from source: URL) -> UUID? {
        let id = UUID()
        let dataPath = dataFolder.appendingPathComponent(id.uuidString)
        AppfroschLogger.shared.logToConsole(message: "Save path for new file is: \(dataPath.path)", type: .debug)
        
        do {
            try fileManager.copyItem(at: source, to: dataPath)
            return id
        } catch {
            AppfroschLogger.shared.logToConsole(message: error.localizedDescription, type: .error)
        }
        return nil
    }
    
    public func save(data: Data, with id: UUID) {
        let dataPath = dataFolder.appendingPathComponent(id.uuidString)
        do {
            try data.write(to: dataPath, options: [.atomic])
            AppfroschLogger.shared.logToConsole(message: "Saved data to \(dataPath.path)", type: .debug)
        } catch {
            AppfroschLogger.shared.logToConsole(message: "Error saving data to \(dataPath.path):", type: .error)
            AppfroschLogger.shared.logToConsole(message: error.localizedDescription, type: .error)
        }
    }
    
    
    //MARK: - Read
    /// Loads an instance of a given type from a specific filename.
    ///
    /// Use case: could be used to load a persisted currentObject of an application (e.g. a running timer).
    public func load<T: Codable>(of type: T.Type, from filename: String) -> T? {
        let path = docPath.appendingPathComponent(filename).appendingPathExtension("json")
        if fileManager.fileExists(atPath: path.path) {
            if let data = fileManager.contents(atPath: path.path) {
                do {
                    let instance = try decoderIso.decode(T.self, from: data)
                    AppfroschLogger.shared.logToConsole(message: "Loading instance of \(T.self) at \(path.path) successfully.", type: .debug)
                    return instance
                } catch {
                    AppfroschLogger.shared.logToConsole(message: "Loading instance of \(T.self) at \(path.path) failed: \(error)", type: .error)
                }
            }
        }
        return nil
    }
    
    /// Loads a file of type T from local storage.
    ///
    /// Use case: load content that could not be stored as UserDefault.
    /// - Returns: optional instance of generic type T
    public func load<T: Codable>(_ type: T.Type) -> T? {
        let pathFolder = docPath.appendingPathComponent(String(describing: type))
        if fileManager.fileExists(atPath: pathFolder.path) {
            var urls = [URL]()
            do {
                urls = try fileManager.contentsOfDirectory(at: pathFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not load content of directory: \(error)", type: .error)
                return nil
            }
            if urls.count == 1 {
                guard let url = urls.first else { fatalError() }
                if let data = fileManager.contents(atPath: url.path) {
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        AppfroschLogger.shared.logToConsole(message: "Could not decode data: \(error)", type: .error)
                        return nil
                    }
                }
            } else {
                AppfroschLogger.shared.logToConsole(message: "There was no file of type \(type) found.", type: .info)
                return nil
            }
        }
        return nil
    }
    
    ///Loads all files of a given type, decodes and returns an array of the type's instances.
    ///
    /// Used in case of one file per instance is used.
    ///
    ///# Usage of this method:
    ///
    ///See the __class documentation__ on the preliminaries and on how to use this method.
    ///
    ///- parameter type: The type which the instances are supposed to be loaded for
    ///- parameter subFolder: optional property that enables loading from a subfolder within the type's folder
    ///- returns: Array of all the instances of a given type stored locally
    ///
    public func loadAll<T: Codable & Identifiable>(of type: T.Type, in subFolder: String? = nil) -> [T] {
        var result = [T]()
        
        var pathFolder = docPath.appendingPathComponent(String(describing: type))
        if let subFolder = subFolder {
            pathFolder = pathFolder.appendingPathComponent(subFolder)
        }
        if fileManager.fileExists(atPath: pathFolder.path) {
            var urls = [URL]()
            do {
                urls = try fileManager.contentsOfDirectory(at: pathFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not load content of directory: \(error)", type: .error)
            }
            
            for url in urls {
                if let data = fileManager.contents(atPath: url.path) {
                    do {
                        if let instance = try? decoder.decode(T.self, from: data) {
                            result.append(instance)
                            continue
                        }
                        let instance = try decoderIso.decode(T.self, from: data)
                        result.append(instance)
                    } catch {
                        AppfroschLogger.shared.logToConsole(message: "Could not decode data of type \(type): \(error)", type: .error)
                    }
                }
            }
        }
        return result
    }
    
    /// Loads the one file of a given type, decodes its collection and returns an array of the type's instances.
    ///
    /// Used in case of one file per instance is used.
    ///
    /// # Usage of this method:
    ///
    /// See the __class documentation__ on the preliminaries and on how to use this method.
    ///
    ///- parameter type: The type which the instances are supposed to be loaded for,
    ///- returns: Array of all the instances of a given type stored locally
    ///
    public func loadCollection<T: Codable & Identifiable>(of type: T.Type) -> [T] {
        var result = [T]()
        
        let pathFolder = docPath.appendingPathComponent(String(describing: type)).appendingPathExtension("json")
        if fileManager.fileExists(atPath: pathFolder.path) {
            if let data = fileManager.contents(atPath: pathFolder.path) {
                do {
                    if let result = try? decoder.decode([T].self, from: data) {
                        return result
                    }
                    //Try with iso-Date decoder (in case the non-iso date format is a problem
                    result = try decoderIso.decode([T].self, from: data)
                    
                } catch {
                    AppfroschLogger.shared.logToConsole(message: "Could not decode collection data: \(error)", type: .error)
                }
            }
        }
        return result
    }
    
    /// Loads an image by its name, the name being the `id` of the instance connected with the image if found.
    ///
    /// Requires UIKit, which is not running on macOS
    ///
    /// Requirement: the image has been previously stored in `Documents/images`.
    /// - Parameter id: UUID of the instance the picture is connected with
    /// - Returns: picture if found, nil if not
    #if os(iOS)
    public func loadImage(with id: UUID) -> UIImage? {
        let imagePath = getImagePath(for: id)
        if fileManager.fileExists(atPath: imagePath.path) {
            if let imageData = fileManager.contents(atPath: imagePath.path) {
                if let image = UIImage(data: imageData) {
                    return image
                }
            }
        }
        return nil
    }
    #else
    public func loadImage(with id: UUID) -> NSImage? {
        let imagePath = getImagePath(for: id)
        if fileManager.fileExists(atPath: imagePath.path) {
            if let imageData = fileManager.contents(atPath: imagePath.path) {
                if let image = NSImage(data: imageData) {
                    return image
                }
            }
        }
        return nil
    }
    #endif
    
    
    /// Cross-platform implementation to load an image from disk.
    /// - Parameter id: the image's uuid
    /// - Returns: optional image
    public func loadCIImage(with id: UUID) -> CIImage? {
        let imagePath = getImagePath(for: id).path()
        if fileManager.fileExists(atPath: imagePath) {
            if let imageData = fileManager.contents(atPath: imagePath) {
                if let image = CIImage(data: imageData) {
                    return image
                }
            }
        }
        return nil
    }
    
    public func loadCGImage(with id: UUID) -> CGImage? {
        if let ciImage = loadCIImage(with: id) {
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                return cgImage
            }
        }
        return nil
    }
    
    
    /// Loads data with a given `UUID`.
    ///
    /// Counterpart to `copyFile(from:)`.
    /// - Parameter id: the `UUID` of the local data that's to get loaded
    /// - Returns: returns the data, if the file with the given id exists or `nil`, if it does not
    public func loadData(with id: UUID) -> Data? {
        let dataPath = dataFolder.appendingPathComponent(id.uuidString)
        if fileManager.fileExists(atPath: dataPath.path) {
            let data = fileManager.contents(atPath: dataPath.path)
            return data
        }
        return nil
    }
    
    //MARK: - Update
    public func update<T: Codable & Identifiable>(instance: T) {
        delete(instance: instance)
        save(instance: instance)
    }
    
    //MARK: - Deleting
    /// Deletes the folder for this instance or its subfolder.
    ///
    ///Use case: when (re-)saving a collection of items, this method can get called prior to saving the collections instances, that might have gotten reduced.
    ///```swift
    ///  @Published var timedEvents: [TimedEvent] {
    ///  willSet {
    ///      //Reset the save folder explicitly prior to saving to make sure that only current items remain in persistence
    ///      if let instance = timedEvents.first {
    ///          persistence.resetSaveFolder(of: instance)
    ///      }
    ///  }
    ///  didSet {
    ///      persistence.save(collection: timedEvents) }
    ///  }
    ///```
    ///
    /// - Parameters:
    ///   - instance: the instance whose type's folder or subfolder is to be deleted
    ///   - subFolder: optional subfolder for the type folder of this instance
    public func resetSaveFolder<T: Codable & Identifiable>(of type: T.Type, in subFolder: String? = nil) {
        var pathFolder = docPath.appendingPathComponent(String(describing: T.self))
        if let subFolder = subFolder {
            pathFolder = pathFolder.appendingPathComponent(subFolder)
        }
        if fileManager.fileExists(atPath: pathFolder.path) {
            do {
                try fileManager.removeItem(at: pathFolder)
            } catch {
                print(error)
            }            
        }
    }
    
    /// Deletes the persisted representation of an instance. That instance must be stored in the filesystem following the naming convention `<instanceId>.json`.
    /// - Parameter instance: the instance that's supposed to be deleted.
    public func delete<T: Codable & Identifiable>(instance: T) {
        let pathFolder = docPath.appendingPathComponent(String(describing: T.self))
        let path = pathFolder.appendingPathComponent(String(describing: instance.id)).appendingPathExtension("json")
        if fileManager.fileExists(atPath: path.path) {
            do {
                try fileManager.removeItem(at: path)
                AppfroschLogger.shared.logToConsole(message: "Deleted instance of \(T.self) with id \(instance.id) successfully.", type: .debug)
            } catch {
                AppfroschLogger.shared.logToConsole(message: "Could not delete file", type: .error)
            }
        } else {
            AppfroschLogger.shared.logToConsole(message: "Could not delete file because it does not exist.", type: .error)
        }
    }
    
    /// Deletes the persisted image. That instance must be stored in the filesystem following the naming convention `uuid`.
    /// - Parameter id: the image id for the image  that's supposed to be deleted.
    public func deleteImage(with id: UUID) {
        let imagePath = imageFolder.appendingPathComponent(id.uuidString)
        if fileManager.fileExists(atPath: imagePath.path) {
            do {
                try fileManager.removeItem(at: imagePath)
                AppfroschLogger.shared.logToConsole(message: "Deleted image with id \(id) successfully.", type: .debug)
        } catch {
            AppfroschLogger.shared.logToConsole(message: "Could not delete image", type: .error)
            }
        } else {
            AppfroschLogger.shared.logToConsole(message: "Could not delete image because it does not exist.", type: .error)
        }
    }
    
    //MARK: Helper Files
    private func getImagePath(for id: UUID) -> URL {
        imageFolder.appending(path: id.uuidString)
    }
}
