class_name SampleCatalog
extends Resource

@export var samples: Array[SampleDefinition] = []


func find_sample(sample_id: String) -> SampleDefinition:
	for sample in samples:
		if sample.id == sample_id:
			return sample
	return null
