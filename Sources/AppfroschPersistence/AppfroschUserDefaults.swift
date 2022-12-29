//
//  File.swift
//  
//
//  Created by Andreas Seeger on 07.01.21.
//

import Foundation

public class AppfroschUserDefaults {
    private init() {}
    
    private static let userDef = UserDefaults.standard
    
    public static func saveToUserDefauls<T: Encodable>(instance: T, withKey key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(instance) {
            userDef.setValue(data, forKey: key)
        }
    }
    
    public static func loadFromUserDefaults<T: Decodable>(type: T.Type, forKey key: String) -> T? {
        let decoder = JSONDecoder()
        if let data = userDef.object(forKey: key) as? Data,
           let object = try? decoder.decode(T.self, from: data) {
            return object
        }
        
        return nil
    }
}
