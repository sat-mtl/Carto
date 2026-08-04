# Dépannage

Ce document contient des conseils de dépannage pour certains problèmes rencontrés.

## Le taux d'envois des caméras est plus bas que la cible

### Orbbec

Si vous utilisez des Orbbec Femto Mega, assurez-vous que personne d'autre sur le réseau n'est en train de demander des flux à la même caméra. Les Orbbec Femto Mega peuvent envoyer des flux à plusieurs application à la fois mais pas en gardant un taux d'envois optimal.

Si personne d'autre n'utilise le réseau et que le taux d'envois est toujours trop lent, assurez-vous que le lien réseau n'est pas saturé. À leur débit maximal (en 1024x1024 à 15fps), sans la couleur, les Orbbec Femto Mega peuvent utiliser 253 Mibps de bande passante. Cela signifie qu'une seule orbbec peut saturer un lien 200 Mibps et qu'ajouter une deuxième orbbec à ce réseau dégradera les performances. Assurez-vous d'utiliser au moins un lien 1Gibps si vous avez un nombre restreint de caméra. Il est aussi possible d'utiliser plusieur réseaux 1Gibps si le serveur sur lequel Carto roule possède un port réseau 10Gibps. Si il n'est pas possible pour vous d'utiliser un réseau avec plus de bande passante, vous pouvez réduire la résolution.

### Hesai

Si vous utilisez des hesai, la cible de taux d'envois dans Carto assume que le lidar est configuré à 1200 rpm. Si votre lidar est configuré à 600 rpm vous aurez la moitié du taux d'envois
