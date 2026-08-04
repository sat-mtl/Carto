# Intégration

Cette page contient des conseils d'intégration de Carto et de dispositifs de capture dans un espace.

## Couverture de l'espace avec des Orbbec Femto Mega

L’objectif de ce système multi-caméras est d’être en mesure de capter des données visuelles sur toute la superficie sur laquelle nous envisageons que des participants pourront interagir avec l’installation. Afin de s’assurer que notre système nous procure des données 3d fiable à tout moment de l’expérience, il faut optimiser la couverture de l’espace grâce au bon positionnement des caméras.

Les spécifications techniques des capteurs Femto Mega nous indiquent qu’il est possible d’obtenir des données de profondeur selon deux modes d’utilisation: le Wide Field of View (WFoV), ainsi que le Narrow Field of View (NFoV). L’utilisation du champ de vision plus large assurera une superficie de captation plus grande à proximité du capteur, tandis que l’utilisation du champ de vision plus étroit permettra de récupérer des informations visuelles à une plus grande distance du capteur. Les spécifications techniques sont présentées dans le tableau suivant. Il faut cependant noter que l’intervalle de distance recommandé dans le tableau est une estimation plutôt conservatrice; nous avons par exemple pu récupérer des données de profondeur à plus de 8m du capteur en utilisant le mode NFOV. À noter que les performances en extérieur sont très limités. Il est préférable d'utiliser un lidar.

Le positionnement des caméras dans l’espace sera déterminé en grande partie par la superficie de la zone de captation, ainsi que par la hauteur des plafonds. Plus les plafonds sont hauts, plus il est facile de couvrir une grande zone de captation au sol sans avoir à se soucier de l’occlusion du champ de vision des caméras (bien entendu, cela considère qu’on est en mesure d’accrocher les caméras en hauteur dans la pièce).

Le cas d’usage standard d’un système à plusieurs caméras visera à obtenir de l’information visuelle dans une zone 3 dimensionnelle d’une hauteur d’au moins 2m, question de récupérer les données de position de tous les corps des individus dans l’espace. Moins les plafonds sont hauts, plus il faut de caméras pour assurer une couverture complète de l’espace, et éviter l’occlusion dans la zone.

Il est à noter que le nombre de caméras nécessaire (et la précision de calibration requise) dépendra de ce qu’on souhaite obtenir comme information sur les déplacements dans l’espace de captation. Le premier objectif sera toujours d’assurer une compréhension spatiale des déplacements par le système: être en mesure de projeter la localisation 3 dimensionnelle d’un participant sur toute surface adjacente, notamment.
