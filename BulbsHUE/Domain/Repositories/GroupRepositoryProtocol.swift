//
//  GroupRepositoryProtocol.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 15.08.2025.
//

import Foundation
import Combine

// MARK: - Group Repository Protocol
protocol GroupRepositoryProtocol {
    // MARK: - Read Operations
    func getAllGroups() -> AnyPublisher<[GroupEntity], Error>
    func getGroup(by id: String) -> AnyPublisher<GroupEntity?, Error>
    func getGroupsByType(_ type: GroupEntity.GroupType) -> AnyPublisher<[GroupEntity], Error>
    
    // MARK: - Write Operations
    func updateGroupState(id: String, isOn: Bool, brightness: Double?) -> AnyPublisher<Void, Error>
    func createGroup(name: String, lightIds: [String], type: GroupEntity.GroupType) -> AnyPublisher<GroupEntity, Error>
    func updateGroup(_ group: GroupEntity) -> AnyPublisher<Void, Error>
    func deleteGroup(id: String) -> AnyPublisher<Void, Error>
    func addLightToGroup(groupId: String, lightId: String) -> AnyPublisher<Void, Error>
    func removeLightFromGroup(groupId: String, lightId: String) -> AnyPublisher<Void, Error>
    
    // MARK: - Reactive Streams
    var groupsStream: AnyPublisher<[GroupEntity], Never> { get }
    func groupStream(for id: String) -> AnyPublisher<GroupEntity?, Never>
}
