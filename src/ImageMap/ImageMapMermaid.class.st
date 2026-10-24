"
I build the Mermaid sources of the diagrams in the ImageMap views, and I turn a Mermaid source into a Bloc element with Pele2svg (https://github.com/iriyak/pele2svg).

Pele2svg is optional. `ImageMapMermaid isAvailable` tells whether it is loaded. Without it, or when drawing fails (for example when Node.js is missing), `elementForSource:` answers a label with the reason, so the views that use me still open. Drawing starts an external process and takes about 0.4 s.

`classesSourceFor:` answers a sankey diagram of an ImageMapOverview: the whole heap, its kinds, and the classes that take at least 1% of the heap.
"
Class {
	#name : 'ImageMapMermaid',
	#superclass : 'Object',
	#category : 'ImageMap-Mermaid',
	#package : 'ImageMap',
	#tag : 'Mermaid'
}

{ #category : 'ui' }
ImageMapMermaid class >> classesElementFor: anOverview [
	^ self elementForSource: (self classesSourceFor: anOverview)
]

{ #category : 'sources' }
ImageMapMermaid class >> classesSourceFor: anOverview [
	"A sankey diagram: the whole heap, then its kinds, then the classes that take at least 1% of the heap. What is left of a kind goes to 'other <kind>' when it is at least 0.1% of the heap, and to 'small remainders' otherwise. The height of the diagram follows the number of nodes in the last column; without it Mermaid draws every node one pixel high."
	| kinds total stats kindBytes rest named out |
	kinds := ImageMapCell kinds.
	total := anOverview totalBytes max: 1.
	stats := anOverview classStats.
	kindBytes := Array new: kinds size withAll: 0.
	rest := Array new: kinds size withAll: 0.
	named := OrderedCollection new.
	stats keysAndValuesDo: [:aClass :v |
		kindBytes at: v first put: (kindBytes at: v first) + (v at: 2).
		(v at: 2) * 100 >= total
			ifTrue: [named add: aClass -> v]
			ifFalse: [rest at: v first put: (rest at: v first) + (v at: 2)]].
	named := named asSortedCollection: [:a :b | (a value at: 2) >= (b value at: 2)].
	out := WriteStream on: String new.
	out nextPutAll: '%%{init: {"sankey": {"width": 900, "suffix": " MiB", "height": ';
		print: ((named size + kinds size) * 28 max: 420);
		nextPutAll: '}}}%%'; lf.
	out nextPutAll: 'sankey-beta'; lf; lf.
	kinds doWithIndex: [:k :i |
		self line: 'Whole heap' to: k bytes: (kindBytes at: i) on: out].
	named do: [:a |
		self line: (kinds at: a value first) to: a key name bytes: (a value at: 2) on: out].
	kinds doWithIndex: [:k :i | | r |
		r := rest at: i.
		self line: k
			to: (r * 1000 >= total ifTrue: ['other ', k] ifFalse: ['small remainders'])
			bytes: r on: out].
	^ out contents
]

{ #category : 'ui' }
ImageMapMermaid class >> elementForSource: aMermaidString [
	"Answer a scrollable element with the diagram, or a label that says why it could not be drawn."
	^ (self isAvailable
		ifFalse: [self messageElement: 'Pele2svg is not loaded. This diagram is drawn with Pele2svg (https://github.com/iriyak/pele2svg), which is optional.']
		ifTrue: [[(Smalltalk at: #Pele2svg) new asElement: aMermaidString]
			on: Error
			do: [:e | self messageElement: 'The diagram could not be drawn: ', e messageText]])
		asScrollableElement
]

{ #category : 'testing' }
ImageMapMermaid class >> isAvailable [
	"Is Pele2svg loaded?"
	^ Smalltalk includesKey: #Pele2svg
]

{ #category : 'private' }
ImageMapMermaid class >> line: aSource to: aTarget bytes: n on: aStream [
	"One row of a sankey diagram: source,target,value in MiB. Rows that round to zero are left out."
	| v |
	v := (n / 1048576.0) printShowingDecimalPlaces: 2.
	v = '0.00' ifTrue: [^ self].
	aStream nextPutAll: aSource; nextPut: $,; nextPutAll: aTarget; nextPut: $,; nextPutAll: v; lf
]

{ #category : 'ui' }
ImageMapMermaid class >> messageElement: aString [
	^ BrLabel new
		aptitude: BrGlamorousLabelAptitude;
		text: aString;
		padding: (BlInsets all: 12)
]
