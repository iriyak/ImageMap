"
I am one row of a table that ImageMapOverview computes from its scan: either one kind (kind, objects, sameShare, nextShares: how often an object of that kind is followed by the same kind, and the shares of the kinds that follow it, biggest first) or one size class (label, objects, bytes, dominantKind). See `kindTransitionRows` and `sizeClassRows`.
"
Class {
	#name : 'ImageMapRow',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'label',
		'objects',
		'bytes',
		'sameShare',
		'nextShares',
		'dominantKind',
		'shortLabel'
	],
	#category : 'ImageMap-Overview',
	#package : 'ImageMap',
	#tag : 'Overview'
}

{ #category : 'accessing' }
ImageMapRow >> bytes [
	^ bytes
]

{ #category : 'accessing' }
ImageMapRow >> bytes: anObject [
	bytes := anObject
]

{ #category : 'accessing' }
ImageMapRow >> dominantKind [
	^ dominantKind
]

{ #category : 'accessing' }
ImageMapRow >> dominantKind: anObject [
	dominantKind := anObject
]

{ #category : 'accessing' }
ImageMapRow >> kind [
	^ kind
]

{ #category : 'accessing' }
ImageMapRow >> kind: anObject [
	kind := anObject
]

{ #category : 'accessing' }
ImageMapRow >> label [
	^ label
]

{ #category : 'accessing' }
ImageMapRow >> label: anObject [
	label := anObject
]

{ #category : 'accessing' }
ImageMapRow >> nextShares [
	^ nextShares
]

{ #category : 'accessing' }
ImageMapRow >> nextShares: anObject [
	nextShares := anObject
]

{ #category : 'accessing' }
ImageMapRow >> objects [
	^ objects
]

{ #category : 'accessing' }
ImageMapRow >> objects: anObject [
	objects := anObject
]

{ #category : 'accessing' }
ImageMapRow >> sameShare [
	^ sameShare
]

{ #category : 'accessing' }
ImageMapRow >> sameShare: anObject [
	sameShare := anObject
]

{ #category : 'accessing' }
ImageMapRow >> shortLabel [
	^ shortLabel
]

{ #category : 'accessing' }
ImageMapRow >> shortLabel: anObject [
	shortLabel := anObject
]
