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

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> afterObjects [
	^ afterObjects
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> afterObjects: x [
	afterObjects := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> aligned [
	^ aligned
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> aligned: x [
	aligned := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> deltas [
	^ deltas
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> deltas: x [
	deltas := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> dominantDelta [
	^ deltas at: self dominantIndex
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> dominantIndex [
	"Index of the kind with the biggest absolute change."
	| best |
	best := 1.
	2 to: deltas size do: [:i | (deltas at: i) abs > (deltas at: best) abs ifTrue: [best := i]].
	^ best
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> dominantKind [
	^ ImageMapCell kinds at: self dominantIndex
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> groupSize [
	^ groupSize
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> groupSize: x [
	groupSize := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> isMerged [
	^ mergedInto notNil
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> isTail [
	^ isTail
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> isTail: x [
	isTail := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> mergedInto [
	^ mergedInto
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> mergedInto: x [
	mergedInto := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> pageNumber [
	^ pageNumber
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> pageNumber: x [
	pageNumber := x
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> topChanges: n [
	"Up to n associations kind -> byte change, biggest absolute change first, zero changes left out."
	| all |
	all := (1 to: deltas size) collect: [:i | (ImageMapCell kinds at: i) -> (deltas at: i)].
	all := (all reject: [:a | a value = 0]) asSortedCollection: [:a :b | a value abs >= b value abs].
	^ all asArray first: (all size min: n)
]

{ #category : 'as yet unclassified' }
ImageMapDiffCell >> totalDelta [
	^ deltas inject: 0 into: [:s :x | s + x]
]
