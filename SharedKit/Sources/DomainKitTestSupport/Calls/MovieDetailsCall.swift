//
//  MovieDetailsCall.swift
//  SharedKit
//
//  Created by Yan Moroz on 31.08.2026.
//

import DomainKit
import Foundation

/// A `MoviesRepository.movieDetails(id:)` call recorded by the stub.
public struct MovieDetailsCall: Hashable, Sendable {
    public let id: Movie.ID

    public init(id: Movie.ID) {
        self.id = id
    }
}
