# Implementation notes

> **About this note.** This note was written by Claude (Anthropic's AI assistant) at the request of the author of ImageMap, who wants to read it at their own pace and learn from it: how the object memory of a Pharo image is organised, and how ImageMap looks at it. The author is still studying the subject and has not yet checked all of it, so please read it as study material and not as an authoritative description of the Spur memory manager. Parts may be wrong or out of date; the VM documentation in [Further reading](#further-reading) is the reference. In the text below, "I" is Claude. Like the code, the note is experimental: see the status note in the [README](../README.md).

How ImageMap looks at the object memory of a running Pharo image, and the logic behind the three views. This is a short orientation, not a description of the VM. For the VM itself, follow the links in [Further reading](#further-reading).

Everything below was checked against GT v1.1.624 (Pharo 13.1, 64-bit Spur, Windows). Statements about the VM that I took from the literature and did not check in the image are marked *(literature)*.

## 1. Object memory in a Pharo 13 / GT image, in outline

GT runs on the Pharo VM (a Cog VM with the Cogit JIT). Its object memory is **Spur** (`SpurMemoryManager`), here in its 64-bit form. Only the parts that matter for ImageMap are listed.

**Objects.** Every heap object starts with an 8-byte header followed by its slots. The header holds, among other fields, a **class index** (not a class pointer), a **format** that says whether the slots are pointers, bytes, words, weak, a compiled method and so on, an identity hash, and a slot count. When an object has 255 or more slots, an extra 8-byte word in front of the header holds the real slot count. Objects are 8-byte aligned and the smallest object is 16 bytes. *(literature)*

You can see the size rules from the image, because `sizeInMemory` follows them:

| Object | `basicSize` | `sizeInMemory` |
|---|---|---|
| `Object new` | 0 | 16 (minimum) |
| `Array new: 1` | 1 | 16 |
| `Array new: 2` | 2 | 24 (8 + 2 x 8) |
| `Array new: 254` | 254 | 2040 (8 + 254 x 8) |
| `Array new: 255` | 255 | 2056 (extra 8-byte overflow word) |
| `ByteArray new: 8` | 8 | 16 |
| `ByteArray new: 9` | 9 | 24 (rounded up to 8) |

**Immediates.** `SmallInteger`, `Character` and `SmallFloat64` are not objects in the heap: the value sits in the reference itself (`isImmediateClass` is true for them). They never appear in a heap walk, and `sizeInMemory` answers 0 for them. A `Float` that does not fit (`1.0e300`) is a `BoxedFloat64` and is a heap object.

**Spaces.** *(literature)* The heap has a **new space**, split into eden (5/7), past and future (1/7 each), and an **old space** made of segments. The segments are linked by *bridges*, which are fake pinned objects that tools must not read. Bridges do not show up in `allInstances` or `allObjects`. New objects are born in eden. A scavenge copies the survivors to the other survivor space and promotes the long-lived ones to old space. A full collection works on old space too. A remembered set records old-to-new references so that a scavenge does not have to scan old space.

**What this means for a map.** Objects move: a scavenge copies, a full GC may compact, and a promotion changes where an object lives. So the position of an object in the heap is not a stable thing to name, which drives several decisions below.

## 2. How ImageMap reads the object memory

ImageMap uses only what the image already offers, with no FFI and no VM change.

### 2.1 Enumeration: a snapshot array

```smalltalk
SystemNavigation default allObjectsDo: [:o | ... ]
```

In Pharo 13 this is `allObjectsOrNil do: aBlock`, and `allObjectsOrNil` is `<primitive: 178>`: **the VM builds an Array of every object in the system and the image iterates over it.** That has a few consequences that the rest of the code relies on.

- The order is the order in which the VM enumerates the heap. ImageMap calls it *heap order*, and it is the only order it knows. It does not tell where in memory an object is.
- The array is a **snapshot**. While you iterate, the array holds every object, so nothing in the array can be collected and the order does not change under you. A scan is therefore consistent from its first object to its last.
- The snapshot costs memory: about 8 bytes per object, so around 90 MB for the 11 million objects of a GT image. It is transient, but it is the reason a scan is not free (about 1 s to reach index 5,000,000, about 3 s for the whole heap).
- Immediates are not in it, bridges are not in it *(literature)*, and free chunks are not in it. ImageMap says "live objects" for this reason.
- The index of an object is its position in this array. A new snapshot after a GC gives different positions.

### 2.2 Size: computed, not read from the header

```smalltalk
sizeInMemory
	^ self class isVariable
		ifTrue: [ self class byteSizeOfInstanceOfSize: self basicSize ]
		ifFalse: [ self class byteSizeOfInstance ]
```

`byteSizeOfInstanceOfSize:` is `<primitive: 181>`, so the size comes from the class format and the slot count and follows the layout in section 1 (header, overflow word, rounding, 16-byte minimum). It is not read from the object's header, and ImageMap does not look at free-chunk sizes or segment gaps.

Two details:

- Some objects answer something that is not an Integer (for example proxies such as a `MessageCatcher` that turn every message into data). For those, the scan uses the size of the class instead.
- A scan runs with no handler around each object and is repeated on a slow path, with a handler for each object, only if the fast path raises an error. A handler for every object made a scan take 5 to 24 s instead of about 1 s.

### 2.3 Offset: a running total, not an address

While iterating, ImageMap adds up the sizes: the *offset* of an object is the sum of the sizes of all the objects before it in the snapshot. It is meant to give the picture a sense of position and scale, like the address column in a memory dump. It is **not a memory address**: gaps (free chunks, bridges, segment boundaries) are not in it, and it is different after the next GC.

### 2.4 Kind: a classification of the class

```smalltalk
ImageMapCell class >> kindOfClass: aClass
```

The kind depends only on the class, in a fixed order of tests: `CompiledCode` (method), metaclasses (class), `Symbol`, `String`, `Context`, `BlockClosure`, `MethodDictionary`, `Dictionary`, `Association`, `OrderedCollection`, then the format of the class (weak, bytes, words, variable pointers) and finally `object`. The order matters because a `Symbol` is also a `String` and a `MethodDictionary` is also a `Dictionary`. The whole-heap scans keep a cache from class to kind, so each class is classified once.

## 3. The three views

### 3.1 Window (`ImageMapSnapshot`, `ImageMapViewer`)

A window is `count` consecutive entries of the snapshot starting at index `start`. Building it walks the snapshot from the beginning and keeps the cells only from `start` on, so the cost grows with `start`. Each cell holds the object, its index, its offset, its size and its kind. A cell holds the object itself (a strong reference), which is how a click can inspect it. The window is therefore a picture of one moment, and the cells keep their objects alive for as long as the window exists.

### 3.2 Overview (`ImageMapOverview`, `ImageMapPage`)

`scan` runs `Smalltalk garbageCollect` and walks the snapshot once. It starts a new page whenever the running offset reaches the next 1 MiB boundary, so a page is "about 1 MiB": it ends after the object that crosses the boundary. For each page it adds the bytes per kind, and the colour of the block is the kind with most bytes. It also adds up bytes and object counts per class (`classStats`), which the diff needs.

The first object of a page is kept in a `WeakArray` (the **anchor**). It has two uses: *Open window here* looks the anchor up again with `startingAt:` to find its current index, which survives a GC that changed all indexes; and the diff uses it as a landmark. It is weak so that an overview kept as a baseline does not hold on to objects that would otherwise be collected.

### 3.3 Diff (`ImageMapDiff`, `ImageMapDiffCell`; experimental)

Comparing two heaps object by object would need object identity across two moments, and positions do not survive a GC. The diff uses the anchors instead:

1. Collect garbage and walk the heap now, in heap order.
2. Whenever the walk meets the anchor of the next baseline page, start counting for that page. Anchors are expected in their old order, so only the next one is tested for each object (an identity comparison).
3. Bytes per kind between two anchors are compared with what the baseline page held. The difference gives the block: filled when the span grew, outlined when it shrank, coloured by the kind that changed most, opaque in proportion to the size of the change.
4. A page whose anchor has been collected is merged into the nearest earlier page whose anchor was found. The bytes after the last anchor that exceed the baseline are shown as *tail* (new) blocks.
5. If an anchor shows up out of order, `isFullyAligned` is false, and the views say so.

Because the pages are spans between landmarks and not memory ranges, the diff answers "which part of the heap, in heap order, grew by what kinds of objects". It does not answer "which objects are new". The per-class change (`classChanges`) comes from the class statistics of the two scans and does not depend on the anchors.

### 3.4 Counts in the scan, and the diagrams

The same pass that builds the pages of the overview also counts, per object, which kind follows which in heap order (`transitions`, kinds x kinds) and how many objects and bytes each kind has in each size class (`sizeCounts`, `sizeBytes`). A size class is a power of two: class n holds the sizes above 2^(n-1) and up to 2^n bytes. Both are small arrays updated in the loop, and they added about 15% to the time of a scan. They are what the Neighbours and Sizes views show. An overview from before they were counted answers nil for them, and the views say "scan again".

The diagrams are Mermaid sources built in `ImageMapMermaid` (a sankey for the classes, for the whole heap and for a window, a flowchart for the neighbours and for the references of an object, bar charts for the sizes and the class changes) and drawn by Pele2svg, which runs Node.js: one external process, about 0.4 s per diagram. Pele2svg is optional, so `ImageMapMermaid` checks that it is loaded and turns any failure into a label.

Three things about Mermaid that cost time. A sankey with many nodes needs its height set (`%%{init: {"sankey": {"height": n}}}%%`); without it every node is one pixel high. A label that contains parentheses or brackets has to be quoted. The colours of the sankey nodes are chosen by pele from a default palette, in the order in which the nodes appear, so they do not match the kind colours and change from one diagram to the next; `nodeColors` in the init directive (`"nodeColors": {"string": "#F7A8B0", ...}`) sets them. `ImageMapMermaid class>>sankeyStats:total:root:minShare:maxClasses:` builds the sankey for both the overview (the whole heap) and a window, and gives every kind, every named class and every `other <kind>` node the colour of its kind.

`ImageMapReferences` shows what one object points to: its named variables, then its indexed slots (the literals for a compiled method), at most 24. Slots that point to the same object share one arrow. Who points to the object is not shown, because `pointersTo` scans the heap (about 1.7 s in the image used here).

## 4. Limits

- Indexes and offsets are valid for one moment. Within one scan the snapshot array keeps the picture self-consistent.
- Offsets are not addresses, and the picture says nothing about fragmentation, free space or the split between new and old space.
- A scan briefly needs memory for the snapshot array.
- The diff is a heuristic built on anchors and can lose resolution when many anchors are collected.
- Only 1 MiB pages have been tried in the views.

## Further reading

- Pharo VM wiki, [Documentation](https://github.com/pharo-project/pharo-vm/wiki/Documentation), with the pages [How is Pharo memory structured when an image is open?](https://github.com/pharo-project/pharo-vm/wiki/How-is-Pharo-memory-structured-when-an-image-is-open-%3F) and [Garbage collector](https://github.com/pharo-project/pharo-vm/wiki/Garbage-collector)
- Booklet draft: [Pharo Virtual Machine](https://github.com/SquareBracketAssociates/Booklet-PharoVirtualMachine)
- Clément Béra, [articles on memory management](https://clementbera.wordpress.com/category/memory-management/), including the Spur object format
- Eliot Miranda, [Cog blog](http://www.mirandabanda.org/cogblog/)
- The source of the memory manager: class `SpurMemoryManager` in the VM sources (`pharo-project/pharo-vm`)
