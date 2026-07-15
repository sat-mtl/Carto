extends Node3D

enum filter_shapes {BOX=0, SPHERE=1}
# Inclusion filter will only keep points that are included in them.
# exclusion filters will only keep points that are excluded from them.
enum filter_modes {INCLUSION=0, EXCLUSION=1, INACTIVE=2}
