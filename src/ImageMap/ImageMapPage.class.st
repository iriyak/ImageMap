"
One page (a fixed number of bytes of live objects, in heap order) of the overview: a reference to its first object, that object's index and byte offset at scan time, and the bytes per kind.
"
Class {
	#name : 'ImageMapPage',
	#superclass : 'Object',
	#instVars : [
		'firstObject',
		'firstIndex',
		'offset',
		'objectCount',
		'bytes',
		'byKind',
		'anchor',
		'anchorIsNil'
	],
	#category : 'ImageMap',
	#package : 'ImageMap'
}

{ #category : 'adding' }
ImageMapPage >> addObject: size kind: k [
	objectCount := objectCount + 1.
	bytes := bytes + size.
	byKind at: k put: (byKind at: k) + size
]

{ #category : 'accessing' }
ImageMapPage >> anchor [
	^ anchor
]

{ #category : 'accessing' }
ImageMapPage >> anchorIsNil [
	^ anchorIsNil
]

{ #category : 'accessing' }
ImageMapPage >> byKind [
	^ byKind
]

{ #category : 'accessing' }
ImageMapPage >> bytes [
	^ bytes
]

{ #category : 'analysis' }
ImageMapPage >> dominantKind [
	| best |
	best := 1.
	2 to: byKind size do: [:i | (byKind at: i) > (byKind at: best) ifTrue: [best := i]].
	^ ImageMapCell kinds at: best
]

{ #category : 'accessing' }
ImageMapPage >> firstIndex [
	^ firstIndex
]

{ #category : 'accessing' }
ImageMapPage >> firstObject [
	"The first object of this page, or nil if it has been garbage collected (see isAnchorAlive). Pages made by older scans hold it strongly."
	^ anchor ifNil: [firstObject] ifNotNil: [:w | w first]
]

{ #category : 'testing' }
ImageMapPage >> isAnchorAlive [
	^ anchor isNil or: [anchorIsNil == true or: [anchor first notNil]]
]

{ #category : 'printing' }
ImageMapPage >> label [
	^ '+', (offset printStringBase: 16), '  ', objectCount printString, ' objects  ', (bytes // 1024) printString, ' KiB  mostly ', self dominantKind asString
]

{ #category : 'accessing' }
ImageMapPage >> objectCount [
	^ objectCount
]

{ #category : 'accessing' }
ImageMapPage >> offset [
	^ offset
]

{ #category : 'initialization' }
ImageMapPage >> setFirstObject: o index: i offset: off kinds: n [
	"The anchor is held weakly so that taking a baseline does not keep that object (and what it references) alive."
	anchor := WeakArray with: o.
	anchorIsNil := o isNil.
	firstIndex := i. offset := off.
	objectCount := 0. bytes := 0.
	byKind := Array new: n withAll: 0
]

{ #category : 'analysis' }
ImageMapPage >> topKinds: n [
	"Answer up to n associations kind -> bytes, biggest first."
	| all |
	all := (1 to: byKind size) collect: [:i | (ImageMapCell kinds at: i) -> (byKind at: i)].
	all := (all select: [:a | a value > 0]) asSortedCollection: [:a :b | a value >= b value].
	^ all asArray first: (all size min: n)
]
