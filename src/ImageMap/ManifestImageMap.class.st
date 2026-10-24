"
ImageMap shows the inside of a running Pharo image as block maps in Glamorous Toolkit. One block is one object, or one page of objects, and its colour is the kind of object: class, method, symbol, string, array, methoddict, dictionary, association, ordered, object, bytes, words, weak, context or block.

There are three views, each with a data class and a viewer:
- a window of 1024 consecutive objects: ImageMapSnapshot and ImageMapViewer
- the whole heap in pages of 1 MiB by default: ImageMapOverview, made of ImageMapPage
- an experimental diff between a baseline and the heap now: ImageMapDiff, made of ImageMapDiffCell

Entry points: `ImageMapViewer openAt: 5000000`, `ImageMapOverview open`, and `ImageMapDiff takeBaseline` followed by `ImageMapDiff open`.

Object indexes and offsets follow the order in which SystemNavigation>>allObjectsDo: visits the objects. An offset is the running total of their sizes, not a memory address. Both move whenever the garbage collector runs. Scanning only reads the class and the size of each object.
"
Class {
	#name : 'ManifestImageMap',
	#superclass : 'PackageManifest',
	#category : 'ImageMap-Manifest',
	#package : 'ImageMap',
	#tag : 'Manifest'
}
