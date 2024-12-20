//
//  FeedImageViewModel.swift
//  PracticeFeediOS
//
//  Created by Chowdhury Md Rajib Sarwar on 12/18/24.
//

import PracticeFeed

final class FeedImageViewModel<Image> {
    typealias Observer<T> = (T) -> Void
    
    private var task: FeedImageDataLoaderTask?
    private let model: FeedImage
    private let imageLoader: FeedImageDataLoader
    private let imageTransformer: (Data) -> Image?
    
    init(model: FeedImage, imageLoader: FeedImageDataLoader, imageTransformer: @escaping (Data) -> Image?) {
        self.model = model
        self.imageLoader = imageLoader
        self.imageTransformer = imageTransformer
    }
    
    var description: String? {
        return model.description
    }
    
    var location: String? {
        return model.location
    }
    
    var hasLocation: Bool {
        return location != nil
    }

    var onImageLoad: Observer<Image>?
    var onImageLoadingStateChange: Observer<Bool>?
    var onShouldTryImageLoadStateChange: Observer<Bool>?
    
    func loadeImageData() {
        onImageLoadingStateChange?(true)
        onShouldTryImageLoadStateChange?(false)
        task = self.imageLoader.loadImageData(from: self.model.url) {  [weak self] result in
            self?.handle(result)
        }
    }
    
    func handle(_ result: FeedImageDataLoader.Result) {
        if let image = (try? result.get()).flatMap(imageTransformer){
            onImageLoad?(image)
        } else {
            onShouldTryImageLoadStateChange?(true)
        }
        onImageLoadingStateChange?(false)
    }
    
    func cancelImageDataLoad() {
        task?.cancel()
    }
}
