//
//  BoostCoreBase.swift
//  BoostCore
//
//  Created by Ondrej Rafaj on 12/12/2017.
//

import Foundation
import Vapor
import ApiCore
import ErrorsCore
import Fluent
import FluentPostgreSQL
import SettingsCore
import MailCore


/// Base class for BoostCore
public class BoostCoreBase {
    
    /// Registered controllers
    static var controllers: [Controller.Type] = [
        BoostController.self,
        TagsController.self,
        AppsController.self,
        UploadKeyController.self,
        ConfigurationController.self
    ]
    
    /// Private temp file handler
    private static var _tempFileHandler: FileHandler?
    
    /// Temp file handler
    public static var tempFileHandler: FileHandler {
        get {
            if let handler = _tempFileHandler {
                return handler
            }
            let handler = LocalFileHandler()
            _tempFileHandler = handler
            return handler
        }
        set {
            _tempFileHandler = newValue
        }
    }
    
    /// Configuration cache
    static var _configuration: BoostCore.Configuration?
    
    /// Main system configuration
    public static var configuration: BoostCore.Configuration {
        get {
            if _configuration == nil {
                // TODO: Fix following!!!!!!!!!!!!!!!!!!
//                do {
//                    guard let path = Environment.get("CONFIG_PATH") else {
//                        let conf = try BoostCore.Configuration.load(fromFile: "config.default.json")
//                        conf.loadEnv()
//                        _configuration = conf
//                        return conf
//                    }
//                    let conf = try BoostCore.Configuration.load(fromFile: path)
//                    // Override any properties with ENV
//                    conf.loadEnv()
//                    _configuration = conf
//                    return conf
//                } catch {
//                    if let error = error as? DecodingError {
//                        // Should config exist but is invalid, crash
//                        fatalError("Invalid configuration file: \(error.reason)")
//                    } else {
                        // Create default configuration
                        _configuration = BoostCore.Configuration(
                            storage: Configuration.Storage(
                                rootTempPath: "tmp",
                                appDestinationPath: "apps"
                            )
                        )
                
//                    }
                        // Override any properties with ENV
                        _configuration?.loadEnv()
//                }
            }
            guard let configuration = _configuration else {
                fatalError("Configuration couldn't be loaded!")
            }
            return configuration
        }
    }
    
    /// Main Vapor configuration method
    public static func configure(_ config: inout Vapor.Config, _ env: inout Vapor.Environment, _ services: inout Services) throws {        
        // Add BoostCore models to the migrations
        ApiCoreBase.add(model: Cluster.self, database: .db)
        ApiCoreBase.add(model: App.self, database: .db)
        ApiCoreBase.add(model: DownloadKey.self, database: .db)
        ApiCoreBase.add(model: Tag.self, database: .db)
        ApiCoreBase.add(model: AppTag.self, database: .db)
        ApiCoreBase.add(model: UploadKey.self, database: .db)
        ApiCoreBase.add(model: Config.self, database: .db)
        ApiCoreBase.add(model: Download.self, database: .db)
        
        // Register controllers
        for c in controllers {
            ApiCoreBase.controllers.append(c)
        }
        
        // Setup SettingsCore
        try SettingsCoreBase.configure(&config, &env, &services)
        
        // Setup ApiCore
        try ApiCoreBase.configure(&config, &env, &services)
        ApiCoreBase.installFutures.append({ req in
            return try Install.make(on: req)
        })
        
        // Verify all has been setup properly
        
        FlightCheck.tick()
    }
    
}
