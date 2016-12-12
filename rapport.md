---
title: Rapport de projet – Génération de labyrinthe
subtitle: Architecture des ordinateurs – Université de Strasbourg
author:
- Nicolas Argyriou
- Quentin Gliech
date: 12 décembre 2016
---

# Méthode de travail

La collaboration s'est faite via Git sur un dépôt hébergé sur GitHub, pour
gérer le versionnement des sources et travailler en parallèle sur différentes
tâches. Ce dépôt avec l'historique complet est disponible à cette adresse:

*<https://github.com/sandhose/labyrinthe-mips/>*

La répartition des tâches s'est faite assez facilement, et de manière à ce que
l'on puisse travailler indépendamment en parallèle. Par exemple, toute la
logique de création de tableau en mémoire et de placement des entrées/sorties
a été fait en même temps que le menu, avec le chargement/la sauvegarde du
labyrinthe dans un fichier.

La répartition des tâches s'est faite de manière à ce que chacun doive attendre
la fin du travail de l'autre pour être sur de travailler toujours de manière
séquentielle.

Nous avons rapidement décidé de coder uniquement pour l'émulateur *MARS* plutôt
que SPIM dès que l'on a commencé à utiliser des SYSCALLs propres à MARS pour
générer des nombres aléatoires.

Le fichier `Alea.s` fournit n'a pas du tout été utilisé, puisqu'il donnait
toujours les mêmes nombres aléatoires.

Nous nous sommes aussi mis d'accord sur des conventions de nommage des labels,
de commentaires &  d'indentation pour rendre le code plus lisible.

---

*Globalement, tout ce qui était demandé a été implémenté.*

\newpage

# Détails d'implémentation

## Structures de données

Le stockage des cellules est assez simple: un tableau contigu de $N*N$ avec un
octet pour chaque cellule, avec chacun des 8 bits utilisés comme indiqué sur le
sujet (+ le 8ème bit qui est utilisé pour garder en mémoire si la case a été
visitée ou pas)

Pour accéder aux cellules du tableau, nous avons fait plusieurs fonctions
annexes:

  - `CalcAddress (Adresse, Taille, X, Y) -> Adresse`:

    retourne l'addresse d'une casedonnée

  - `GetFlag (Adresse, Bit) -> Bit`:

    retourne la valeur d'un bit certain bit à une adresse (0 s'il est éteint,
    >0 sinon)

  - `SetFlag (Adresse, Bit)`:

    met un certain bit à 1 dans un octet

  - `UnsetFlag (Adresse, Bit)`:

    met un certain bit à 0 dans un octet

Tous les espaces mémoires sont **alloués** dans le **tas** ! Même les buffers
qui servent à stocker le nom de fichier, ou même à enregistrer le fichier à la
fin le sont.

## Approches pour résoudre certains problèmes

### Le menu

Toutes les fonctions qui demandent des choix à l'utilisateur sont programmées
pour assurer que le choix est correct en sortant de la fonction. Par exemple,
c'est à l'intérieur de la fonction `MainMenu` que l'on va vérifier que le choix
de l'utilisateur (1 ou 2) est correct avant de retourner.

### La génération: le choix des sorties du labyrinthe

La génération des sorties du labyrinthe (fonction `GenerateExits`) se fait
à partir de 4 nombres aléatoires.

Le premier, entre 0 et 1, va déterminer la colonne (= la première coordonnée)
des sorties (0 = entrée sur la première, et sortie sur la dernière
; 1 = l'inverse).

Les deux suivants servent à déterminer la cellule de chaque sortie (= la
seconde coordonnée) de chacune des sorties.

Enfin, un dernier entre 0 et 1 va déterminer si les sorties se trouvent sur les
bords horizontaux ou verticaux. Cette transformation est faite simplement en
échangeant (ou non) les deux coordonnées calculées précédemment.

### L'algorithme de génération & de résolution

Les algorithmes au cœur des processus de génération et de résolution étant très
similaires, la fonction qui détermine la case suivante à explorer est la même
pour les deux algorithme.

Celle-ci prend les coordonnées `(x,y)` d'une case en argument, et renvoie la
direction dans laquelle se déplacer pour la case suivante.

Il y a deux différences clés entre l'algorithme de génération et de résolution,

  1. La condition pour qu'une case soit éligible à l'exploration. La présence
     d'un mur empêchant le passage doit être vérifié durant la résolution
  2. L'action entreprise lors d'un déplacement. Les murs entre les deux cases
     sont abattus lors de la génération.

Le défi de cette fonction n'était pas tant l'inspection des quatre cases
adjacentes à celle passée en argument, mais de choisir aléatoirement laquelle
des cases valides serait éligible.

Pour chacune des quatre directions, l'on va donc vérifier

  1. si le déplacement est viable (donc pas en dehors de la grille, pas encore
     visitée, et – dans le cas de la résolution – sans mur entre)
  2. tirer un nombre aléatoire – avec une probabilité décroissante de "succès"
     – pour déterminer si l'on choisit cette direction ou non

Nous n'allons pas détailler ici le calcul, mais cela assure qu'il y ait que le
choix de la direction parmi les directions possibles est équitable.

\newpage

# Difficultés rencontrées

## Demander le nom du fichier

Demander une chaine de caractères à l'utilisateur nous a donné plus de fil
à retordre que ce que l'on pensait. En effet, le syscall qui permet de lire une
chaine de caractère demande déjà une adresse vers un buffer (qui est pour le
coup alloué dans le tas), et il y a un retour à la ligne (`\n`) à la fin de la
chaine. Enfin, il faut pouvoir concaténer `.resolu` à la fin de ce nom de
fichier dans le cas de la résolution.

## Choisir la prochaine case aléatoirement

Le processus de choix de direction a été assez complexe à imaginer, puisqu'il
a fallu tirer parmi un ensemble de case non déterminé à l'avance, sans que le
tirage soit en faveur d'une case.

## Respecter les conventions de registres & ne pas utiliser d'espace de mémoire "global"

Au début, pour simplifier, de nombreux espaces mémoires étaient statiquement
alloués dans le segment `.data`. Au fur et à mesure, nous nous sommes
débrouillés pour allouer à chaque fois tous ces espaces dynamiquement dans le
tas.

Aussi, nous nous sommes forcés à respecter au mieux les conventions au niveau
des registres, à savoir de passer les arguments dans `$aN`, de restaurer l'état
des `$sN` après utilisation, et d'utiliser les registres temporaires `$tN` que
s'il n'y a pas d'appel de fonctions. Il a fallu aussi se restreindre à chaque
fois à 4 arguments maximum (une seule fonction déroge à cette règle: un
argument est passé dans `$t9` pour la fonction `GenerateNextDirection`)
