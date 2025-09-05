//
//  TypeCellData.swift
//  BulbsHUE
//
//  Created by Anton Reasin on 18.08.2025.
//

import SwiftUI

// MARK: - Протокол для данных ячейки типа
protocol TypeCellData {
    associatedtype SubtypeType
    
    var name: String { get }
    var iconName: String { get }
    var iconWidth: CGFloat { get }
    var iconHeight: CGFloat { get }
    var subtypes: [SubtypeType] { get }
}

// MARK: - Протокол для подтипов
protocol SubtypeCellData {
    var id: UUID { get }
    var name: String { get }
    var iconName: String { get }
}

// MARK: - Протокол для менеджера типов
protocol TypeManager: AnyObject, Observable {
    associatedtype SubtypeType: SubtypeCellData
    
    var selectedSubtype: UUID? { get set }
    var hasSelection: Bool { get }
    
    func selectSubtype(_ subtype: SubtypeType)
    func isSubtypeSelected(_ subtype: SubtypeType) -> Bool
    func getSelectedSubtype() -> SubtypeType?
    func clearSelection()
}

// MARK: - Расширения для существующих типов
extension BulbType: TypeCellData {
    typealias SubtypeType = LampSubtype
}

extension LampSubtype: SubtypeCellData {}

extension BulbTypeManager: TypeManager {
    typealias SubtypeType = LampSubtype
}

extension RoomCategory: TypeCellData {
    typealias SubtypeType = RoomSubtype
}

extension RoomSubtype: SubtypeCellData {}

extension RoomCategoryManager: TypeManager {
    typealias SubtypeType = RoomSubtype
}
