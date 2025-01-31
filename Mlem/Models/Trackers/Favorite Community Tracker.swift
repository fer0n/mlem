//
//  Favorites Tracker.swift
//  Mlem
//
//  Created by David Bureš on 16.05.2023.
//

import Combine
import Dependencies
import Foundation

@MainActor
class FavoriteCommunitiesTracker: ObservableObject {
    
    @Dependency(\.persistenceRepository) var persistenceRepository
    
    @Published var favoriteCommunities: [FavoriteCommunity] = .init()
    private var updateObserver: AnyCancellable?

    init() {
        self.favoriteCommunities = persistenceRepository.loadFavoriteCommunities()
        self.updateObserver = $favoriteCommunities.sink { [weak self] value in
            Task {
                try await self?.persistenceRepository.saveFavoriteCommunities(value)
            }
        }
    }
    
    func favoriteCommunities(for account: SavedAccount) -> [APICommunity] {
        favoriteCommunities
            .filter { $0.forAccountID == account.id }
            .map { $0.community }
            .sorted()
    }
    
    func favorite(_ community: APICommunity, for account: SavedAccount) {
        let newFavorite = FavoriteCommunity(forAccountID: account.id, community: community)
        favoriteCommunities.append(newFavorite)
    }
    
    func unfavorite(_ community: APICommunity) {
        favoriteCommunities.removeAll(where: { $0.community.id == community.id })
    }
}
