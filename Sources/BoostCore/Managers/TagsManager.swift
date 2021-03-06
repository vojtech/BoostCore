//
//  TagsManager.swift
//  BoostCore
//
//  Created by Ondrej Rafaj on 3/10/2018.
//

import Foundation
import Vapor
import ApiCore
import ErrorsCore
import Fluent
import FluentPostgreSQL
import DatabaseKit
import SQL


public class TagsManager {
    
    /// Save an array of tags on an app
    public static func save(tags: [String], for app: App, team: Team, on req: Request) throws -> Future<Void> {
        guard let teamId = team.id else {
            throw ErrorsCore.HTTPError.missingId
        }
        return try app.tags.query(on: req).all().flatMap(to: Void.self) { appTags in
            var futures: [Future<Void>] = []
            tags.forEach { tagSubstring in
                let tag = String(tagSubstring).safeTagText
                guard !appTags.contains(identifier: tag) else {
                    return
                }   
                let future = Tag.query(on: req).filter(\Tag.identifier == tag).filter(\Tag.teamId == teamId).first().flatMap(to: Void.self) {  tagObject in
                    guard let tagObject = tagObject else {
                        let t = Tag(id: nil, teamId: teamId, identifier: tag)
                        return t.save(on: req).flatMap(to: Void.self) { tag in
                            return app.tags.attach(tag, on: req).flatten()
                        }
                    }
                    return app.tags.attach(tagObject, on: req).flatten()
                }
                futures.append(future)
            }
            return futures.flatten(on: req)
        }
    }
    
    /// Unsecured tags for an app
    public static func tags(app: App, on req: Request) throws -> Future<Tags> {
        return try app.tags.query(on: req).all()
    }
    
    /// Secured apps for a tag
    public static func tags(appId: DbIdentifier, on req: Request) throws -> Future<Tags> {
        return try req.me.teams().flatMap(to: Tags.self) { teams in
            return try App.query(on: req).safeApp(appId: appId, teamIds: teams.ids).first().flatMap(to: Tags.self) { app in
                guard let app = app else {
                    throw ErrorsCore.HTTPError.notFound
                }
                return try tags(app: app, on: req)
            }
        }
    }
    
    public static func delete(tag: Tag, on req: Request) throws -> Future<Void> {
        return try tag.apps.query(on: req).count().flatMap(to: Void.self) { count in
            let delete = AppTag.query(on: req).filter(\AppTag.tagId == tag.id!).delete()
            guard count == 1 else {
                return delete
            }
            return delete.flatMap(to: Void.self) { _ in
                return tag.delete(on: req)
            }
        }
    }
    
    public static func delete(tagId: DbIdentifier, appId: DbIdentifier, on req: Request) throws -> Future<Void> {
        return Tag.query(on: req).filter(\Tag.id == tagId).first().flatMap(to: Void.self) { tag in
            guard let tag = tag else {
                throw ErrorsCore.HTTPError.notFound
            }
            return try req.me.teams().flatMap(to: Void.self) { teams in
                return try App.query(on: req).safeApp(appId: appId, teamIds: teams.ids).first().flatMap(to: Void.self) { app in
                    guard let _ = app else {
                        throw ErrorsCore.HTTPError.notFound
                    }
                    return try delete(tag: tag, on: req)
                }
            }
        }
    }
    
    public static func tags(identifiers: [String] = [], team: Team? = nil, on req: Request) throws -> Future<[String]> {
        func search(q: inout Fluent.QueryBuilder<PostgreSQLDatabase, Tag>, identifiers: [String]) {
            if !identifiers.isEmpty {
                q.group(.or) { q in
                    identifiers.forEach({ i in
                        q.filter(\Tag.identifier ~~ i)
                    })
                }
            }
            _ = q.sort(\Tag.identifier, .ascending)
            // TODO: Fix!!!!!!!!!
//            _ = q.groupBy(\Tag.identifier)
        }
        
        if let team = team, let teamId = team.id { // Search only tags attached to a specific team
            var q = Tag.query(on: req).filter(\Tag.teamId == teamId)
            search(q: &q, identifiers: identifiers)
            let tags: Future<Tags> = q.all()
            return tags.map(to: [String].self) { tags in
                let t: [String] = tags.map({ $0.identifier })
                // TODO: Fix using SQL!!!!!!!!!
                return Array(Set<String>(t)).sorted()
            }
        } else { // Search for all tags for user
            return try req.me.teams().flatMap(to: [String].self) { teams in
                var q = Tag.query(on: req).filter(\Tag.teamId ~~ teams.ids)
                // TODO: Refactor following duplicate code
                search(q: &q, identifiers: identifiers)
                let tags: Future<Tags> = q.all()
                return tags.map(to: [String].self) { tags in
                    let t: [String] = tags.map({ $0.identifier })
                    // TODO: Fix using SQL!!!!!!!!!
                    return Array(Set<String>(t)).sorted()
                }
            }
        }
    }
    
}
