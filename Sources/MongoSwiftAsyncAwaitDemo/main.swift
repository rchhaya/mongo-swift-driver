#if compiler(>=5.5) && canImport(_Concurrency)
import Dispatch
import MongoSwift
import NIO

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 2)
defer {
    try? elg.syncShutdownGracefully()
}

func main() async throws {
    let client = try MongoClient(using: elg)
    let db = client.db("asyncTestDB")
    try await db.drop()

    print("created client")
    let opts = CreateCollectionOptions(capped: true, max: 3, size: 1000)
    let coll = try await client.db("asyncTestDB").createCollection("test", options: opts)
    print("created coll")
    let result = try await coll.insertMany([["x": 1], ["x": 2], ["x": 3]])
    print("Inserted IDs: \(result!.insertedIDs)")

    let cursorTask = Task {
        let cursor = try await coll.find(options: FindOptions(cursorType: .tailable))
        while let doc = try await cursor.next() {
            print("found document: \(doc)")
        }
        // for try await doc in try await coll.find(options: FindOptions(cursorType: .tailable)) {
        //     print("found document: \(doc)")
        // }
    }

    try await Task.sleep(nanoseconds: 30_000_000_000)
    cursorTask.cancel()

    try await coll.drop()
    try await client.close()
}

let dg = DispatchGroup()
dg.enter()
let task = Task.detached {
    do {
        try await main()
        print("success!")
    } catch {
        print("failed! \(error)")
    }
    dg.leave()
}
dg.wait()

#endif
