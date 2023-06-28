//
//  File.swift
//  
//
//  Created by Andreas Seeger on 07.01.21.
//

import Foundation

//MARK: Class Documentation
///Generic, singleton class to persist instances locally as json files.
///
///Use the static functions on this class.
///
///The instance of a struct or a class using this __must__ conform to `Codable`
///which is why iOS13 is required.
public class AppfroschUserDefaults {
    ///Making the init private prevents creating an instance.
    private init() {}
    
    ///A handle to the standard user default
    private static let userDef = UserDefaults.standard
    
    ///Saves an instance to user defaults.
    ///
    /// - parameter instance: the instance that is to be saved to user defaults
    /// - parameter key: the key the instance is to be stored with
    public static func saveToUserDefaults<T: Encodable>(instance: T, withKey key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(instance) {
            userDef.setValue(data, forKey: key)
        }
    }
    
    ///Loads an instance from user defaults.
    ///
    /// - parameter type: the instance that is to be loaded from user defaults
    /// - parameter key: the key the instance has been stored with
    /// - returns: an instance of the type `T`, if available or `nil` if not
    public static func loadFromUserDefaults<T: Decodable>(type: T.Type, forKey key: String) -> T? {
        let decoder = JSONDecoder()
        if let data = userDef.object(forKey: key) as? Data,
           let object = try? decoder.decode(T.self, from: data) {
            return object
        }
        return nil
    }
}
