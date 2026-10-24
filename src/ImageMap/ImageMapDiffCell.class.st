"
One block of the diff map: either a baseline page (pageNumber) with its per-kind byte change, or a tail block (isTail) for bytes added after the last baseline page.
"
Class {
	#name : 'ImageMapDiffCell',
	#superclass : 'Object',
	#instVars : [
		'pageNumber',
		'deltas',
		'aligned',
		'isTail',
		'afterObjects',
		'mergedInto',
		'groupSize'
	],
	#category : 'ImageMap',
	#package : 'ImageMap'
}

{ #category : 'accessing' }
ImageMapDiffCell >> afterObjects [
	^ afterObjects
]

{ #category : 'accessing' }
ImageMapDiffCell >> afterObjects: x [
	afterObjects := x
]

{ #category : 'accessing' }
ImageMapDiffCell >> aligned [
	^ aligned
]

{ #category : 'accessing' }
ImageMapDiffCell >> aligned: x [
	aligned := x
]

{ #category : 'accessing' }
ImageMapDiffCell >> deltas [
	^ deltas
]

{ #category : 'accessing' }
ImageMapDiffCell >> deltas: x [
	deltas := x
]

{ #category : 'analysis' }
ImageMapDiffCell >> dominantDelta [
	^ deltas at: self dominantIndex
]

{ #category : 'analysis' }
ImageMapDiffCell >> dominantIndex [
	"Index of the kind with the biggest absolute change."
	| best |
	best := 1.
	2 to: deltas size do: [:i | (deltas at: i) abs > (deltas at: best) abs ifTrue: [best := i]].
	^ best
]

{ #category : 'analysis' }
ImageMapDiffCell >> dominantKind [
	^ ImageMapCell kinds at: self dominantIndex
]

{ #category : 'accessing' }
ImageMapDiffCell >> groupSize [
	^ groupSize
]

{ #category : 'accessing' }
ImageMapDiffCell >> groupSize: x [
	groupSize := x
]

{ #category : 'testing' }
ImageMapDiffCell >> isMerged [
	^ mergedInto notNil
]

{ #category : 'accessing' }
ImageMapDiffCell >> isTail [
	^ isTail
]

{ #category : 'accessing' }
ImageMapDiffCell >> isTail: x [
	isTail := x
]

{ #category : 'accessing' }
ImageMapDiffCell >> mergedInto [
	^ mergedInto
]

{ #category : 'accessing' }
ImageMapDiffCell >> mergedInto: x [
	mergedInto := x
]

{ #category : 'accessing' }
ImageMapDiffCell >> pageNumber [
	^ pageNumber
]

{ #category : 'accessing' }
ImageMapDiffCell >> pageNumber: x [
	pageNumber := x
]

{ #category : 'analysis' }
ImageMapDiffCell >> topChanges: n [
	"Up to n associations kind -> byte change, biggest absolute change first, zero changes left out."
	| all |
	all := (1 to: deltas size) collect: [:i | (ImageMapCell kinds at: i) -> (deltas at: i)].
	all := (all reject: [:a | a value = 0]) asSortedCollection: [:a :b | a value abs >= b value abs].
	^ all asArray first: (all size min: n)
]

{ #category : 'analysis' }
ImageMapDiffCell >> totalDelta [
	^ deltas inject: 0 into: [:s :x | s + x]
]
