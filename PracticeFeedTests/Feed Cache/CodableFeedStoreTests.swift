//
//  CodableFeedStoreTests.swift
//  PracticeFeedTests
//
//  Created by Chowdhury Md Rajib Sarwar on 11/20/24.
//

import XCTest
import PracticeFeed

class CodableFeedStore {
    private struct Cache: Codable {
        let feed: [CodableFeedImage]
        let timestamp: Date
        
        var localFeed: [LocalFeedImage] {
            return feed.map { $0.local }
        }
    }
    
    private struct CodableFeedImage: Codable {
        private let id: UUID
        private let description: String?
        private let location: String?
        private let url: URL
        
        init(_ image: LocalFeedImage) {
            id = image.id
            description = image.description
            location = image.location
            url = image.url
        }
        
        var local: LocalFeedImage {
            return LocalFeedImage(id: id, description: description, location: location, url: url)
        }
    }
    
    private let storeURL: URL
    
    init(storeURL: URL) {
        self.storeURL = storeURL
    }
    
    func retrieve(completion: @escaping FeedStore.RetrievalCompletion) {
        guard let data = try? Data(contentsOf: storeURL) else {
            return completion(.empty)
        }
        
        let decoder = JSONDecoder()
        let cache = try! decoder.decode(Cache.self, from: data)
        completion(.found(feed: cache.localFeed, timestamp: cache.timestamp))
    }
    
    func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping FeedStore.InsertionCompletion) {
        let encoder = JSONEncoder()
        let cache = Cache(feed: feed.map(CodableFeedImage.init), timestamp: timestamp)
        let encoded = try! encoder.encode(cache)
        try! encoded.write(to: storeURL)
        completion(nil)
    }
}

class CodableFeedStoreTests: XCTestCase {
   
    override func setUp() {
        super.setUp()
        
        setupEmptyStoreState()
    }
    
    override func tearDown() {
        super.tearDown()
        
        undoStoreSideEffects()
    }
    
    func test_retrieve_deliverEmptyOnEmptyCache() {
        let sut = makeSUT()
        
        expect(sut, toRetrieve: .empty)
    }
    
    func test_retrieve_hasNoSideEffectOnEmptyCache() {
        let sut = makeSUT()
        let exp = expectation(description: "Wait for cache retrieval")
        sut.retrieve { firstResult in
            sut.retrieve { secondResult in
                switch (firstResult, secondResult) {
                case (.empty, .empty):
                    break
                default:
                    XCTFail("Expected retrieving twice from empty cache to deliver same empty result, got \(firstResult) ans \(secondResult) instead")
                }
                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_retrieveAfterInsertingToEmptyCache_deliversInsertedValues() {
        let sut = makeSUT()
        let feed = uniqueImageFeed().local
        let timestamp = Date()
        
        let exp = expectation(description: "Wait for cache retrieval")
        sut.insert(feed, timestamp: timestamp) { insertionEror in
            XCTAssertNil(insertionEror, "Expected feed to be inserted successfully")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        expect(sut, toRetrieve: .found(feed: feed, timestamp: timestamp))
    }
    
    func test_retrieve_hasNoSideEffectOnNonEmptyCache () {
        let sut = makeSUT()
        let feed = uniqueImageFeed().local
        let timestamp = Date()
        let exp = expectation(description: "Wait for cache retrieval")
        sut.insert(feed, timestamp: timestamp) { insertionEror in
            XCTAssertNil(insertionEror, "Expected feed to be inserted successfully")
            
            sut.retrieve { firstResult in
                sut.retrieve { secondResult in
                    switch (firstResult, secondResult) {
                    case let (.found(firstFound), .found(secondFound)):
                        XCTAssertEqual(firstFound.feed, feed)
                        XCTAssertEqual(firstFound.timestamp, timestamp)
                        
                        XCTAssertEqual(secondFound.feed, feed)
                        XCTAssertEqual(secondFound.timestamp, timestamp)
                    default:
                        XCTFail("Expected retrieving twice from non empty cache to deliver same found result with feed \(feed) and timestamp \(timestamp), got \(firstResult) and \(secondResult) instead")
                    }
                    exp.fulfill()
                }
            }
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    // MARK: Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> CodableFeedStore {
        let sut = CodableFeedStore(storeURL: testSpecificStoreURL)
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func expect(_ sut: CodableFeedStore, toRetrieve expectedResult: RetrieveCacheFeedResult, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait for cache retrieval")
        sut.retrieve { retrieveResult in
            switch (expectedResult, retrieveResult) {
            case (.empty, .empty):
                break
                
            case let (.found(expected), .found(retrieved)):
                XCTAssertEqual(retrieved.feed, expected.feed)
                XCTAssertEqual(retrieved.timestamp, expected.timestamp)
            default:
                XCTFail("Expected to retrieve \(expectedResult), got \(retrieveResult) instead")
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
}
