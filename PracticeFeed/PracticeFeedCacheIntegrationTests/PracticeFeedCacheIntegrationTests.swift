//
//  PracticeFeedCacheIntegrationTests.swift
//  PracticeFeedCacheIntegrationTests
//
//  Created by Chowdhury Md Rajib Sarwar on 12/4/24.
//

import XCTest
import PracticeFeed

final class PracticeFeedCacheIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        deletestoreArtifact()
    }
    
    override func tearDown() {
        super.tearDown()
        deletestoreArtifact()
    }
    
    func test_load_deliversNoItemOnEmptyCache() {
        let sut = makeSUT()
        expect(sut, toLoad: [])
    }
    
    func test_load_deliversItemsSavedOnASeparateInstance() {
        let sutToPerformSave = makeSUT()
        let sutToPerformLoad = makeSUT()
        let feed = uniqueImageFeed().models
        
        save(feed, with: sutToPerformSave)
        
        expect(sutToPerformLoad, toLoad: feed)
    }
    
    func test_load_overrridesItemsSavedOnASeparateInstance() {
        let sutToPerformFirstSave = makeSUT()
        let sutToPerformLastSave = makeSUT()
        let sutToPerformLoad = makeSUT()
        let firstFeed = uniqueImageFeed().models
        let latestFeed = uniqueImageFeed().models
        
        save(firstFeed, with: sutToPerformFirstSave)
        save(latestFeed, with: sutToPerformLastSave)
        
        expect(sutToPerformLoad, toLoad: latestFeed)
    }
    

    // MARK: Helpers
    
    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> LocalFeedLoader {
        let storeBundle = Bundle(for: CoreDataFeedStore.self)
        let storeURL = testSpecificStoreURL
        let store = try! CoreDataFeedStore(storeURL: storeURL)
        let sut = LocalFeedLoader(store: store, currentDate: Date.init)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    func save(_ feed: [FeedImage], with loader: LocalFeedLoader, file: StaticString = #file, line: UInt = #line) {
        let saveExp = expectation(description: "Wait for save completion")
        loader.save(feed) { result in
            if case let Result.failure(error) = result {
                XCTAssertNil(error, "Expected to save feed successfully")
            }
            saveExp.fulfill()
        }
        wait(for: [saveExp], timeout: 1.0)
    }
    
    func expect(_ sut: LocalFeedLoader, toLoad expectedFeed: [FeedImage], file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Wait for cache retrieval")
        sut.load { result in
            switch result {
            case let .success(imageFeed):
                XCTAssertEqual(imageFeed, expectedFeed, "Expected empty feed")
                 
            case let .failure(error):
                XCTFail("Expected successful feed result, got \(error) instead")
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    private func setupEmptyStoreState() {
        deletestoreArtifact()
    }
    
    private func undoStoreSideEffects() {
        deletestoreArtifact()
    }
    
    private func deletestoreArtifact() {
        try? FileManager.default.removeItem(at: testSpecificStoreURL)
    }
    
    private var testSpecificStoreURL: URL {
        return FileManager.default.urls(for: .cachesDirectory,
                                        in: .userDomainMask).first!.appendingPathComponent("\(type(of: self )).store")
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory,
                                        in: .userDomainMask).first!
    }
}
