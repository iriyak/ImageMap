"
I am the Metacello baseline of ImageMap. Load ImageMap with `Metacello new repository: 'github://iriyak/ImageMap:main/src'; baseline: 'ImageMap'; load`.

ImageMap needs Glamorous Toolkit (Bloc, Brick and Phlow), which this baseline does not declare, so load it into a GT image. `BaselineOfImageMap loadLepiter` adds the lepiter directory of the cloned repository to the default Lepiter database.
"
Class {
	#name : 'BaselineOfImageMap',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfImageMap',
	#package : 'BaselineOfImageMap'
}

{ #category : 'loading' }
BaselineOfImageMap class >> loadLepiter [
	IceRepository registry  
		detect: [ :aRepository |
			aRepository name = 'ImageMap' ]
		ifFound: [ :aRepository | 
			| defaultDatabase currentProperties |
			defaultDatabase := LeDatabasesRegistry defaultLogicalDatabase.
			currentProperties := defaultDatabase properties.
			currentProperties addRegisteredDirectory: aRepository repositoryDirectory / 'lepiter'.
			defaultDatabase reload ]
		ifNone: [
			self inform: 'Repository not found.' ]
]

{ #category : 'baseline' }
BaselineOfImageMap >> baseline: spec [
	<baseline>
		^ spec for: #common do: [
			spec package: 'ImageMap'
		]
]
