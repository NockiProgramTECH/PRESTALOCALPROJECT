

# Dictionnaire de données
*Table :Categorie Prestation*

|Nom du champ| Type de donnée| Description|
| :--- | :--- | :--- |
| id  Integer | Identifiant unique de la prestation. |
| nom |Varchar(100)    | Nom de la prestation (ex: Plombier, Soudeur, Électricien). |
| iconeImage | URL |Optionnel : une icône pour l'affichage dans l'application mobile. |
| descriptionText | Text | Optionnel : description de ce que couvre ce métier. |

*Table: Ville*
| Nom du champ | Type de donnée | Description |
| :--- | :--- | :--- |
| id | Integer | Identifiant unique de la ville. |
| nom | Varchar(100) | Nom de la ville (ex: Dakar, Thiès). |

*Table : prestataire qiu est un User personnaliser de notre Projet* 
| Nom du champ | Type de donnée  | Description |
| :--- | :--- | :--- |
| id UUID  |  Integer  | Identifiant unique du prestataire |
| nom |  Varchar(50) | Nom de famille |
| prenom | Varchar(50) | Prénom(s) |
| email |  Varchar(100) | Adresse mail (unique pour la connexion) |
| telephone | Varchar(20) | Numéro de téléphone (format international) |
| photo_profil | Image / URL | Chemin vers le fichier image du profil |
| metier | Varchar(100) | La catégorie de prestation (Plomberie, Design, etc.) |
| bio | Text | Description détaillée des compétences |
| ville | Integer(Foreignkey  ) | Ville de résidence/travail foreignkey de la table ville |
| quartier | Varchar(50) | Zone d'intervention précise |
| annee_experience | Integer | Années d'expérience dans le métier |
| est_verifie | Boolean | Statut de confiance (True/False) |
| date_inscription | DateTime | Date de création du compte |


*Table : prestation*
| Nom du champ | Type de donnée | Description | Exemple |
| :--- | :--- | :--- | :--- |
| id | Integer | Identifiant unique de la prestation. | 1 |
| nom | Varchar(100) | Le nom du métier ou du service. | Plomberie ou Plombiers |
| slug | Varchar(100) | Version URL du nom (très utile pour le web ou les API). | plomberie |
| metier | Varchar(100) | La catégorie de prestation (Plomberie, Design, etc.). | Plomberie |
| description | Text | Une phrase explicative de ce que comprend ce service. | Dépannage de fuites, installation de robinetterie, débouchage... |
| image_couverture | URL / Image | Une belle photo illustrative pour les bannières. | categories/plomberie_cover.jpg |
| icone | URL / Image | Un petit pictogramme (souvent au format SVG ou PNG transparent) pour la grille de l'application. | icones/plumber.svg |
| est_actif | Boolean | Permet de masquer temporairement une prestation si nécessaire (True/False). | True |

*Table :evaluation*
| Nom du champ | Type de donnée | Description | Exemple |
| :--- | :--- | :--- | :--- |
| id | Integer | Identifiant unique de l'évaluation. | 1 |
| prestataire_id | Integer (Foreign Key) | Référence à l'identifiant du prestataire évalué. | 1 |
| client_nom | Varchar(100) | Nom du client qui a laissé l'évaluation. | Dupont |
| client_prenom | Varchar(100) | Prénom du client qui a laissé l'évaluation. | Jean |
| client_email | Varchar(100) | Adresse mail du client (optionnel, pour vérification). | jean.dupont@example.com |
| note | Integer (1-5) | Note globale attribuée au prestataire. | 4 |
| commentaire | Text | Commentaire détaillé sur l'expérience avec le prestataire. | "Très professionnel et ponctuel, je recommande !" |
| date_evaluation | DateTime | Date et heure de l'évaluation. | 2024-06-01 14:30:00 |



