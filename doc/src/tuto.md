# Création, paramétrage et calibration d'une caméra

Ce petit tutoriel vous guidera à travers la création et la calibration de deux caméra orbbec femto mega.

Pour faire une calibration, nous conseillons de désactiver la "crop region" en premier lieu. Cela vous permet de manipuler librement vos nuages de points sans que leur position par rapport à la "crop region" n'en change leur affichage.

Pour instancier une caméra, allez dans l'onglet "Cameras" du menu latéral et appuyez sur le "+". Un sous-menu pour le dispositif devrait être créé. Le dispositif Orbbec devrait être sélectionné par défaut.

Si des caméra orbbec sont branchées sur votre réseau, le menu déroulant "IP" devrait déjà contenir les adresses IP des caméras. Si vous venez de les brancher, attendez un moment que les orbbecs démarrent et que le processus d'auto-découverte de Carto les trouve. En sélectionnant une IP, la caméra devrait se connecter et son nuage de point devrait s'afficher.

Commencez par tenter d'aligner le plancher, les murs ou un objet facilement reconnaissable de votre espace de manière à ce que le haut soit reconnaissable. Pour faciliter la visualisation, Vous pouvez faire disparaître les points de votre deuxième caméra en mettant le "thinning" à 100%. Les vues orthographiques sont très pratiques pour obtenir un alignement des planchers et des murs.

Pour votre deuxième caméra, tentez d'aligner les planchers, murs ou autre objets reconnaissable au nuage de point de votre première caméra.

Vous pouvez ensuite réactiver la "crop region". Vous pouvez cliquer sur les "poignées" de la "crop region" pour obtenir un gizmo vous permettant de la déplacer et de la redimensionner.

La "crop region" est pratique pour obtenir un cadrage permettant d'observer des gens déambulant dans l'espace sans avoir les points des planchers et des murs.

Notez qu'il est possible de sélectionner plusieurs objets à la fois avec Ctrl+Click. Cela peut vous aider à changer la position de vos caméras sans perdre votre alignement.

Voici un vidéo montrant l'exécution des étapes :

<div style="padding:56.25% 0 0 0;position:relative;"><iframe src="https://player.vimeo.com/video/1214388626?badge=0&amp;autopause=0&amp;player_id=0&amp;app_id=58479" frameborder="0" allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share" referrerpolicy="strict-origin-when-cross-origin" style="position:absolute;top:0;left:0;width:100%;height:100%;" title="Carto - Exemple de calibration de deux Orbbec Femto Mega"></iframe></div><script src="https://player.vimeo.com/api/player.js"></script>
