"
I draw a formula as a Bloc element in a side panel, with Pele2svg (https://github.com/iriyak/pele2svg), which typesets it with MathJax.

A formula is optional, like the diagrams: `ImageMapFormula isAvailable` tells whether the Pele2svg that is loaded can typeset a formula on its own (that is newer than its v0.3.0 release; see its CHANGELOG), and `elementForTex:` answers nil when it cannot, or when drawing fails (for example when Node.js or mathjax-full is missing), so the panels show their plain text only. Drawing starts an external process and takes about 0.3 s, so the SVG of a formula is kept for the next time: a TeX string that was drawn once costs nothing afterwards. `resetCache` forgets them.
"
Class {
	#name : 'ImageMapFormula',
	#superclass : 'Object',
	#classVars : [
		'Svgs'
	],
	#category : 'ImageMap-Core',
	#package : 'ImageMap',
	#tag : 'Core'
}

{ #category : 'accessing' }
ImageMapFormula class >> elementForTex: aTexString [
	"A BlSkiaSvgElement with the formula (14 px, black), or nil when it cannot be drawn."

	| svg |
	self isAvailable ifFalse: [ ^ nil ].
	^ [ svg := self svgs at: aTexString ifAbsentPut: [ Pele2svg new svgFor: aTexString format: #tex display: false size: 14 color: '#000000' ].
		Pele2svg new elementFromSvg: svg ] on: Error do: [ :error | nil ]
]

{ #category : 'testing' }
ImageMapFormula class >> isAvailable [
	"Is a Pele2svg loaded that can typeset a formula on its own?"

	^ (Smalltalk at: #Pele2svg ifAbsent: [ ^ false ]) canUnderstand: #svgFor:format:display:size:color:
]

{ #category : 'accessing' }
ImageMapFormula class >> resetCache [
	Svgs := nil
]

{ #category : 'private' }
ImageMapFormula class >> svgs [
	^ Svgs ifNil: [ Svgs := Dictionary new ]
]
