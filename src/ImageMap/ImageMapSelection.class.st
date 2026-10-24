"
I am what one open picture of an ImageMapOverview or an ImageMapDiff remembers about the click: the box of the side panel where the details go (detailBox), the block that is marked (element, and the border it had before, border), and the page or cell it stands for (item). The model can be open in several windows or inspectors at once (ImageMapOverview open answers the overview, and inspecting that answer opens it a second time), so each picture has its own selection, and a click in one of them does not write into the side panel of another.
"
Class {
	#name : 'ImageMapSelection',
	#superclass : 'Object',
	#instVars : [
		'detailBox',
		'element',
		'item',
		'border'
	],
	#category : 'ImageMap-Overview',
	#package : 'ImageMap',
	#tag : 'Overview'
}

{ #category : 'accessing' }
ImageMapSelection >> border [
	^ border
]

{ #category : 'accessing' }
ImageMapSelection >> border: anObject [
	border := anObject
]

{ #category : 'accessing' }
ImageMapSelection >> detailBox [
	^ detailBox
]

{ #category : 'accessing' }
ImageMapSelection >> detailBox: anObject [
	detailBox := anObject
]

{ #category : 'accessing' }
ImageMapSelection >> element [
	^ element
]

{ #category : 'accessing' }
ImageMapSelection >> element: anObject [
	element := anObject
]

{ #category : 'accessing' }
ImageMapSelection >> item [
	^ item
]

{ #category : 'accessing' }
ImageMapSelection >> item: anObject [
	item := anObject
]
