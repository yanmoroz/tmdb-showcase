//
//  MoviesCall.swift
//  SharedKit
//
//  Created by Yan Moroz on 31.08.2026.
//

import DomainKit
import Foundation

/// A `MoviesRepository.movies(query:page:)` call recorded by the stub.
public struct MoviesCall: Hashable, Sendable {
    public let query: MoviesQuery
    public let page: Int

    public init(query: MoviesQuery, page: Int) {
        self.query = query
        self.page = page
    }
}
