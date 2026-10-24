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
