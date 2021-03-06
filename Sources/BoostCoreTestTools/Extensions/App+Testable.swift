//
//  App+Testable.swift
//  BoostCoreTestTools
//
//  Created by Ondrej Rafaj on 05/03/2018.
//

import Foundation
import ApiCore
import Vapor
import Fluent
@testable import BoostCore
import VaporTestTools


extension TestableProperty where TestableType == App {
    
    @discardableResult public static func create(team: Team, name: String, identifier: String? = nil, version: String, build: String, platform: App.Platform, on app: Application) -> App {
        let req = app.testable.fakeRequest()
        let identifier = (identifier ?? name.safeText)
        let cluster = Cluster.testable.guaranteedCluster(identifier: identifier, platform: platform, on: app)
        cluster.teamId = team.id!
        let object = App(teamId: team.id!, clusterId: cluster.id!, name: name, identifier: identifier, version: version, build: build, platform: platform, size: 5000, sizeTotal: 5678)
        cluster.appCount += 1
        _ = try! cluster.add(app: object, on: req).wait()
        return try! object.save(on: req).wait()
    }
    
    public func addTag(name: String, team: Team, identifier: String, on app: Application) {
        let req = app.testable.fakeRequest()
        let tag = try! Tag(teamId: team.id!, identifier: "tag-for-app-2").save(on: req).wait()
        _  = try! element.tags.attach(tag, on: req).wait()
    }
    
}

