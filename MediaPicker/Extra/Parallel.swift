//
//  Parallel.swift
//  Talnts
//
//  Created by Mikhail Stepkin on 30.07.15.
//  Copyright (c) 2015 Ramotion. All rights reserved.
//

import Foundation

enum QueuePriority {
    
    case Main
    
    case Background
    case Low
    case Default
    case High
    
}

enum SyncType {
    
    case Sync
    case Async
    
}

func parallel(type: SyncType, priority: QueuePriority, closure:() -> Void) {
    
    let queue: dispatch_queue_t
    switch priority {
    case .Main:
        queue = dispatch_get_main_queue()
        
    case .Background:
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
    case .Low:
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
    case .Default:
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    case .High:
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
    }
    
    switch type {
    case .Sync:
        dispatch_sync(queue, closure)
    case .Async:
        dispatch_async(queue, closure)
    }
    
}

func sync(priority: QueuePriority, closure:() -> Void) {
    parallel(SyncType.Sync, priority: priority, closure: closure)
}

func async(priority: QueuePriority, closure:() -> Void) {
    parallel(SyncType.Async, priority: priority, closure: closure)
}

func syncWith(object: AnyObject, @noescape closure: () -> Void) {
    objc_sync_enter(object)
    closure()
    objc_sync_exit(object)
}

func syncWith<T>(object: AnyObject, @noescape closure: () -> T) -> T {
    objc_sync_enter(object)
    let x = closure()
    objc_sync_exit(object)
    return x
}

func asyncWith(object: AnyObject, priority: QueuePriority, closure:() -> Void) {
    async(priority) {
        objc_sync_enter(object)
        closure()
        objc_sync_exit(object)
    }
}

extension NSObject {
    
    func synced(@noescape closure: () -> Void) {
        syncWith(self, closure: closure)
    }
    
    func synced<T>(@noescape closure: () -> T) -> T {
        return syncWith(self, closure: closure)
    }
    
}